//
//  DeviceWebSocketClient.swift
//  Limi
//
//  One LAN WebSocket per device → AppURLs.Device.webSocketURL(ip:).
//  Detects HTTP 503 mqtt_active on the upgrade response and translates it to
//  LimiTransportError.mqttActive. Does NOT auto-retry on 503 (per spec).
//
//  Connect is concurrency-safe: multiple callers wait on one handshake via a
//  waiter list (a single CheckedContinuation used to be overwritten and crash).
//

import Foundation

public final class DeviceWebSocketClient: NSObject {
    public static let shared = DeviceWebSocketClient()

    /// Per-device state. Keyed by uppercased deviceId.
    private final class Connection {
        let deviceId: String
        let ipAddress: String
        var task: URLSessionWebSocketTask?
        var connecting: Bool = false
        var receiveLoopStarted: Bool = false
        /// All callers waiting for the current handshake to finish.
        var connectWaiters: [CheckedContinuation<Void, Error>] = []

        init(deviceId: String, ipAddress: String) {
            self.deviceId = deviceId
            self.ipAddress = ipAddress
        }
    }

    private var connections: [String: Connection] = [:]
    private let queueLock = NSLock()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }()

    private override init() { super.init() }

    // MARK: - Public API

    /// Send a JSON envelope over the device's LAN WebSocket. Connects lazily.
    /// Throws `.mqttActive` if firmware returns HTTP 503 mqtt_active.
    public func send(_ payload: Data, deviceId: String, ipAddress: String) async throws {
        let key = deviceId.uppercased()
        let connection = ensureConnection(deviceId: key, ipAddress: ipAddress)

        try await connectIfNeeded(connection)

        guard let task = connection.task, task.state == .running else {
            throw LimiTransportError.doorUnavailable(.webSocket)
        }

        let message = URLSessionWebSocketTask.Message.data(payload)
        do {
            try await task.send(message)
        } catch {
            // Task failed mid-flight — surface as unreachable (door rule will
            // re-evaluate on next call).
            disconnect(deviceId: key)
            throw mapError(error)
        }
    }

    /// Force-close the per-device socket (e.g. when door switches away from WS).
    public func disconnect(deviceId: String) {
        let key = deviceId.uppercased()
        queueLock.lock()
        let connection = connections.removeValue(forKey: key)
        let waiters = connection?.connectWaiters ?? []
        connection?.connectWaiters.removeAll()
        queueLock.unlock()
        connection?.task?.cancel(with: .normalClosure, reason: nil)
        for waiter in waiters {
            waiter.resume(throwing: LimiTransportError.deviceUnreachable)
        }
    }

    public func disconnectAll() {
        queueLock.lock()
        let all = Array(connections.values)
        connections.removeAll()
        queueLock.unlock()
        for connection in all {
            let waiters = connection.connectWaiters
            connection.connectWaiters.removeAll()
            connection.task?.cancel(with: .normalClosure, reason: nil)
            for waiter in waiters {
                waiter.resume(throwing: LimiTransportError.deviceUnreachable)
            }
        }
    }

    // MARK: - Internal

    private func ensureConnection(deviceId: String, ipAddress: String) -> Connection {
        queueLock.lock()
        defer { queueLock.unlock() }
        if let existing = connections[deviceId] {
            // If the IP changed (DHCP), tear down and rebuild.
            if existing.ipAddress != ipAddress {
                let staleWaiters = existing.connectWaiters
                existing.connectWaiters.removeAll()
                existing.task?.cancel(with: .normalClosure, reason: nil)
                for waiter in staleWaiters {
                    waiter.resume(throwing: LimiTransportError.deviceUnreachable)
                }
                let fresh = Connection(deviceId: deviceId, ipAddress: ipAddress)
                connections[deviceId] = fresh
                return fresh
            }
            return existing
        }
        let fresh = Connection(deviceId: deviceId, ipAddress: ipAddress)
        connections[deviceId] = fresh
        return fresh
    }

    private func connectIfNeeded(_ connection: Connection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queueLock.lock()

            if let existing = connection.task, existing.state == .running {
                queueLock.unlock()
                continuation.resume()
                return
            }

            // Another caller is already handshaking — join the waiter list.
            if connection.connecting {
                connection.connectWaiters.append(continuation)
                queueLock.unlock()
                return
            }

            guard let url = AppURLs.Device.webSocketURL(ip: connection.ipAddress) else {
                queueLock.unlock()
                continuation.resume(throwing: LimiTransportError.missingDeviceIP)
                return
            }

            let task = session.webSocketTask(with: url)
            connection.task = task
            connection.connecting = true
            connection.receiveLoopStarted = false
            connection.connectWaiters.append(continuation)
            queueLock.unlock()

            task.resume()
        }

        // Only the first successful connect starts the receive loop once.
        queueLock.lock()
        let shouldStartReceive =
            connection.task?.state == .running && !connection.receiveLoopStarted
        if shouldStartReceive {
            connection.receiveLoopStarted = true
        }
        queueLock.unlock()
        if shouldStartReceive {
            receiveLoop(on: connection)
        }
    }

    private func receiveLoop(on connection: Connection) {
        guard let task = connection.task else { return }
        task.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("⚠️ [DeviceWebSocketClient] receive error for \(connection.deviceId): \(error.localizedDescription)")
                self?.disconnect(deviceId: connection.deviceId)
            case .success(let message):
                self?.handleIncoming(message, on: connection)
                self?.receiveLoop(on: connection)
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message, on connection: Connection) {
        switch message {
        case .data(let data):
            log(data: data, deviceId: connection.deviceId)
        case .string(let string):
            log(data: string.data(using: .utf8) ?? Data(), deviceId: connection.deviceId)
        @unknown default:
            break
        }
    }

    private func log(data: Data, deviceId: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("📩 [WS \(deviceId)] non-JSON response (\(data.count) bytes)")
            return
        }
        let success = json["success"] as? Bool ?? false
        let source = json["source"] as? String ?? "?"
        let error = json["error"] as? String ?? ""
        print("📩 [WS \(deviceId)] success=\(success) source=\(source) error=\(error)")
    }

    private func mapError(_ error: Error) -> LimiTransportError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCancelled, NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return .deviceUnreachable
            default:
                break
            }
        }
        return .deviceUnreachable
    }

    fileprivate func resolveContinuation(for task: URLSessionTask, with result: Result<Void, Error>) {
        queueLock.lock()
        let connection = connections.values.first { $0.task === task }
        let waiters = connection?.connectWaiters ?? []
        connection?.connectWaiters.removeAll()
        connection?.connecting = false
        if case .failure = result {
            connection?.receiveLoopStarted = false
        }
        queueLock.unlock()

        for waiter in waiters {
            switch result {
            case .success:
                waiter.resume()
            case .failure(let err):
                waiter.resume(throwing: err)
            }
        }
    }
}

// MARK: - URLSession delegates (open + 503 detection)

extension DeviceWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        resolveContinuation(for: webSocketTask, with: .success(()))
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        print("🔴 [DeviceWebSocketClient] closed code=\(closeCode.rawValue) reason=\(reasonText)")
    }
}

extension DeviceWebSocketClient: URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // For a WebSocket upgrade, the only way to learn about a 503 mqtt_active
        // rejection is to inspect the HTTP response on the failed task.
        if let http = task.response as? HTTPURLResponse, http.statusCode == 503 {
            // Surface 503 as a strong signal that MQTT is active for that device.
            queueLock.lock()
            let key = connections.first(where: { $0.value.task === task })?.key
            queueLock.unlock()
            if let key {
                SocketIOMQTTBridge.shared.reportObservedMQTTActive(deviceId: key)
            }
            resolveContinuation(for: task, with: .failure(LimiTransportError.mqttActive))
            return
        }
        if let error = error {
            resolveContinuation(for: task, with: .failure(mapError(error)))
            return
        }
        // Normal close — nothing to resume.
    }
}
