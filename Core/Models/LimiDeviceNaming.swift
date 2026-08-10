//
//  LimiDeviceNaming.swift
//  Limi
//
//  Shared rules for identifying Limi hardware across BLE, Bonjour, and MQTT.
//

import Foundation

enum LimiDeviceNaming {
    static let knownHubNames: Set<String> = [
        "1 CH-HUB", "4 CH-HUB", "8 CH-HUB", "16 CH-HUB",
        "Mini Controller", "LIMI Device"
    ]

    /// Returns true when the advertised name belongs to a supported Limi hub.
    static func isAllowedDeviceName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAllowed = Set(knownHubNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        return normalizedAllowed.contains(normalized)
            || normalized.hasPrefix("limi1ch-")
            || normalized.hasPrefix("limi device")
    }

    /// MQTT / Socket.IO presence values that mean the device is reachable.
    static func isOnlinePresenceStatus(_ status: String) -> Bool {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on", "online", "connected", "true", "1":
            return true
        default:
            return false
        }
    }

    /// True when `status` is a real presence value (not an ack-only / empty payload).
    static func isDefinitePresenceStatus(_ status: String) -> Bool {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on", "online", "connected", "true", "1",
             "off", "offline", "disconnected", "false", "0":
            return true
        default:
            return false
        }
    }

    /// Stable hardware id across Bonjour (`deviceId`), cloud presence (`LIMI1CH-…`), and UI MAC.
    /// Prefers the trailing 12-hex MAC when present so Case 3 cloud + local share one transport state.
    static func normalizedHardwareId(_ deviceId: String) -> String {
        let upper = deviceId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let dash = upper.lastIndex(of: "-") {
            let suffix = String(upper[upper.index(after: dash)...])
            if suffix.count == 12, suffix.allSatisfy(\.isHexDigit) {
                return suffix
            }
        }
        let hex = upper.filter(\.isHexDigit)
        if hex.count >= 12 {
            return String(hex.suffix(12))
        }
        return upper
    }
}
