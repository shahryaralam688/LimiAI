//
//  VirtualDeviceScanGrouping.swift
//  Limi
//
//  Collapses virtual-group member rows (Add Device scan, etc.) into one Master card.
//

import Foundation

enum VirtualDeviceScanGrouping {
    static let masterDisplayName = "Master Device"
    static let masterRowIDPrefix = "virtual-master:"

    static func masterRowID(virtualDeviceID: String) -> String {
        masterRowIDPrefix + virtualDeviceID
    }

    static func isMasterRowID(_ id: String) -> Bool {
        id.hasPrefix(masterRowIDPrefix)
    }

    /// Hides member MAC rows and inserts one master scan row per virtual group.
    static func apply(
        devices: [BLEDevice],
        groups: [VirtualDeviceGroupingSpec],
        masterName: String = masterDisplayName
    ) -> [BLEDevice] {
        guard !groups.isEmpty else { return devices }

        var allMemberIDs = Set<String>()
        for group in groups {
            for id in group.memberHardwareIds {
                allMemberIDs.insert(LimiDeviceNaming.normalizedHardwareId(id))
            }
        }

        var memberRows: [String: BLEDevice] = [:]
        var standalone: [BLEDevice] = []

        for device in devices {
            guard !device.isVirtualMaster else { continue }
            let hw = device.resolvedHardwareId()
            if allMemberIDs.contains(hw) {
                if let existing = memberRows[hw] {
                    memberRows[hw] = preferredScanDuplicate(existing, device)
                } else {
                    memberRows[hw] = device
                }
            } else {
                standalone.append(device)
            }
        }

        var masters: [BLEDevice] = []
        for group in groups {
            let memberOrder = group.memberHardwareIds
                .map { LimiDeviceNaming.normalizedHardwareId($0) }
                .filter { !$0.isEmpty }
            guard !memberOrder.isEmpty else { continue }

            let sortedMembers: [BLEDevice] = memberOrder.compactMap { memberRows[$0] }
            let stableVirtualID = group.virtualDeviceID.isEmpty ? "local-master" : group.virtualDeviceID
            let memberHardwareIds = memberOrder
            let metadata = VirtualMasterScanMetadata(
                virtualDeviceID: stableVirtualID,
                memberHardwareIds: memberHardwareIds,
                memberDevices: sortedMembers
            )

            let bleCandidates = sortedMembers.filter { $0.deviceType == .bluetooth }
            let presence = VirtualMasterPresence.evaluate(
                memberHardwareIds: memberOrder,
                isMQTTOnline: VirtualMasterPresence.defaultMQTTCheck,
                isBLEVisible: { hw in
                    VirtualMasterPresence.isBLEVisible(hardwareId: hw, scannedBLEDevices: bleCandidates)
                },
                isWiFiLANOnline: { hw in
                    if let member = sortedMembers.first(where: { $0.resolvedHardwareId() == hw }) {
                        return member.deviceType == .wifi && member.reachability == .online
                    }
                    return VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw)
                }
            )
            let masterIP = sortedMembers.first(where: { ($0.ipAddress ?? "").isEmpty == false })?.ipAddress
            let label = group.displayName.isEmpty ? masterName : group.displayName

            let master = BLEDevice(
                name: label,
                uuid: masterRowID(virtualDeviceID: stableVirtualID),
                deviceType: .wifi,
                ipAddress: masterIP,
                txtRecord: [
                    "deviceId": stableVirtualID,
                    "virtualMaster": "1",
                    "memberCount": "\(memberOrder.count)",
                    "masterTransport": presence.transport.rawValue,
                ],
                reachability: presence.isOnline ? .online : .offline,
                lastSeen: Date(),
                virtualMaster: metadata
            )
            masters.append(master)
        }

        guard !masters.isEmpty else { return devices }

        return (standalone + masters).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Hides member MAC rows and inserts one master scan row when enabled members are visible.
    static func apply(
        devices: [BLEDevice],
        enabledMemberHardwareIds: [String],
        virtualDeviceID: String,
        masterName: String = masterDisplayName
    ) -> [BLEDevice] {
        guard !enabledMemberHardwareIds.isEmpty else { return devices }
        let spec = VirtualDeviceGroupingSpec(
            virtualDeviceID: virtualDeviceID,
            memberHardwareIds: enabledMemberHardwareIds,
            displayName: masterName
        )
        return apply(devices: devices, groups: [spec], masterName: masterName)
    }

    /// Prefer online Wi‑Fi over BLE, then fresher lastSeen.
    private static func preferredScanDuplicate(_ a: BLEDevice, _ b: BLEDevice) -> BLEDevice {
        let aReach = memberIsReachable(a)
        let bReach = memberIsReachable(b)
        if aReach != bReach { return bReach ? b : a }
        if a.deviceType != b.deviceType {
            if a.deviceType == .wifi { return a }
            if b.deviceType == .wifi { return b }
        }
        let aSeen = a.lastSeen ?? .distantPast
        let bSeen = b.lastSeen ?? .distantPast
        return bSeen > aSeen ? b : a
    }

    static func memberIsReachable(_ device: BLEDevice) -> Bool {
        switch device.deviceType {
        case .wifi:
            return device.reachability == .online
        case .bluetooth:
            return true
        }
    }
}
