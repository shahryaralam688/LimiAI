//
//  VoicePendantAudioRecorder.swift
//  Limi
//
//  Real microphone recording + local file storage for the Audio Sharing
//  screen. Captures audio to an m4a file on disk so it can be played back
//  and uploaded to the backend (which relays it to the pendant hardware).
//

import Foundation
import AVFoundation

// MARK: - Local Audio File Store

/// Manages the on-disk location for recorded/imported voice notes.
enum VoicePendantAudioStore {
    /// Directory under Documents where pendant audio lives.
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("VoicePendantAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// A fresh file URL for a new recording.
    static func newRecordingURL() -> URL {
        directory.appendingPathComponent("rec-\(UUID().uuidString).m4a")
    }

    /// Copies an imported (security-scoped) file into our store and returns
    /// the local copy URL.
    static func importFile(from source: URL) throws -> URL {
        let needsScope = source.startAccessingSecurityScopedResource()
        defer { if needsScope { source.stopAccessingSecurityScopedResource() } }

        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let destination = directory.appendingPathComponent("imp-\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func duration(of url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite ? max(seconds, 0) : 0
    }

    static func delete(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Recorder

@MainActor
final class VoicePendantAudioRecorder: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Normalized 0...1 input level for a simple live meter.
    @Published private(set) var level: Double = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var meterTimer: Timer?

    // MARK: Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: Recording

    /// Begins recording. Returns false if permission/setup fails.
    @discardableResult
    func start() async -> Bool {
        guard !isRecording else { return true }

        let granted = await requestPermission()
        guard granted else {
            permissionDenied = true
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = VoicePendantAudioStore.newRecordingURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            newRecorder.record()

            recorder = newRecorder
            currentURL = url
            isRecording = true
            elapsed = 0
            startMetering()
            return true
        } catch {
            return false
        }
    }

    /// Stops recording and returns the file URL + duration, or nil on failure.
    func stop() -> (url: URL, duration: Double)? {
        guard isRecording, let recorder, let url = currentURL else { return nil }
        recorder.stop()
        stopMetering()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let duration = VoicePendantAudioStore.duration(of: url)
        self.recorder = nil
        self.currentURL = nil
        return (url, duration > 0 ? duration : elapsed)
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        stopMetering()
        isRecording = false
        VoicePendantAudioStore.delete(currentURL)
        self.recorder = nil
        self.currentURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Metering

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.elapsed = recorder.currentTime
                let power = recorder.averagePower(forChannel: 0) // dB, -160...0
                let normalized = max(0, min(1, (power + 50) / 50))
                self.level = Double(normalized)
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }
}
