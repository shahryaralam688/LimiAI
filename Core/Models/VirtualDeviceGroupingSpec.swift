//
//  VirtualDeviceGroupingSpec.swift
//  Limi
//
//  One cloud or local virtual-device group (id + member MACs + label).
//

import Foundation

struct VirtualDeviceGroupingSpec: Equatable {
    static let defaultMasterDisplayName = "Master Device"

    let virtualDeviceID: String
    let memberHardwareIds: [String]
    let displayName: String

    static func fromRemote(
        _ remote: VirtualDeviceRemotePayload,
        useShortLabel: Bool,
        masterDisplayName: String = defaultMasterDisplayName
    ) -> VirtualDeviceGroupingSpec? {
        let id = remote.virtual_device_id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        let members = remote.mac_addresses
            .map { LimiDeviceNaming.normalizedHardwareIdFromMAC($0) }
            .filter { !$0.isEmpty }
        guard !members.isEmpty else { return nil }

        let displayName: String
        if useShortLabel {
            let short = id.count > 10 ? String(id.suffix(8)) : id
            displayName = "\(masterDisplayName) · \(short)"
        } else {
            displayName = masterDisplayName
        }

        return VirtualDeviceGroupingSpec(
            virtualDeviceID: id,
            memberHardwareIds: members,
            displayName: displayName
        )
    }
}
