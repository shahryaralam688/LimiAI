//
//  VirtualDeviceSequenceStore.swift
//  Limi
//
//  Per-account, per-virtual-device order + on/off for member hubs.
//  Pattern `devices` uses enabled IDs in this saved order.
//

import Combine
import Foundation

public struct VirtualDeviceSequenceItem: Codable, Equatable, Identifiable {
    public var hardwareId: String
    public var isEnabled: Bool

    public var id: String { hardwareId }

    public init(hardwareId: String, isEnabled: Bool = true) {
        self.hardwareId = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        self.isEnabled = isEnabled
    }
}

/// Phone-local sequence diary. Wiped on account switch.
public final class VirtualDeviceSequenceStore: ObservableObject {
    public static let shared = VirtualDeviceSequenceStore()

    private let defaultsKey = "limi.virtualDevice.sequenceByOwner"
    private let lock = NSLock()
    private var cache: [String: [String: [VirtualDeviceSequenceItem]]]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(
            [String: [String: [VirtualDeviceSequenceItem]]].self,
            from: data
           ) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    /// `vd-537ff690` from Home row ids like `virtual-master:vd-537ff690`.
    public static func canonicalVirtualDeviceId(_ raw: String) -> String {
        var id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "virtual-master:"
        if id.lowercased().hasPrefix(prefix) {
            id = String(id.dropFirst(prefix.count))
        }
        return id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Saved order merged with current members. New members append (on). Removed members drop.
    public func orderedItems(
        virtualDeviceId: String,
        members: [String]
    ) -> [VirtualDeviceSequenceItem] {
        let current = uniqueHardwareIds(members)
        guard !current.isEmpty else { return [] }

        let saved = savedItems(virtualDeviceId: virtualDeviceId, memberIds: current)
        var used = Set<String>()
        var merged: [VirtualDeviceSequenceItem] = []

        for item in saved {
            guard current.contains(item.hardwareId), used.insert(item.hardwareId).inserted else {
                continue
            }
            merged.append(item)
        }
        for hw in current where used.insert(hw).inserted {
            merged.append(VirtualDeviceSequenceItem(hardwareId: hw, isEnabled: true))
        }
        return merged
    }

    /// Pattern `devices`: user-saved enabled order. Cloud/member list only if nothing is saved.
    public func enabledOrderedHardwareIds(
        virtualDeviceId: String,
        members: [String]
    ) -> [String] {
        patternDeviceIds(virtualDeviceId: virtualDeviceId, members: members)
    }

    /// Exact `devices` array for `pattern_control`.
    public func patternDeviceIds(
        virtualDeviceId: String,
        members: [String]
    ) -> [String] {
        let current = uniqueHardwareIds(members)
        let saved = savedItems(virtualDeviceId: virtualDeviceId, memberIds: current)
        guard !saved.isEmpty else { return current }

        var used = Set<String>()
        var devices: [String] = []
        for item in saved {
            guard current.contains(item.hardwareId), used.insert(item.hardwareId).inserted else {
                continue
            }
            if item.isEnabled {
                devices.append(item.hardwareId)
            }
        }
        for hw in current where used.insert(hw).inserted {
            devices.append(hw)
        }
        return devices
    }

    public func replaceItems(
        virtualDeviceId: String,
        items: [VirtualDeviceSequenceItem]
    ) {
        let vd = Self.canonicalVirtualDeviceId(virtualDeviceId)
        guard !vd.isEmpty else { return }
        let owner = AuthManager.shared.sessionCacheKey()
        guard !owner.isEmpty else { return }

        var seen = Set<String>()
        let cleaned = items.compactMap { item -> VirtualDeviceSequenceItem? in
            let hw = LimiDeviceNaming.normalizedHardwareId(item.hardwareId)
            guard hw.count == 12, hw.allSatisfy(\.isHexDigit), seen.insert(hw).inserted else {
                return nil
            }
            return VirtualDeviceSequenceItem(hardwareId: hw, isEnabled: item.isEnabled)
        }

        lock.lock()
        var ownerMap = cache[owner] ?? [:]
        ownerMap = ownerMap.filter { Self.canonicalVirtualDeviceId($0.key) != vd }
        ownerMap[vd] = cleaned
        cache[owner] = ownerMap
        let snapshot = cache
        lock.unlock()
        persist(snapshot)
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    public func removeAll() {
        lock.lock()
        cache = [:]
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func savedItems(
        virtualDeviceId: String,
        memberIds: [String]
    ) -> [VirtualDeviceSequenceItem] {
        let owner = AuthManager.shared.sessionCacheKey()
        let vd = Self.canonicalVirtualDeviceId(virtualDeviceId)
        lock.lock()
        defer { lock.unlock() }
        let ownerMap = cache[owner] ?? [:]

        if let exact = ownerMap[vd], !exact.isEmpty {
            return exact
        }
        for (key, items) in ownerMap where Self.canonicalVirtualDeviceId(key) == vd {
            if !items.isEmpty { return items }
        }

        let current = Set(memberIds)
        guard !current.isEmpty else { return [] }

        var best: (items: [VirtualDeviceSequenceItem], overlap: Int)?
        for items in ownerMap.values {
            let ids = Set(items.map(\.hardwareId))
            let overlap = ids.intersection(current).count
            guard overlap > 0, ids.isSubset(of: current) || current.isSubset(of: ids) else {
                continue
            }
            if best == nil || overlap > best!.overlap {
                best = (items, overlap)
            }
        }
        return best?.items ?? []
    }

    private func persist(_ snapshot: [String: [String: [VirtualDeviceSequenceItem]]]) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func uniqueHardwareIds(_ members: [String]) -> [String] {
        var seen = Set<String>()
        return members.compactMap { raw in
            let hw = LimiDeviceNaming.normalizedHardwareId(raw)
            guard hw.count == 12, hw.allSatisfy(\.isHexDigit), seen.insert(hw).inserted else {
                return nil
            }
            return hw
        }
    }
}
