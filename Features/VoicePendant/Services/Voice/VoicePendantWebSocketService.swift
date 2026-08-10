//
//  VoicePendantWebSocketService.swift
//  Limi
//
//  URLSessionWebSocketTask transport for the Limi backend voice protocol.
//

import Foundation

protocol VoicePendantWebSocketServicing: AnyObject {
    var onText: ((String) -> Void)? { get set }
    var onBinary: ((Data) -> Void)? { get set }
    var onClosed: ((Error?) -> Void)? { get set }

    func connect(url: URL) async throws
    func sendJSON(_ object: [String: Any]) async throws
    func sendBinary(_ data: Data) async throws
    func disconnect()
}

final class VoicePendantWebSocketService: NSObject, VoicePendantWebSocketServicing {
    var onText: ((String) -> Void)?
    var onBinary: ((Data) -> Void)?
    var onClosed: ((Error?) -> Void)?

    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private var task: URLSessionWebSocketTask?
    private let queue = DispatchQueue(label: "voicePendant.websocket")
    private var isReceiving = false

    func connect(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: VoicePendantVoiceError.deallocated)
                    return
                }
                self.disconnectLocked()
                let wsTask = self.session.webSocketTask(with: url)
                self.task = wsTask
                wsTask.resume()
                self.isReceiving = true
                self.receiveLoop()
                continuation.resume()
            }
        }
    }

    func sendJSON(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw VoicePendantVoiceError.invalidJSON
        }
        try await send(text: text)
    }

    func sendBinary(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self, let task = self.task else {
                    continuation.resume(throwing: VoicePendantVoiceError.notConnected)
                    return
                }
                task.send(.data(data)) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            self?.disconnectLocked()
        }
    }

    private func disconnectLocked() {
        isReceiving = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func send(text: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self, let task = self.task else {
                    continuation.resume(throwing: VoicePendantVoiceError.notConnected)
                    return
                }
                task.send(.string(text)) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func receiveLoop() {
        guard isReceiving, let task else { return }
        task.receive { [weak self] result in
            guard let self, self.isReceiving else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.onText?(text)
                case .data(let data):
                    self.onBinary?(data)
                @unknown default:
                    break
                }
                self.receiveLoop()
            case .failure(let error):
                self.isReceiving = false
                self.onClosed?(error)
            }
        }
    }
}

extension VoicePendantWebSocketService: URLSessionWebSocketDelegate {}

enum VoicePendantVoiceError: LocalizedError {
    case deallocated
    case notConnected
    case invalidJSON
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .deallocated: return "Voice service unavailable."
        case .notConnected: return "Not connected to the pendant voice service."
        case .invalidJSON: return "Invalid voice protocol message."
        case .microphoneUnavailable: return "Microphone unavailable."
        }
    }
}
