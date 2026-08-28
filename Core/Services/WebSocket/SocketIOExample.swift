// SocketIOExample.swift
// Works with socketio/socket.io-client-swift via SPM or CocoaPods

import Foundation
import SocketIO

final class SocketIOExample {
    var onOrderUpdate: ((String) -> Void)? // Called with action value from order_update

    private let manager: SocketIO.SocketManager
    private let socket: SocketIOClient

    init?() {
        let url = AppURLs.Realtime.socketIOURL
        // Make the configuration type explicit to avoid Any/ambiguity issues
        let config: SocketIOClientConfiguration = [
            .log(false),
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
        }

        socket.on("ID") { data, _ in
        }

        socket.on("order_update") { data, _ in

            // Parse: { extracted: { light: { action: "..." } } }
            if let dict = (data.first as? [String: Any]),
               let extracted = dict["extracted"] as? [String: Any],
               let light = extracted["light"] as? [String: Any],
               let action = light["action"] as? String {
                self.onOrderUpdate?(action)
            } else {
            }
        }

        socket.on("server_hello") { data, _ in
        }

        socket.on(clientEvent: .error) { data, _ in
        }

        socket.on(clientEvent: .disconnect) { data, _ in
        }
    }

    func connect() { socket.connect() }
    func disconnect() { socket.disconnect() }
}
