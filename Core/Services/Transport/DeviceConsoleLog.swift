//
//  DeviceConsoleLog.swift
//  Limi
//
//  Device-only console logging. Filter Xcode console with: [Device]
//  Multi-device Wi-Fi setup debug: watch Provision / Config / Home / Bonjour.
//

import Foundation

/// Narrow device-lifecycle logs (discovery after configure + Socket.IO messages).
enum DeviceConsole {
    static var isEnabled = true

    /// Presence-lifecycle debug channel switch. When `true`, ALL normal `[Device]…` logs are
    /// muted and only `focus(...)` `[LIFECYCLE]` lines print — handy while debugging presence.
    /// Kept `false` in production so neither the (per-5s heartbeat) lifecycle logs nor a wall
    /// of `[Device]` logs spam the console. Flip to `true` locally to trace the presence flow.
    static var focusMode = false

    /// Task-focused presence channel. Only prints while `focusMode` is on, so the frequent
    /// heartbeat / handoff traces stay out of the production console.
    static func focus(_ message: String) {
        guard focusMode else { return }
        print("🔵 [LIFECYCLE] \(message)")
    }

    enum Area: String {
        case socket = "Socket"
        case presence = "Presence"
        case bonjour = "Bonjour"
        case ble = "BLE"
        case config = "Config"
        case home = "Home"
        case provision = "Provision"
        case add = "AddFlow"
        case lan = "LAN"
    }

    private static var lastBLEDiscoverLog: [String: Date] = [:]
    private static let bleDiscoverThrottle: TimeInterval = 8

    static func log(_ area: Area, _ message: String) {
        guard isEnabled, !focusMode else { return }
        print("[Device][\(area.rawValue)] \(message)")
    }

    /// Visual separator so multi-device runs are easy to spot in Xcode.
    static func banner(_ title: String) {
        guard isEnabled, !focusMode else { return }
        print("[Device]========== \(title) ==========")
    }

    /// Log configured-peripheral advertisements without flooding the console.
    static func bleAdvertisement(name: String, uuid: String, rssi: NSNumber, isConfiguredTarget: Bool) {
        guard isEnabled, !focusMode, isConfiguredTarget else { return }
        let key = uuid.uppercased()
        let now = Date()
        if let last = lastBLEDiscoverLog[key], now.timeIntervalSince(last) < bleDiscoverThrottle {
            return
        }
        lastBLEDiscoverLog[key] = now
        log(.ble, "advertise name=\(name) uuid=\(uuid) rssi=\(rssi) (configured)")
    }

    // MARK: - Debug dumps (2nd-device Wi-Fi setup)

    static func dumpConfiguredStore(reason: String) {
        guard isEnabled, !focusMode else { return }
        let records = ConfiguredBLEDeviceStore.shared.allRecords
        log(.config, "STORE DUMP (\(reason)) count=\(records.count)")
        if records.isEmpty {
            log(.config, "  (empty — no devices configured on this phone yet)")
            return
        }
        for (index, item) in records.sorted(by: { $0.hardwareId < $1.hardwareId }).enumerated() {
            log(
                .config,
                "  [\(index + 1)] hardwareId=\(item.hardwareId) bleUUID=\(item.blePeripheralUUID) name=\(item.displayName)"
            )
        }
    }

    static func dumpBonjourOnline(reason: String) {
        guard isEnabled, !focusMode else { return }
        let devices = BonjourServiceBrowser.shared.discoveredWiFiDevices
        let online = devices.filter { $0.deviceType == .wifi && $0.reachability == .online }
        log(.bonjour, "ONLINE DUMP (\(reason)) online=\(online.count) total=\(devices.count)")
        for (index, d) in online.enumerated() {
            let id = d.txtRecord?["deviceId"] ?? "-"
            log(
                .bonjour,
                "  [\(index + 1)] name=\(d.name) uuid=\(d.uuid) deviceId=\(id) ip=\(d.ipAddress ?? "-")"
            )
        }
        if online.isEmpty {
            log(.bonjour, "  (no online Bonjour devices)")
        }
    }

    static func dumpHomeList(
        reason: String,
        devices: [(name: String, hardwareId: String, online: Bool, configured: Bool)]
    ) {
        guard isEnabled, !focusMode else { return }
        log(.home, "LIST DUMP (\(reason)) count=\(devices.count)")
        for (index, d) in devices.enumerated() {
            log(
                .home,
                "  [\(index + 1)] name=\(d.name) id=\(d.hardwareId) online=\(d.online) configured=\(d.configured)"
            )
        }
        if devices.isEmpty {
            log(.home, "  (home list empty)")
        }
    }
}
