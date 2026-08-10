//
//  VoicePendantVoiceSessionService.swift
//  Limi
//
//  Adapts the pendant WebSocket voice manager to the shared VoiceSessionControlling
//  surface used by VoiceView / VoiceViewModel (no UI changes required).
//

import Combine
import Foundation

@MainActor
final class VoicePendantVoiceSessionService: ObservableObject, VoiceSessionControlling {
    @Published private(set) var connectionState: VoiceConnectionState = .disconnected
    @Published private(set) var isUserSpeaking = false
    @Published private(set) var isAssistantSpeaking = false
    @Published var lastUserVisibleError: String?
    @Published private(set) var latestTranscript: String?
    @Published private(set) var finalizedTranscript: String?
    @Published private(set) var lastToolCall: LimiToolCall?

    var statePublisher: Published<VoiceConnectionState>.Publisher { $connectionState }
    var isUserSpeakingPublisher: Published<Bool>.Publisher { $isUserSpeaking }
    var isAssistantSpeakingPublisher: Published<Bool>.Publisher { $isAssistantSpeaking }
    var latestTranscriptPublisher: Published<String?>.Publisher { $latestTranscript }
    var finalizedTranscriptPublisher: Published<String?>.Publisher { $finalizedTranscript }
    var lastToolCallPublisher: Published<LimiToolCall?>.Publisher { $lastToolCall }

    let deviceID: String
    private let manager: VoicePendantVoiceManager

    init(deviceID: String) {
        self.deviceID = deviceID
        let manager = VoicePendantVoiceManager(deviceID: deviceID)
        self.manager = manager
        manager.delegate = self
    }

    func start() {
        lastUserVisibleError = nil
        connectionState = .connecting
        manager.start()
    }

    func stop() {
        manager.stop()
        connectionState = .disconnected
        isUserSpeaking = false
        isAssistantSpeaking = false
    }
}

extension VoicePendantVoiceSessionService: VoicePendantVoiceManagerDelegate {
    nonisolated func voiceManagerDidUpdateState(_ manager: VoicePendantVoiceManager) {
        Task { @MainActor in
            switch manager.phase {
            case .idle:
                connectionState = .disconnected
                isAssistantSpeaking = false
                isUserSpeaking = false
            case .connecting, .waitingForHello:
                connectionState = .connecting
                isAssistantSpeaking = false
                isUserSpeaking = false
            case .streaming:
                connectionState = .connected
                isAssistantSpeaking = false
                isUserSpeaking = manager.isUserSpeaking
            case .assistantSpeaking:
                connectionState = .connected
                isAssistantSpeaking = true
                isUserSpeaking = false
            case .error:
                connectionState = .error
                isAssistantSpeaking = false
                isUserSpeaking = false
            }
        }
    }

    nonisolated func voiceManager(_ manager: VoicePendantVoiceManager, didFail message: String) {
        Task { @MainActor in
            if lastUserVisibleError == nil {
                lastUserVisibleError = message
            }
            connectionState = .error
        }
    }
}
