//
//  LanWebSocketEndpoint.swift
//  Limi
//
//  Resolved LAN WebSocket service from _limi-ws._tcp mDNS advertisement.
//

import Foundation

public struct LanWebSocketEndpoint: Identifiable, Equatable {
    /// TXT `deviceId`, uppercased — matches DeviceTransportState.deviceId.
    public let deviceId: String
    /// Resolved IPv4/IPv6 host.
    public let host: String
    /// Advertised TCP port (typically 8765).
    public let port: Int
    public let serviceName: String
    public let lastSeen: Date

    public var id: String { "\(deviceId)|\(host)|\(port)" }

    public init(
        deviceId: String,
        host: String,
        port: Int,
        serviceName: String,
        lastSeen: Date = Date()
    ) {
        self.deviceId = deviceId.uppercased()
        self.host = host
        self.port = port
        self.serviceName = serviceName
        self.lastSeen = lastSeen
    }
}
