//
//  SocketIOMQTTBridge.swift
//  Limi
//
//  Adapter that lets LimiTransport's "MQTT door" run on top of the existing
//  Socket.IO backend (LightControllingSocket). The backend is responsible for
//  forwarding our payload onto the actual MQTT topic device/<id>/command.
//
//  Replace this with a CocoaMQTT-based implementation when you decide to
//  add a real broker client — LimiTransport will not need to change.
//

import Foundation
import Combine
import SocketIO

public final class SocketIOMQTTBridge: NSObject, MQTTClient {
    public static let shared = SocketIOMQTTBridge()

    /// Event name backend listens for. Must match LightControllingSocket today.
    private let commandEvent = "light_controll"

    /// Room/group control — separate from single-device `light_controll`.
    private let groupCommandEvent = "group_light_control"

    /// Separate event so reset is never mixed with command (per spec).
    private let resetEvent = "device_reset"

    private let presenceSubject = PassthroughSubject<MQTTPresenceUpdate, Never>()
    private var registered = false

    public var presencePublisher: AnyPublisher<MQTTPresenceUpdate, Never> {
        presenceSubject.eraseToAnyPublisher()
    }

    private override init() {
        super.init()
        registerPresenceHandler()
    }

    // MARK: - MQTTClient

    public func publishCommand(_ payload: Data, deviceId: String) async throws {
        guard let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw LimiTransportError.badCommand
        }
        try await emit(event: commandEvent, payload: json)
    }

    public func publishGroupCommand(_ payload: Data) async throws {
        guard let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw LimiTransportError.badCommand
        }
        try await emit(event: groupCommandEvent, payload: json)
    }

    public func publishReset(deviceId: String) async throws {
        let payload: [String: Any] = [
            "deviceId": deviceId.uppercased(),
            "reset": true
        ]
        try await emit(event: resetEvent, payload: payload)
    }

    // MARK: - Internal

    private func emit(event: String, payload: [String: Any]) async throws {
        let socket = LightControllingSocket.shared
        guard socket.isConnected else {
            throw LimiTransportError.doorUnavailable(.mqtt)
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            socket.emitWithAck(event: event, payload: payload, timeoutSeconds: 5.0) { _ in
                continuation.resume()
            }
        }
    }

    /// Wires `device_status` (and any future presence event) through to the
    /// presence publisher so DeviceTransportRegistry can fan it out.
    private func registerPresenceHandler() {
        guard !registered else { return }
        registered = true
        LightControllingSocket.shared.registerPresenceHandler { [weak self] deviceId, status in
            guard let self else { return }
            guard LimiDeviceNaming.isDefinitePresenceStatus(status) else {
                DeviceConsole.log(.presence, "ignore non-definite status id=\(deviceId) status=\(status)")
                return
            }
            let connected = LimiDeviceNaming.isOnlinePresenceStatus(status)
            DeviceConsole.log(
                .presence,
                "MQTT bridge id=\(deviceId) connected=\(connected) raw=\(status)"
            )
            self.presenceSubject.send(MQTTPresenceUpdate(deviceId: deviceId, connected: connected))
        }
    }

    /// External hook: a 503 mqtt_active response from a WebSocket attempt
    /// is itself proof that MQTT is up.
    public func reportObservedMQTTActive(deviceId: String) {
        DeviceConsole.log(.presence, "MQTT observed via WS 503 id=\(deviceId)")
        presenceSubject.send(MQTTPresenceUpdate(deviceId: deviceId, connected: true))
    }
}
