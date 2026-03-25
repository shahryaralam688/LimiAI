//
//  LightControllingSocket.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 28/10/2025.
//

import Foundation
import SocketIO

class LightControllingSocket: ObservableObject {
    static let shared = LightControllingSocket()

    private var manager: SocketManager
    private var socket: SocketIOClient
    
    private init() {
        // Initialize socket manager with the provided URL
        let token = AuthManager.shared.getToken() ?? ""
        guard let url = URL(string: APIConstants.baseURL) else {
            fatalError("Invalid socket URL")
        }

        // Pass auth token as connect parameter so it appears on all /socket.io requests
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(true),
                .compress,
                .connectParams(["auth": token])
            ]
        )
        socket = manager.defaultSocket
        
        setupSocketEvents()
    }
    
    private func setupSocketEvents() {
        // Listen for connection
        socket.on(clientEvent: .connect) { data, ack in
            print("Socket connected successfully")
        }
        
        // Listen for disconnection
        socket.on(clientEvent: .disconnect) { data, ack in
            print("Socket disconnected")
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
        
        socket.on("device_status") { data, ack in
            guard let raw = data.first else {
                print("Received device_status with no payload: \(data)")
                return
            }
            if let dict = raw as? [String: Any] {
                let deviceId = dict["deviceId"] as? String ?? "<unknown>"
                let status = dict["status"] as? String ?? "<unknown>"
                print("📩 device_status => deviceId: \(deviceId), status: \(status)")
            } else if let jsonString = raw as? String,
                      let jsonData = jsonString.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                let deviceId = dict["deviceId"] as? String ?? "<unknown>"
                let status = dict["status"] as? String ?? "<unknown>"
                print("📩 device_status (string JSON) => deviceId: \(deviceId), status: \(status)")
            } else {
                print("Received device_status with unexpected payload: \(data)")
            }
        }
        // Listen for any errors
        socket.on(clientEvent: .error) { data, ack in
            print("Socket error: \(data)")
        }
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
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
            print("✅ Light control acknowledgment received: \(data)")
        }
        
        print("📤 Sent light control data: \(lightData)")
    }
    func sendLightControl(message: [String]) {
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
        
        socket.emitWithAck("light_controll", lightData).timingOut(after: 5.0) { data in
            print("✅ Light control acknowledgment received: \(data)")
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
            print("✅ Light control acknowledgment received: \(data)")
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
}
