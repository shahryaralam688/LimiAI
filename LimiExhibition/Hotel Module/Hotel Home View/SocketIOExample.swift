// SocketIOExample.swift
// Works with socketio/socket.io-client-swift via SPM or CocoaPods

import Foundation
import SocketIO

final class SocketIOExample {
    var onOrderUpdate: ((String) -> Void)? // Called with action value from order_update

    private let manager: SocketIO.SocketManager
    private let socket: SocketIOClient

    init?() {
        let urlString = APIConstants.baseURL
        guard let url = URL(string: urlString) else {
            print("Invalid server URL")
            return nil
        }

        // Make the configuration type explicit to avoid Any/ambiguity issues
        let config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            // Useful with Cloudflare tunnels / proxies:
            .secure(true),              // because you're using https
            .forceWebsockets(true),     // skip polling if your tunnel blocks it
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(2)
        ]

        self.manager = SocketIO.SocketManager(socketURL: url, config: config)

        // Both forms work depending on library version; pick one:
        if let defaultSock = manager.defaultSocket as SocketIOClient? {
            self.socket = defaultSock
        } else {
            // Fallback for versions that prefer namespaced sockets
            self.socket = manager.socket(forNamespace: "/")
        }

        setupListeners()
    }

    private func setupListeners() {
        socket.on(clientEvent: .connect) { _, _ in
            print("Socket connected")
        }

        socket.on("ID") { data, _ in
            print("Received 'ID' event:", data)
        }

        socket.on("order_update") { data, _ in
            print("Received 'order_update' event:", data)

            // Parse: { extracted: { light: { action: "..." } } }
            if let dict = (data.first as? [String: Any]),
               let extracted = dict["extracted"] as? [String: Any],
               let light = extracted["light"] as? [String: Any],
               let action = light["action"] as? String {
                print("Parsed action: \(action)")
                self.onOrderUpdate?(action)
            } else {
                print("Could not parse 'action' from order_update")
            }
        }

        socket.on("server_hello") { data, _ in
            print("Received 'server_hello' event:", data)
        }

        socket.on(clientEvent: .error) { data, _ in
            print("Socket error:", data)
        }

        socket.on(clientEvent: .disconnect) { data, _ in
            print("Socket disconnected:", data)
        }
    }

    func connect() { socket.connect() }
    func disconnect() { socket.disconnect() }
}
