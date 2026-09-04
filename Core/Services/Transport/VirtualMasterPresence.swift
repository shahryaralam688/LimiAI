//
//  VirtualMasterPresence.swift
//  Limi
//
//  Master controller status: all members MQTT → Internet;
//  any member BLE-without-MQTT → BLE; otherwise Online (ignore unreachable members).
//

import Foundation

enum VirtualMasterPresence {
    /// A cloud hub is treated as *live* only while a definite `device_status` arrived
    /// within this window. Used together with a positive BLE signal to hand a hub off
    /// from cloud → BLE when its Wi‑Fi drops without an explicit `off` ever arriving.
    static let cloudPresenceTTL: TimeInterval = 45

    /// Absolute ceiling: if there has been no definite cloud presence for this long AND
    /// no local (BLE) evidence, the hub is considered offline. Kept generous so a quiet
    /// but genuinely-online remote hub is never falsely marked offline.
    static let cloudPresenceHardTTL: TimeInterval = 300

    /// Live cloud = the registry flag AND a fresh heartbeat (no stale snapshot fallback).
    /// This is the authoritative "is it really on cloud right now" check used to decide
    /// whether to record a `.cloud` snapshot — prevents the snapshot self-refresh loop.
    static func isLiveCloudOnline(hardwareId: String) -> Bool {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        let state = DeviceTransportRegistry.shared.state(for: key)
        return state.mqttConnected && state.isCloudPresenceFresh(ttl: cloudPresenceTTL)
    }

    enum Transport: Equatable {
        case offline
        case internet
        case ble
        case online

        init(rawValue: String) {
            switch rawValue.lowercased() {
            case "internet": self = .internet
            case "ble": self = .ble
            case "online": self = .online
            default: self = .offline
            }
        }

        var rawValue: String {
            switch self {
            case .offline: return "offline"
            case .internet: return "internet"
            case .ble: return "ble"
            case .online: return "online"
            }
        }
    }

    struct Summary: Equatable {
        let isOnline: Bool
        let transport: Transport

        var statusLabel: String {
            switch transport {
            case .offline: return "Offline"
            case .internet: return "Online · Internet"
            case .ble: return "Online · BLE"
            case .online: return "Online"
            }
        }

        /// Short label for Add Device scan rows.
        var scanSubtitleSuffix: String {
            switch transport {
            case .offline: return "Offline"
            case .internet: return "Internet"
            case .ble: return "BLE"
            case .online: return "Online"
            }
        }
    }

    /// Backend `device_status` / MQTT — master cards use this (not local BLE/Bonjour).
    static func isMemberCloudOnline(hardwareId: String) -> Bool {
        effectiveCloudOnline(hardwareId: hardwareId)
    }

    static func isAnyMemberCloudOnline(memberHardwareIds: [String]) -> Bool {
        memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
            .contains { isMemberCloudOnline(hardwareId: $0) }
    }

    static func cloudOnlineMemberCount(memberHardwareIds: [String]) -> (online: Int, total: Int) {
        let ids = memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
        let online = ids.filter { isMemberCloudOnline(hardwareId: $0) }.count
        return (online, ids.count)
    }

    /// Master Home card subtitle from backend presence only.
    static func masterCardCloudStatusLabel(memberHardwareIds: [String]) -> String {
        let counts = cloudOnlineMemberCount(memberHardwareIds: memberHardwareIds)
        guard counts.total > 0 else { return "Offline" }
        if counts.online == 0 { return "Offline" }
        if counts.online == counts.total { return "Online · Cloud" }
        return "Online · \(counts.online)/\(counts.total) hubs"
    }

    /// True when at least one member hub is reachable (MQTT, BLE, or local Wi‑Fi).
    static func isAnyMemberOnline(
        memberHardwareIds: [String],
        isMQTTOnline: (String) -> Bool = defaultMQTTCheck,
        isBLEVisible: (String) -> Bool = { isBLEVisible(hardwareId: $0) },
        isWiFiLANOnline: (String) -> Bool = defaultWiFiLANCheck
    ) -> Bool {
        memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
            .contains {
                isMemberReachable(
                    hardwareId: $0,
                    isMQTTOnline: isMQTTOnline,
                    isBLEVisible: isBLEVisible,
                    isWiFiLANOnline: isWiFiLANOnline
                )
            }
    }

