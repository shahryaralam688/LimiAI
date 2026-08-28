//
//  VirtualDeviceGroup.swift
//  LIMI AI Device
//
//  Local SwiftData cache of the signed-in user's virtual devices (replaced by GET).
//

import Foundation
import SwiftData

@Model
final class VirtualDeviceGroup {
    /// Single row key — one cache row per app install (contents are per signed-in user).
    @Attribute(.unique) var singletonKey: String
    var virtualDeviceID: String
    /// Normalized 12-hex hardware ids, comma-separated.
    var enabledHardwareIdsRaw: String
    var updatedAt: Date
    /// Last successful pull from GET /virtual-device.
    var lastRemoteSyncAt: Date?
    /// Fingerprint of the signed-in user so another account cannot reuse this cache.
    var ownerUserKey: String = ""
    /// JSON array of cloud groups from the last successful GET (source of truth).
    var remoteGroupsJSON: String = "[]"

    init(
        singletonKey: String = VirtualDeviceGroup.primaryKey,
        virtualDeviceID: String,
        enabledHardwareIds: [String] = [],
        lastRemoteSyncAt: Date? = nil,
        ownerUserKey: String = "",
        remoteGroupsJSON: String = "[]"
    ) {
        self.singletonKey = singletonKey
        self.virtualDeviceID = virtualDeviceID
        self.enabledHardwareIdsRaw = Self.joinHardwareIds(enabledHardwareIds)
        self.updatedAt = Date()
        self.lastRemoteSyncAt = lastRemoteSyncAt
        self.ownerUserKey = ownerUserKey
        self.remoteGroupsJSON = remoteGroupsJSON
    }

    static let primaryKey = "primary"

    var enabledHardwareIds: [String] {
        get { Self.splitHardwareIds(enabledHardwareIdsRaw) }
        set {
            enabledHardwareIdsRaw = Self.joinHardwareIds(newValue)
            updatedAt = Date()
        }
    }

    static func joinHardwareIds(_ ids: [String]) -> String {
        ids
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: ",")
    }

    static func splitHardwareIds(_ raw: String) -> [String] {
        raw
            .split(separator: ",")
            .map { LimiDeviceNaming.normalizedHardwareId(String($0)) }
            .filter { !$0.isEmpty }
    }
}
