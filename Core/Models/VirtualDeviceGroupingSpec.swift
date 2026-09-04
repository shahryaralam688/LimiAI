//
//  VirtualDeviceGroupingSpec.swift
//  Limi
//
//  One cloud or local virtual-device group (id + member MACs + label).
//

import Foundation

struct VirtualDeviceGroupingSpec: Equatable {
    /// Ali: show as Hub-{pendant/member count}, e.g. Hub-2, Hub-4.
    static let defaultMasterDisplayName = hubDisplayName(pendantCount: 1)

    let virtualDeviceID: String
    let memberHardwareIds: [String]
    let displayName: String

    /// User-facing label for a virtual master / multi-hub group.
    static func hubDisplayName(pendantCount: Int) -> String {
        "Hub-\(max(pendantCount, 1))"
    }

    static func fromRemote(
        _ remote: VirtualDeviceRemotePayload,
        useShortLabel: Bool,
        masterDisplayName: String? = nil
    ) -> VirtualDeviceGroupingSpec? {
        let id = remote.virtual_device_id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        let members = remote.mac_addresses
            .map { LimiDeviceNaming.normalizedHardwareIdFromMAC($0) }
            .filter { !$0.isEmpty }
        guard !members.isEmpty else { return nil }

        let baseName = masterDisplayName ?? hubDisplayName(pendantCount: members.count)
        let displayName: String
        if useShortLabel {
            let short = id.count > 10 ? String(id.suffix(8)) : id
            displayName = "\(baseName) · \(short)"
        } else {
            displayName = baseName
        }

        return VirtualDeviceGroupingSpec(
            virtualDeviceID: id,
            memberHardwareIds: members,
            displayName: displayName
        )
    }
}