    /// One member hub — cloud MQTT, BLE, or Bonjour LAN.
    static func isMemberReachable(
        hardwareId: String,
        isMQTTOnline: (String) -> Bool = defaultMQTTCheck,
        isBLEVisible: (String) -> Bool = { isBLEVisible(hardwareId: $0) },
        isWiFiLANOnline: (String) -> Bool = defaultWiFiLANCheck
    ) -> Bool {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return false }
        return isMQTTOnline(hw) || isBLEVisible(hw) || isWiFiLANOnline(hw)
    }

    static func onlineMemberCount(
        memberHardwareIds: [String],
        isMQTTOnline: (String) -> Bool = defaultMQTTCheck,
        isBLEVisible: (String) -> Bool = { isBLEVisible(hardwareId: $0) },
        isWiFiLANOnline: (String) -> Bool = defaultWiFiLANCheck
    ) -> (online: Int, total: Int) {
        let ids = memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
        let online = ids.filter {
            isMemberReachable(
                hardwareId: $0,
                isMQTTOnline: isMQTTOnline,
                isBLEVisible: isBLEVisible,
                isWiFiLANOnline: isWiFiLANOnline
            )
        }.count
        return (online, ids.count)
    }

    /// Home card rule: all members offline → offline; any member online → online.
    static func masterCardStatusLabel(
        memberHardwareIds: [String],
        isMQTTOnline: (String) -> Bool = defaultMQTTCheck,
        isBLEVisible: (String) -> Bool = { isBLEVisible(hardwareId: $0) },
        isWiFiLANOnline: (String) -> Bool = defaultWiFiLANCheck
    ) -> String {
        let counts = onlineMemberCount(
            memberHardwareIds: memberHardwareIds,
            isMQTTOnline: isMQTTOnline,
            isBLEVisible: isBLEVisible,
            isWiFiLANOnline: isWiFiLANOnline
        )
        guard counts.total > 0 else { return "Offline" }
        if counts.online == 0 { return "Offline" }
        if counts.online == counts.total {
            return evaluate(
                memberHardwareIds: memberHardwareIds,
                isMQTTOnline: isMQTTOnline,
                isBLEVisible: isBLEVisible,
                isWiFiLANOnline: isWiFiLANOnline
            ).statusLabel
        }
        return "Online · \(counts.online)/\(counts.total) hubs"
    }

    /// Evaluates master transport. Card is offline only when **every** member is unreachable.
    static func evaluate(
        memberHardwareIds: [String],
        isMQTTOnline: (String) -> Bool = defaultMQTTCheck,
        isBLEVisible: (String) -> Bool = { isBLEVisible(hardwareId: $0) },
        isWiFiLANOnline: (String) -> Bool = defaultWiFiLANCheck
    ) -> Summary {
        let ids = memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else {
            return Summary(isOnline: false, transport: .offline)
        }

        guard isAnyMemberOnline(
            memberHardwareIds: ids,
            isMQTTOnline: isMQTTOnline,
            isBLEVisible: isBLEVisible,
            isWiFiLANOnline: isWiFiLANOnline
        ) else {
            return Summary(isOnline: false, transport: .offline)
        }

        // Pick the best transport label among reachable members.
        if ids.allSatisfy(isMQTTOnline) {
            return Summary(isOnline: true, transport: .internet)
        }

        if ids.allSatisfy(isWiFiLANOnline) {
            return Summary(isOnline: true, transport: .online)
        }

        let anyBLEWithoutMQTT = ids.contains { hardwareId in
            !isMQTTOnline(hardwareId) && isBLEVisible(hardwareId)
        }
        if anyBLEWithoutMQTT {
            return Summary(isOnline: true, transport: .ble)
        }

        return Summary(isOnline: true, transport: .online)
    }

    /// BLE visibility for a member MAC **only when not MQTT-online**.
    static func isBLEVisible(
        hardwareId: String,
        scannedBLEDevices: [BLEDevice] = []
    ) -> Bool {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return false }

        // MQTT wins — configured BLE peripherals may still advertise while cloud-connected.
        if defaultMQTTCheck(hardwareId: hw) {
            return false
        }

        if scannedBLEDevices.contains(where: {
            $0.deviceType == .bluetooth && $0.resolvedHardwareId() == hw
        }) {
            return true
        }

        for entry in BluetoothManager.shared.discoveredDevices {
            if LimiDeviceNaming.normalizedHardwareId(entry.name) == hw {
                return true
            }
        }

        guard let uuid = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: hw) else {
            return false
        }
        if BluetoothManager.shared.isLiveConnected(forPeripheralUUID: uuid) {
            return true
        }
        return BluetoothManager.shared.hasRecentAdvertisement(forPeripheralUUID: uuid, within: 15)
    }

    static func defaultMQTTCheck(hardwareId: String) -> Bool {
        effectiveCloudOnline(hardwareId: hardwareId)
    }

    /// Live MQTT registry flag, or a recent cloud snapshot while Socket.IO is connected.
    static func effectiveCloudOnline(hardwareId: String) -> Bool {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return false }

        let state = DeviceTransportRegistry.shared.state(for: key)
        if state.mqttConnected {
            // Trust the live cloud flag only while presence is fresh. A long heartbeat
            // silence means the hub dropped off Wi‑Fi even though no `off` event arrived.
            return state.isCloudPresenceFresh(ttl: cloudPresenceTTL)
        }

        guard LightControllingSocket.shared.isConnected else { return false }

        if CloudPresenceMemory.shared.lastConnected(deviceId: key) == false {
            return false
        }

        if let snap = PresenceSnapshotStore.shared.snapshot(for: key),
           snap.age <= PresenceSnapshotStore.staleOnlineTTL {
            switch snap.path {
            case .cloud:
                return snap.isOnline
            case .offline:
                return false
            default:
                break
            }
        }

        return false
    }

    /// True when the hub is visible on the local network via Bonjour/mDNS.
    static func defaultWiFiLANCheck(hardwareId: String) -> Bool {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return false }
        return BonjourServiceBrowser.shared.discoveredWiFiDevices.contains { device in
            device.deviceType == .wifi
                && device.reachability == .online
                && device.resolvedHardwareId() == hw
        }
    }

    /// Bonjour row for this MAC with a resolved LAN IP (ping may still be offline).
    static func isMemberAdvertisedOnLAN(hardwareId: String) -> Bool {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return false }
        return BonjourServiceBrowser.shared.discoveredWiFiDevices.contains { device in
            guard device.deviceType == .wifi else { return false }
            guard device.resolvedHardwareId() == hw else { return false }
            let ip = device.ipAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !ip.isEmpty
        }
    }
}
