//
//  VirtualDeviceHomeGrouping.swift
//  LIMI AI Device
//
//  Hides individual hubs that belong to a virtual (master) device and
//  surfaces one multi-channel row on Home instead.
//

import Foundation

enum VirtualDeviceHomeGrouping {
    static let masterDisplayName = VirtualDeviceGroupingSpec.defaultMasterDisplayName
    static let masterRowIDPrefix = "virtual-master:"

    static func masterRowID(virtualDeviceID: String) -> String {
        masterRowIDPrefix + virtualDeviceID
    }

    static func isMasterRowID(_ id: String) -> Bool {
        id.hasPrefix(masterRowIDPrefix)
    }

    /// Removes member MAC rows and inserts one virtual-master row per group.
    static func apply(
        devices: [WifiDevice],
        groups: [VirtualDeviceGroupingSpec]
    ) -> [WifiDevice] {
        guard !groups.isEmpty else { return devices }

        var memberRows: [String: WifiDevice] = [:]
        var standalone: [WifiDevice] = []
        var allMemberIDs = Set<String>()

        for group in groups {
            for id in group.memberHardwareIds {
                allMemberIDs.insert(LimiDeviceNaming.normalizedHardwareId(id))
            }
        }

        for device in devices {
            let hw = LimiDeviceNaming.normalizedHardwareId(device.chennalMac)
            if allMemberIDs.contains(hw) {
                memberRows[hw] = device
            } else if !isMasterRowID(device.id) {
                standalone.append(device)
            }
        }

        var masters: [WifiDevice] = []
        for group in groups {
            let memberOrder = group.memberHardwareIds
                .map { LimiDeviceNaming.normalizedHardwareId($0) }
                .filter { !$0.isEmpty }
            guard !memberOrder.isEmpty else { continue }

            let sortedMembers: [WifiDevice] = memberOrder.compactMap { memberRows[$0] }
            let stableVirtualID = group.virtualDeviceID.isEmpty ? "local-master" : group.virtualDeviceID
            let channelTypes: [String]
            if sortedMembers.isEmpty {
                channelTypes = Array(repeating: "CCT", count: memberOrder.count)
            } else {
                channelTypes = sortedMembers.map { $0.channelTypes.first ?? "CCT" }
            }

            let presenceOnline = VirtualMasterPresence.isAnyMemberCloudOnline(
                memberHardwareIds: memberOrder
            )

            let master = WifiDevice(
                id: masterRowID(virtualDeviceID: stableVirtualID),
                uuid: stableVirtualID,
                chennalMac: stableVirtualID,
                chennalCount: memberOrder.count,
                channelTypes: channelTypes,
                deviceName: group.displayName,
                isOnline: presenceOnline,
                memberChannelMacs: memberOrder
            )
            masters.append(master)
        }

        guard !masters.isEmpty else { return devices }

        return (standalone + masters).sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
    }

    /// Removes member MAC rows and inserts one virtual-master row when enabled members exist.
    static func apply(
        devices: [WifiDevice],
        enabledMemberHardwareIds: [String],
        virtualDeviceID: String,
        masterName: String = masterDisplayName
    ) -> [WifiDevice] {
        guard !enabledMemberHardwareIds.isEmpty else { return devices }
        let spec = VirtualDeviceGroupingSpec(
            virtualDeviceID: virtualDeviceID,
            memberHardwareIds: enabledMemberHardwareIds,
            displayName: masterName
        )
        return apply(devices: devices, groups: [spec])
    }
}
