//
//  VoicePendantBackendRecorder.swift
//  Limi
//
//  Live microphone streaming to ws://69.62.125.138:8000/ws/{device_id}.
//  Matches the same UI surface as VoicePendantAudioRecorder.
//

import Foundation

@MainActor
final class VoicePendantBackendRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Double = 0
    @Published var permissionDenied = false

    private let deviceID: String
    private let manager: VoicePendantVoiceManager
    private var meterTimer: Timer?
    private var startedAt: Date?

    init(deviceID: String) {
        self.deviceID = deviceID
        self.manager = VoicePendantVoiceManager(deviceID: deviceID)
        super.init()
        manager.delegate = self
    }

    @discardableResult
    func start() async -> Bool {
        guard !isRecording else { return true }
        permissionDenied = false
        startedAt = Date()
        isRecording = true
        elapsed = 0
        startMetering()
        manager.start()
        print("🎙️ [VoicePendantVoice] Live stream started -> \(deviceID)")
        return true
    }

    func stop() -> (url: URL?, duration: Double)? {
        guard isRecording else { return nil }
        manager.stop()
        stopMetering()
        isRecording = false
        let duration = elapsed
        elapsed = 0
        level = 0
        print("🎙️ [VoicePendantVoice] Live stream stopped -> \(deviceID)")
        return (nil, duration)
    }

    func cancel() {
        guard isRecording else { return }
        manager.stop()
        stopMetering()
        isRecording = false
        elapsed = 0
        level = 0
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        startedAt = nil
    }
}

extension VoicePendantBackendRecorder: VoicePendantVoiceManagerDelegate {
    nonisolated func voiceManagerDidUpdateState(_ manager: VoicePendantVoiceManager) {
        Task { @MainActor in
            self.level = Double(manager.inputLevel)
        }
    }

    nonisolated func voiceManager(_ manager: VoicePendantVoiceManager, didFail message: String) {
        Task { @MainActor in
            self.permissionDenied = false
            print("❌ [VoicePendantVoice] \(message)")
        }
    }
}
