//
//  VoicePendantVoiceManager.swift
//  Limi
//
//  Orchestrates WebSocket + mic PCM streaming + speaker playback for one pendant.
//

import Foundation

protocol VoicePendantVoiceManagerDelegate: AnyObject {
    func voiceManagerDidUpdateState(_ manager: VoicePendantVoiceManager)
    func voiceManager(_ manager: VoicePendantVoiceManager, didFail message: String)
}

final class VoicePendantVoiceManager {
    enum Phase: Equatable {
        case idle
        case connecting
        case waitingForHello
        case streaming
        case assistantSpeaking
        case error
    }

    let deviceID: String
    weak var delegate: VoicePendantVoiceManagerDelegate?

    private(set) var phase: Phase = .idle
    private(set) var isUserSpeaking = false
    private(set) var inputLevel: Float = 0

    private let webSocket: VoicePendantWebSocketServicing
    private let recorder = VoicePendantPCMRecorder()
    private let player = VoicePendantPCMPlayer()
    private let queue = DispatchQueue(label: "voicePendant.manager")

    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var micStarted = false
    private var receivedBackendReady = false

    init(deviceID: String, webSocket: VoicePendantWebSocketServicing = VoicePendantWebSocketService()) {
        self.deviceID = deviceID
        self.webSocket = webSocket
        bindWebSocket()
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = true
            self.reconnectAttempts = 0
            self.connectLocked()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = false
            self.reconnectWorkItem?.cancel()
            self.reconnectWorkItem = nil
            self.teardownLocked()
            self.setPhase(.idle)
        }
    }

    // MARK: - WebSocket

    private func bindWebSocket() {
        webSocket.onText = { [weak self] text in
            self?.queue.async { self?.handleTextLocked(text) }
        }
        webSocket.onBinary = { [weak self] data in
            self?.queue.async { self?.handleBinaryLocked(data) }
        }
        webSocket.onClosed = { [weak self] error in
            self?.queue.async { self?.handleClosedLocked(error) }
        }
    }

    private func connectLocked() {
        teardownLocked(resetPhase: false)
        setPhase(.connecting)
        receivedBackendReady = false
        micStarted = false

        let url = VoicePendantVoiceConfiguration.webSocketURL(deviceID: deviceID)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.webSocket.connect(url: url)
                self.queue.async {
                    self.setPhase(.waitingForHello)
                }
            } catch {
                self.queue.async {
                    self.handleFailureLocked("Could not connect to pendant voice service.")
                }
            }
        }
    }

    private func handleTextLocked(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "backend_ready":
            receivedBackendReady = true
            sendHelloLocked()
        case "speaker_begin":
            beginAssistantPlaybackLocked()
        case "speaker_end":
            endAssistantPlaybackLocked()
        default:
            break
        }
    }

    private func handleBinaryLocked(_ data: Data) {
        guard receivedBackendReady || micStarted else { return }
        do {
            if phase != .assistantSpeaking {
                try player.prepare()
                setPhase(.assistantSpeaking)
            }
            player.enqueue(data)
        } catch {
            handleFailureLocked("Speaker playback failed.")
        }
    }

    private func sendHelloLocked() {
        Task {
            do {
                try await webSocket.sendJSON(VoicePendantVoiceConfiguration.helloPayload)
                self.queue.async {
                    self.startMicLocked()
                }
            } catch {
                self.queue.async {
                    self.handleFailureLocked("Voice handshake failed.")
                }
            }
        }
    }

    private func startMicLocked() {
        guard !micStarted else { return }
        Task {
            do {
                try await self.recorder.start { [weak self] chunk in
                    guard let self else { return }
                    self.queue.async {
                        self.sendMicChunkLocked(chunk)
                    }
                } onLevel: { [weak self] level in
                    guard let self else { return }
                    self.queue.async {
                        self.inputLevel = level
                        self.isUserSpeaking = level > 0.04 && self.phase != .assistantSpeaking
                        self.notifyDelegateLocked()
                    }
                }
                self.queue.async {
                    self.micStarted = true
                    self.reconnectAttempts = 0
                    self.setPhase(.streaming)
                }
            } catch {
                self.queue.async {
                    self.handleFailureLocked("Microphone capture failed.")
                }
            }
        }
    }

    private func sendMicChunkLocked(_ chunk: Data) {
        guard phase == .streaming || phase == .assistantSpeaking else { return }
        Task {
            do {
                try await webSocket.sendBinary(chunk)
            } catch {
                self.queue.async {
                    self.handleClosedLocked(error)
                }
            }
        }
    }

    private func beginAssistantPlaybackLocked() {
        do {
            try player.prepare()
            isUserSpeaking = false
            setPhase(.assistantSpeaking)
        } catch {
            handleFailureLocked("Could not start assistant playback.")
        }
    }

    private func endAssistantPlaybackLocked() {
        isUserSpeaking = false
        if micStarted {
            setPhase(.streaming)
        } else if receivedBackendReady {
            setPhase(.waitingForHello)
        }
    }

    private func handleClosedLocked(_ error: Error?) {
        teardownLocked(resetPhase: false)
        guard shouldReconnect else {
            setPhase(.idle)
            return
        }
        scheduleReconnectLocked()
    }

    private func scheduleReconnectLocked() {
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        setPhase(.connecting)
        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.connectLocked()
        }
        reconnectWorkItem = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleFailureLocked(_ message: String) {
        teardownLocked(resetPhase: false)
        setPhase(.error)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.voiceManager(self, didFail: message)
        }
        if shouldReconnect {
            scheduleReconnectLocked()
        }
    }

    private func teardownLocked(resetPhase: Bool = true) {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        recorder.stop()
        player.stop()
        webSocket.disconnect()
        micStarted = false
        receivedBackendReady = false
        isUserSpeaking = false
        inputLevel = 0
        if resetPhase {
            setPhase(.idle)
        }
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        notifyDelegateLocked()
    }

    private func notifyDelegateLocked() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.voiceManagerDidUpdateState(self)
        }
    }
}
