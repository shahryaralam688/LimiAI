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

    /// Side-channel taps that get notified whenever a `device_status` event
    /// arrives. Used by SocketIOMQTTBridge to surface MQTT presence into
    /// DeviceTransportState. Multiple handlers are supported.
    private var presenceHandlers: [(String, String) -> Void] = []

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
                .log(true),
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
            print("Socket connected successfully")
            self?.publishConnectionStatus(.connected)
        }

        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            self?.publishConnectionStatus(.connected)
        }

        // Listen for disconnection
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("Socket disconnected")
            self?.publishConnectionStatus(.disconnected)
        }

        // Listen for server_hello event
        socket.on("server_hello") { data, ack in
            print("Received server_hello event: \(data)")
        }

        // Listen for light control responses
        socket.on("light_controll_response") { data, ack in
            print("Received light control response: \(data)")
        }

        // Listen for any general responses
        socket.on("response") { data, ack in
            print("Received general response: \(data)")
        }

        // Listen for acknowledgments or status updates
        socket.on("status") { data, ack in
            print("Received status update: \(data)")
        }

        socket.on("device_status") { [weak self] data, ack in
            guard let raw = data.first else {
                print("Received device_status with no payload: \(data)")
                return
            }
            var parsed: (deviceId: String, status: String, pendantTypes: String?)?
            if let dict = raw as? [String: Any] {
                parsed = Self.parseDeviceStatusDict(dict)
                if let parsed {
                    print("📩 device_status => deviceId: \(parsed.deviceId), status: \(parsed.status), pendantTypes: \(parsed.pendantTypes ?? "nil")")
                }
            } else if let jsonString = raw as? String,
                      let jsonData = jsonString.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                parsed = Self.parseDeviceStatusDict(dict)
                if let parsed {
                    print("📩 device_status (string JSON) => deviceId: \(parsed.deviceId), status: \(parsed.status), pendantTypes: \(parsed.pendantTypes ?? "nil")")
                }
            } else {
                print("Received device_status with unexpected payload: \(data)")
            }
            if let parsed {
                DevicePendantTypeStore.shared.update(
                    deviceId: parsed.deviceId,
                    pendantTypes: parsed.pendantTypes
                )
                if let self {
                    for handler in self.presenceHandlers {
                        handler(parsed.deviceId, parsed.status)
                    }
                }
            }
        }
        // Listen for any errors
        socket.on(clientEvent: .error) { [weak self] data, ack in
            print("Socket error: \(data)")
            guard let self else { return }
            if self.socket.status != .connected {
                self.publishConnectionStatus(self.wantsConnection ? .connecting : .disconnected)
            }
        }
    }

    func connect() {
        wantsConnection = true
        if socket.status != .connected {
            publishConnectionStatus(.connecting)
        }
        refreshSocketWithCurrentAuth(andConnect: true)
    }

    func disconnect() {
        wantsConnection = false
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

    func sendLightControlOnOff(message: [String]) {
        guard message.count >= 2 else {
            print("⚠️ Invalid message format: \(message)")
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

        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
//            ??print("✅ Light control acknowledgment received: \(data)")
        }

        print("📤 Sent light control data: \(lightData)")
    }
    func sendLightControl(
        message: [String],
        acknowledgment: ((TimeInterval, Bool) -> Void)? = nil
    ) {
        guard message.count >= 5 else {
            print("⚠️ Invalid message format: \(message)")
            return
        }
        guard socket.status == .connected else {
            print("⚠️ Socket not connected (status = \(socket.status)), skipping light_controll emit")
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
        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
            let roundTrip = Date().timeIntervalSince(sentAt)
            let didReceiveAck = !data.isEmpty
//            print("✅ Light control acknowledgment received: \(data)")
            acknowledgment?(roundTrip, didReceiveAck)
        }

        print("📤 Sent light control data: \(lightData)")
    }
    func sendLightControlRGB(message: [String]) {
        guard message.count >= 6 else {
            print("⚠️ Invalid message format: \(message)")
            return
        }
        guard socket.status == .connected else {
            print("⚠️ Socket not connected (status = \(socket.status)), skipping light_controll RGB emit")
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

        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
//            print("✅ Light control acknowledgment received: \(data)")
        }

        print("📤 Sent light control data: \(lightData)")
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
            print("⚠️ Socket not connected (status = \(socket.status)), skipping pattern control emit")
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
            print("✅ Pattern control acknowledgment received: \(data)")
        }

        print("📤 Sent pattern control data: \(patternData)")
    }
    // Method to add custom event listeners
    func listenForCustomEvent(_ eventName: String) {
        socket.on(eventName) { data, ack in
            print("Received custom event '\(eventName)': \(data)")
        }
    }

    // Method to listen for all events (useful for debugging)
    func listenForAllEvents() {
        socket.onAny { event in
            print("Received any event: \(event.event) with data: \(event.items ?? [])")
        }
    }

    // MARK: - Transport bridge hooks (used by SocketIOMQTTBridge)

    /// Register a tap that fires every time a `device_status` event arrives.
    /// Passes `(deviceId, status)` as raw strings.
    func registerPresenceHandler(_ handler: @escaping (String, String) -> Void) {
        presenceHandlers.append(handler)
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
            print("⚠️ emitWithAck '\(event)' skipped — socket status \(socket.status)")
            completion([])
            return
        }
        socket.emitWithAck(event, payload).timingOut(after: timeoutSeconds) { data in
            completion(data)
        }
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
