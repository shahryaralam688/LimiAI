//
//  LightControllingSocket.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 28/10/2025.
//

import Combine
import Foundation
import SocketIO

class LightControllingSocket: ObservableObject {
    static let shared = LightControllingSocket()

    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
    }

    private var manager: SocketManager
    private var socket: SocketIOClient
    private var lastConnectAuthToken: String?
    private var wantsConnection = false
    private var authCancellable: AnyCancellable?
    private var authSessionCancellable: AnyCancellable?
    private var lastConnectAttemptAt: Date = .distantPast
    private let connectDebounce: TimeInterval = 1.5

    /// Side-channel taps that get notified whenever a `device_status` event
    /// arrives. Used by SocketIOMQTTBridge to surface MQTT presence into
    /// DeviceTransportState. Multiple handlers are supported.
    private var presenceHandlers: [(UUID, (String, String) -> Void)] = []

    /// Published for UI banners (DeviceApp / home). Updated on main thread.
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected

    /// True while the underlying SocketIO connection is connected.
    var isConnected: Bool { socket.status == .connected }

    private init() {
        let token = Self.currentConnectAuthToken()
        lastConnectAuthToken = token
        (manager, socket) = Self.makeManagerAndSocket(authToken: token)
        setupSocketEvents()
        observeAuthChanges()
    }

    /// Raw JWT for Socket.IO connect param `auth` (not HTTP `Authorization` — see `LimiAPIAuthPolicy`).
    private static func currentConnectAuthToken() -> String {
        AuthManager.shared.getToken() ?? ""
    }

    private static func makeManagerAndSocket(authToken: String) -> (SocketManager, SocketIOClient) {
        let url = AppURLs.Realtime.socketIOURL
        let manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                .connectParams(["auth": authToken]),
            ]
        )
        return (manager, manager.defaultSocket)
    }

    private func observeAuthChanges() {
        authCancellable = AuthManager.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                if isAuthenticated {
                    if self.wantsConnection {
                        self.refreshSocketWithCurrentAuth(andConnect: true)
                    }
                } else {
                    self.wantsConnection = false
                    self.socket.disconnect()
                }
            }

        authSessionCancellable = NotificationCenter.default
            .publisher(for: .limiAuthSessionDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let token = Self.currentConnectAuthToken()
                if LightControllingSocketAuthPolicy.shouldForceDisconnect(token: token) {
                    self.wantsConnection = false
                    self.socket.disconnect()
                    return
                }
                guard self.wantsConnection else { return }
                self.refreshSocketWithCurrentAuth(andConnect: true)
            }
    }

    private func refreshSocketWithCurrentAuth(andConnect: Bool) {
        let token = Self.currentConnectAuthToken()
        if LightControllingSocketAuthPolicy.shouldRebuildSocket(
            lastToken: lastConnectAuthToken,
            currentToken: token
        ) {
            rebuildSocket(authToken: token)
        }
        if andConnect {
            socket.connect()
        }
    }

    private func rebuildSocket(authToken: String) {
        socket.disconnect()
        socket.removeAllHandlers()

        (manager, socket) = Self.makeManagerAndSocket(authToken: authToken)
        lastConnectAuthToken = authToken
        setupSocketEvents()
    }

    private func setupSocketEvents() {
        // Listen for connection
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            DeviceConsole.log(.socket, "connected → \(AppURLs.Realtime.socketIOURL.absoluteString)")
            self?.publishConnectionStatus(.connected)
        }

        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            DeviceConsole.log(.socket, "reconnected")
            self?.publishConnectionStatus(.connected)
        }

        // Listen for disconnection
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            DeviceConsole.log(.socket, "disconnected reason=\(data)")
            self?.publishConnectionStatus(.disconnected)
        }

        // Listen for server_hello event
        socket.on("server_hello") { data, ack in
            DeviceConsole.log(.socket, "← server_hello \(Self.compactPayload(data))")
        }

        // Listen for light control responses
        socket.on("light_controll_response") { data, ack in
            DeviceConsole.log(.socket, "← light_controll_response \(Self.compactPayload(data))")
        }

        socket.on("virtual_light_control_response") { data, ack in
            DeviceConsole.log(.socket, "← virtual_light_control_response \(Self.compactPayload(data))")
        }

        // Listen for any general responses
        socket.on("response") { data, ack in
            DeviceConsole.log(.socket, "← response \(Self.compactPayload(data))")
        }

        // Listen for acknowledgments or status updates
        socket.on("status") { data, ack in
            DeviceConsole.log(.socket, "← status \(Self.compactPayload(data))")
        }

        socket.on("device_status") { [weak self] data, ack in
            DeviceConsole.log(.socket, "← SOCKET REPLY event=device_status raw=\(Self.compactPayload(data))")
            guard let raw = data.first else {
                DeviceConsole.log(.presence, "← device_status (empty payload) — no id/status")
                return
            }
            var parsed: (deviceId: String, status: String, pendantTypes: String?)?
            if let dict = raw as? [String: Any] {
                parsed = Self.parseDeviceStatusDict(dict)
            } else if let jsonString = raw as? String,
                      let jsonData = jsonString.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                parsed = Self.parseDeviceStatusDict(dict)
            } else {
                DeviceConsole.log(.presence, "← device_status (unparsed) \(raw)")
            }
            if let parsed {
                let hw = LimiDeviceNaming.normalizedHardwareId(parsed.deviceId)
                let pendant = parsed.pendantTypes.map { " pendant=\($0)" } ?? ""
                DeviceConsole.log(
                    .presence,
                    "← SOCKET device_status id=\(parsed.deviceId) hw=\(hw) status=\(parsed.status)\(pendant)"
                )
                DevicePendantTypeStore.shared.update(
                    deviceId: parsed.deviceId,
                    pendantTypes: parsed.pendantTypes
                )
                if let self {
                    for (_, handler) in self.presenceHandlers {
                        handler(parsed.deviceId, parsed.status)
                    }
                }
            }
        }

        // Log every other server→client event so missing device_status is obvious in console.
        listenForAllEvents()
        // Listen for any errors
        socket.on(clientEvent: .error) { [weak self] data, ack in
            let detail = Self.compactPayload(data)
            DeviceConsole.log(.socket, "error \(detail)")
            guard let self else { return }
            // Socket.IO can emit transient errors while still connected — avoid UI flicker.
            if self.socket.status == .connected {
                return
            }
            self.publishConnectionStatus(self.wantsConnection ? .connecting : .disconnected)
        }
    }

    func connect() {
        wantsConnection = true
        let now = Date()
        if socket.status == .connected {
            publishConnectionStatus(.connected)
            return
        }
        if socket.status == .connecting,
           now.timeIntervalSince(lastConnectAttemptAt) < connectDebounce {
            publishConnectionStatus(.connecting)
            return
        }
        lastConnectAttemptAt = now
        publishConnectionStatus(.connecting)
        DeviceConsole.log(.socket, "connecting…")
        refreshSocketWithCurrentAuth(andConnect: true)
    }

    func disconnect() {
        wantsConnection = false
        DeviceConsole.log(.socket, "disconnect() called")
        socket.disconnect()
        publishConnectionStatus(.disconnected)
    }

    private func publishConnectionStatus(_ status: ConnectionStatus) {
        let apply = { [weak self] in
            guard let self, self.connectionStatus != status else { return }
            self.connectionStatus = status
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Virtual master device control — backend fans out to member hubs over MQTT.
    func sendVirtualLightControl(
        virtualDeviceId: String,
        command: [String: Any],
        acknowledgment: ((TimeInterval, Bool) -> Void)? = nil
    ) {
        let trimmedID = virtualDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }
        guard socket.status == .connected else {
            DeviceConsole.log(.socket, "skip virtual_light_control — socket not connected id=\(trimmedID)")
            return
        }

        let payload: [String: Any] = [
            "virtual_device_id": trimmedID,
            "command": command,
        ]

        let sentAt = Date()
        DeviceConsole.log(
            .socket,
            "→ virtual_light_control id=\(trimmedID) \(Self.compactDict(payload))"
        )
        socket.emitWithAck("virtual_light_control", payload).timingOut(after: 5.0) { data in
            let roundTrip = Date().timeIntervalSince(sentAt)
            let didReceiveAck = !data.isEmpty
            DeviceConsole.log(
                .socket,
                "← virtual_light_control ack rtt=\(String(format: "%.0f", roundTrip * 1000))ms ok=\(didReceiveAck)"
            )
            acknowledgment?(roundTrip, didReceiveAck)
        }
    }

    func sendLightControlOnOff(message: [String]) {
        guard message.count >= 2 else {
            return
        }

        let deviceId = message[0].uppercased()
        let onoff = String(message[1])


        let lightData: [String: Any] = [
            "deviceId": deviceId,
            "command": [
                "onoff": onoff
                ]

        ]

        DeviceConsole.log(.socket, "→ light_controll onoff id=\(deviceId) onoff=\(onoff)")
        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
            DeviceConsole.log(.socket, "← light_controll ack \(Self.compactPayload(data))")
        }

    }
    func sendLightControl(
        message: [String],
        acknowledgment: ((TimeInterval, Bool) -> Void)? = nil
    ) {
        guard message.count >= 5 else {
            return
        }
        guard socket.status == .connected else {
            DeviceConsole.log(.socket, "skip light_controll — socket not connected")
            return
        }

        let deviceId = message[0].uppercased()
        let channelPosition = Int(message[1]) ?? 1
        let red = Int(message[2]) ?? 0
        let green = Int(message[3]) ?? 0
        let blue = Int(message[4]) ?? 0

        let lightData: [String: Any] = [
            "deviceId": deviceId,
            "command": [
                "channel": channelPosition,
                "ww": red,
                "cw": green,
                "brightness": blue
            ]
        ]

        let sentAt = Date()
        DeviceConsole.log(
            .socket,
            "→ light_controll cct id=\(deviceId) ch=\(channelPosition) ww=\(red) cw=\(green) bri=\(blue)"
        )
        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
            let roundTrip = Date().timeIntervalSince(sentAt)
            let didReceiveAck = !data.isEmpty
            DeviceConsole.log(
                .socket,
                "← light_controll ack rtt=\(String(format: "%.0f", roundTrip * 1000))ms ok=\(didReceiveAck)"
            )
            acknowledgment?(roundTrip, didReceiveAck)
        }

    }
    func sendLightControlRGB(message: [String]) {
        guard message.count >= 6 else {
            return
        }
        guard socket.status == .connected else {
            DeviceConsole.log(.socket, "skip light_controll RGB — socket not connected")
            return
        }

        let deviceId = message[0].uppercased()
        let channelPosition = Int(message[1]) ?? 1
        let red = Int(message[2]) ?? 0
        let green = Int(message[3]) ?? 0
        let blue = Int(message[4]) ?? 0
        let brightness = Int(message[5]) ?? 0

        let lightData: [String: Any] = [
            "deviceId": deviceId,
            "command": [
                "channel": channelPosition,
                "red": red,
                "green": green,
                "blue": blue,
                "brightness": brightness
            ]
        ]

        DeviceConsole.log(
            .socket,
            "→ light_controll rgb id=\(deviceId) ch=\(channelPosition) r=\(red) g=\(green) b=\(blue) bri=\(brightness)"
        )
        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
            DeviceConsole.log(.socket, "← light_controll ack \(Self.compactPayload(data))")
        }

    }
    func sendSampleData() {
        // Dummy data in the same format as your message array
        let byteArray: [String] = [
            "80B54EE8B228", // deviceId
            "220",          // red
            "20",           // green
            "200"           // blue
        ]

        sendLightControl(message: byteArray)
    }

    // MARK: - Pattern Control (RGB Effects)
    /// Send a pattern command to the device.
    /// Pattern `id`, RGB color, speed and intensity are provided by the caller.
    ///
    /// JSON structure:
    /// {
    ///   "deviceId": "MAC",
    ///   "command": {
    ///     "channel": 2,
    ///     "pattern": {
    ///       "id": <id>,
    ///       "speed": <speed>,
    ///       "intensity": <intensity>,
    ///       "color": [r, g, b]
    ///     }
    ///   }
    /// }
    func sendPatternControl(
        deviceId: String,
        channelPosition: Int,
        patternId: Int,
        red: Int,
        green: Int,
        blue: Int,
        speed: Int,
        intensity: Int
    ) {
        guard socket.status == .connected else {
            return
        }

        let upperDeviceId = deviceId.uppercased()

        let patternData: [String: Any] = [
            "deviceId": upperDeviceId,
            "command": [
                "channel": channelPosition,
                "pattern": [
                    "id": patternId,
                    "speed": speed,
                    "intensity": intensity,
                    "color": [red, green, blue]
                ]
            ]
        ]

        socket.emitWithAck("light_controll", patternData).timingOut(after: 5.0) { data in
        }

    }
    // Method to add custom event listeners
    func listenForCustomEvent(_ eventName: String) {
        socket.on(eventName) { data, ack in
        }
    }

    // Method to listen for all events (useful for debugging)
    func listenForAllEvents() {
        let skip = Set([
            "connect", "disconnect", "reconnect", "error",
            "ping", "pong", "device_status"
        ])
        socket.onAny { event in
            let name = event.event
            if skip.contains(name) { return }
            if name.hasPrefix("websocket") || name.hasPrefix("engine") { return }
            let items = event.items ?? []
            DeviceConsole.log(
                .socket,
                "← SOCKET REPLY event=\(name) payload=\(Self.compactPayload(items))"
            )
        }
    }

    // MARK: - Transport bridge hooks (used by SocketIOMQTTBridge)

    /// Register a tap that fires every time a `device_status` event arrives.
    /// Passes `(deviceId, status)` as raw strings.
    /// - Returns: Token for `unregisterPresenceHandler` (provisioning must remove itself on finish).
    @discardableResult
    func registerPresenceHandler(_ handler: @escaping (String, String) -> Void) -> UUID {
        let id = UUID()
        presenceHandlers.append((id, handler))
        return id
    }

    func unregisterPresenceHandler(_ id: UUID) {
        presenceHandlers.removeAll { $0.0 == id }
    }

    private static func parseDeviceStatusDict(_ dict: [String: Any]) -> (deviceId: String, status: String, pendantTypes: String?) {
        let deviceId = dict["deviceId"] as? String ?? "<unknown>"
        let status = dict["status"] as? String ?? "<unknown>"
        let pendantTypes = (dict["pendantTypes"] as? String)
            ?? (dict["pendantType"] as? String)
            ?? (dict["pendant_types"] as? String)
        return (deviceId, status, pendantTypes)
    }

    /// Generic emit-with-ack helper used by the transport layer to publish
    /// arbitrary command/reset payloads through the existing Socket.IO bridge.
    func emitWithAck(
        event: String,
        payload: [String: Any],
        timeoutSeconds: Double = 5.0,
        completion: @escaping ([Any]) -> Void
    ) {
        guard socket.status == .connected else {
            DeviceConsole.log(.socket, "skip emit \(event) — socket not connected")
            completion([])
            return
        }
        let deviceId = (payload["deviceId"] as? String) ?? "?"
        DeviceConsole.log(.socket, "→ \(event) id=\(deviceId) \(Self.compactDict(payload))")
        socket.emitWithAck(event, payload).timingOut(after: timeoutSeconds) { data in
            DeviceConsole.log(.socket, "← \(event) ack \(Self.compactPayload(data))")
            completion(data)
        }
    }

    private static func compactPayload(_ data: [Any]) -> String {
        guard !data.isEmpty else { return "(empty)" }
        if let dict = data.first as? [String: Any] {
            return compactDict(dict)
        }
        return String(describing: data.first ?? data)
    }

    private static func compactDict(_ dict: [String: Any]) -> String {
        let keys = ["deviceId", "virtual_device_id", "status", "pendantTypes", "pendantType", "firmwareVersion", "command", "reset", "channel", "onoff", "power"]
        var parts: [String] = []
        for key in keys {
            if let value = dict[key] {
                parts.append("\(key)=\(value)")
            }
        }
        if parts.isEmpty {
            return String(describing: dict)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Auth refresh policy (Phase M — unit-testable)

enum LightControllingSocketAuthPolicy {
    static func shouldRebuildSocket(lastToken: String?, currentToken: String) -> Bool {
        lastToken != currentToken
    }

    static func shouldForceDisconnect(token: String) -> Bool {
        token.isEmpty
    }
}
