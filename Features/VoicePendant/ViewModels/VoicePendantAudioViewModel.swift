//
//  VoicePendantAudioViewModel.swift
//  Limi
//
//  Backs the Audio Sharing screen:
//    • Real microphone recording (AVAudioRecorder via VoicePendantAudioRecorder).
//    • Importing audio from Files / other apps (storage).
//    • Real playback (AVAudioPlayer) for notes with a local file; simulated
//      playback for seeded demo notes that have no audio on disk.
//    • Sending the actual audio bytes to the pendant through the service.
//

import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class VoicePendantAudioViewModel: NSObject, ObservableObject {

    let pendant: VoicePendant

    @Published private(set) var voiceNotes: [VoiceNote] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    // Recording
    let recorder = VoicePendantAudioRecorder()

    // Playback
    @Published private(set) var playback: AudioPlaybackState = .idle
    @Published private(set) var playbackProgress: Double = 0

    // Sharing
    @Published private(set) var sharingNoteID: String?

    private let service: VoicePendantDataServicing
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var simulatedTimer: Timer?

    init(pendant: VoicePendant, service: VoicePendantDataServicing = VoicePendantDataService.current) {
        self.pendant = pendant
        self.service = service
        super.init()
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            voiceNotes = try await service.fetchVoiceNotes(for: pendant.id)
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Recording

    var isRecording: Bool { recorder.isRecording }

    func startRecording() async {
        let ok = await recorder.start()
        if !ok && recorder.permissionDenied {
            errorMessage = "Microphone access is off. Enable it in Settings to record."
        }
    }

    func stopRecordingAndSave() {
        guard let result = recorder.stop() else { return }
        let note = VoiceNote(
            id: "vn-\(UUID().uuidString.prefix(6))",
            title: "Recording \(shortTimestamp())",
            durationSeconds: result.duration,
            createdAt: Date(),
            sharedToPendant: false,
            source: .recorded,
            fileURL: result.url
        )
        voiceNotes.insert(note, at: 0)
        toastMessage = "Recording saved"
    }

    func cancelRecording() {
        recorder.cancel()
    }

    // MARK: - Import (Files / other apps)

    func importAudio(from url: URL) {
        do {
            let localURL = try VoicePendantAudioStore.importFile(from: url)
            let duration = VoicePendantAudioStore.duration(of: localURL)
            let title = url.deletingPathExtension().lastPathComponent
            let note = VoiceNote(
                id: "vn-\(UUID().uuidString.prefix(6))",
                title: title.isEmpty ? "Imported audio" : title,
                durationSeconds: duration,
                createdAt: Date(),
                sharedToPendant: false,
                source: .imported,
                fileURL: localURL
            )
            voiceNotes.insert(note, at: 0)
            toastMessage = "Audio imported"
        } catch {
            errorMessage = "Couldn't import audio: \(error.localizedDescription)"
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importAudio(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Playback

    func togglePlayback(for note: VoiceNote) {
        if playback.isPlaying(note.id) {
            pause()
        } else {
            play(note)
        }
    }

    private func play(_ note: VoiceNote) {
        stopTimers()
        if playback.activeNoteID != note.id { playbackProgress = 0 }

        if let url = note.fileURL {
            // Real playback.
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                if case .paused(let id) = playback, id == note.id {
                    newPlayer.currentTime = playbackProgress * newPlayer.duration
                }
                newPlayer.play()
                player = newPlayer
                playback = .playing(noteID: note.id)
                startProgressTimer()
            } catch {
                errorMessage = "Couldn't play audio: \(error.localizedDescription)"
            }
        } else {
            // Simulated playback for demo notes without a file.
            playback = .playing(noteID: note.id)
            startSimulatedTimer(duration: max(note.durationSeconds, 0.1))
        }
    }

    func pause() {
        guard let id = playback.activeNoteID else { return }
        player?.pause()
        stopTimers()
        playback = .paused(noteID: id)
    }

    func stop() {
        player?.stop()
        player = nil
        stopTimers()
        playback = .idle
        playbackProgress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }

    private func startSimulatedTimer(duration: Double) {
        let step = 0.05
        simulatedTimer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.playbackProgress += step / duration
                if self.playbackProgress >= 1 {
                    self.playbackProgress = 1
                    self.finishPlayback()
                }
            }
        }
    }

    private func finishPlayback() {
        stopTimers()
        player = nil
        playback = .idle
        playbackProgress = 0
    }

    private func stopTimers() {
        progressTimer?.invalidate(); progressTimer = nil
        simulatedTimer?.invalidate(); simulatedTimer = nil
    }

    // MARK: - Sharing (sends real bytes)

    func isSharing(_ note: VoiceNote) -> Bool { sharingNoteID == note.id }

    func share(_ note: VoiceNote) async {
        guard sharingNoteID == nil else { return }
        sharingNoteID = note.id
        defer { sharingNoteID = nil }

        // Read the actual audio bytes off disk (nil for demo notes).
        var audioData: Data?
        if let url = note.fileURL {
            audioData = try? Data(contentsOf: url)
            if audioData == nil {
                errorMessage = "Audio file is missing on this device."
                return
            }
        }

        do {
            let response = try await service.shareAudio(note: note, audioData: audioData, to: pendant.id)
            if let index = voiceNotes.firstIndex(where: { $0.id == note.id }) {
                voiceNotes[index].sharedToPendant = true
            }
            toastMessage = response.message ?? "Audio sent to pendant."
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ note: VoiceNote) async {
        do {
            try await service.deleteVoiceNote(note.id, for: pendant.id)
            VoicePendantAudioStore.delete(note.fileURL)
            voiceNotes.removeAll { $0.id == note.id }
            if playback.activeNoteID == note.id { stop() }
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func shortTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: Date())
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoicePendantAudioViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishPlayback()
        }
    }
}
