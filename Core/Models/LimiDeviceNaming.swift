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

    /// Factory-default BLE names (e.g. after reset) — not the post-provision `LIMI Device` Wi‑Fi label.
    static func isBLEProvisioningHubName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("limi1ch-") { return true }
        switch normalized {
        case "1 ch-hub", "4 ch-hub", "8 ch-hub", "16 ch-hub", "mini controller":
            return true
        default:
            return false
        }
    }

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
        case "on", "online", "connected", "true", "1", "boot":
            return true
        default:
            return false
        }
    }

    /// True when `status` is a real presence value (not an ack-only / empty payload).
    static func isDefinitePresenceStatus(_ status: String) -> Bool {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on", "online", "connected", "true", "1", "boot",
             "off", "offline", "disconnected", "false", "0":
            return true
        default:
            return false
        }
    }

    /// When two Bonjour rows are the same board, keep the fresher / better-labeled one.
    static func preferredWiFiDuplicate(_ a: BLEDevice, _ b: BLEDevice) -> BLEDevice {
        let aSeen = a.lastSeen ?? .distantPast
        let bSeen = b.lastSeen ?? .distantPast
        if aSeen != bSeen { return bSeen > aSeen ? b : a }

        let aHasId = !(a.txtRecord?["deviceId"] ?? "").isEmpty
        let bHasId = !(b.txtRecord?["deviceId"] ?? "").isEmpty
        if aHasId != bHasId { return bHasId ? b : a }

        let aName = a.name.lowercased()
        let bName = b.name.lowercased()
        if aName != bName {
            if bName.hasPrefix(aName) { return b }
            if aName.hasPrefix(bName) { return a }
            if b.name.count != a.name.count { return b.name.count > a.name.count ? b : a }
        }
        return b
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

    /// Accepts `AA:BB:CC:DD:EE:FF`, `limi1ch-…`, or plain 12-hex from API payloads.
    static func normalizedHardwareIdFromMAC(_ mac: String) -> String {
        normalizedHardwareId(mac.replacingOccurrences(of: ":", with: ""))
    }

    /// `80B54ECCA7F4` → `80:B5:4E:CC:A7:F4` for virtual-device API payloads.
    static func colonSeparatedMAC(from hardwareId: String) -> String {
        let hex = normalizedHardwareId(hardwareId)
        guard hex.count == 12 else { return hardwareId }
        return stride(from: 0, to: 12, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return String(hex[start..<end])
        }.joined(separator: ":")
    }

    /// True when `id` is a CoreBluetooth peripheral UUID (not a 12-hex hardware MAC).
    static func isValidPeripheralUUID(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: trimmed) != nil else { return false }
        let hex = normalizedHardwareId(trimmed)
        // Reject values that are only a hardware MAC pasted into the UUID field.
        if hex.count == 12, hex.allSatisfy(\.isHexDigit), !trimmed.contains("-") {
            return false
        }
        return true
    }
}
