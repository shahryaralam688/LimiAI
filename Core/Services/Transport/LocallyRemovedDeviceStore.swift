//
//  LocallyRemovedDeviceStore.swift
//  Limi
//
//  Per signed-in account: hardware ids hidden from Home on this phone.
//  Another account on the same phone keeps its own removed list.
//

import Foundation

public final class LocallyRemovedDeviceStore {
    public static let shared = LocallyRemovedDeviceStore()

    private let defaultsKey = "limi.transport.locallyRemovedDeviceIdsByUser"
    private let legacyDefaultsKey = "limi.transport.locallyRemovedDeviceIds"
    private let lock = NSLock()
    private var removedIdsByUser: [String: Set<String>] = [:]
    private var didMigrateLegacy = false

    private init() {
        loadFromDisk()
    }

    public func contains(_ deviceId: String) -> Bool {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return false }
        migrateLegacyIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        guard let owner = currentOwnerKey(), !owner.isEmpty else { return false }
        return removedIdsByUser[owner, default: []].contains(key)
    }

    public func markRemoved(_ deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        migrateLegacyIfNeeded()
        lock.lock()
        guard let owner = currentOwnerKey(), !owner.isEmpty else {
            lock.unlock()
            return
        }
        var set = removedIdsByUser[owner, default: []]
        set.insert(key)
        removedIdsByUser[owner] = set
        lock.unlock()
        persist()
        DeviceConsole.log(.config, "locally removed id=\(key) user=\(owner)")
    }

    /// Call when Bonjour rediscovers or Add Device succeeds so the board can return for this account.
    public func clearRemoved(_ deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        migrateLegacyIfNeeded()
        lock.lock()
        guard let owner = currentOwnerKey(), !owner.isEmpty else {
            lock.unlock()
            return
        }
        var set = removedIdsByUser[owner, default: []]
        set.remove(key)
        if set.isEmpty {
            removedIdsByUser.removeValue(forKey: owner)
        } else {
            removedIdsByUser[owner] = set
        }
        lock.unlock()
        persist()
    }

    /// Test helper — clears all users' tombstones.
    public func resetForTests() {
        lock.lock()
        removedIdsByUser.removeAll()
        didMigrateLegacy = true
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
    }

    // MARK: - Private

    private func currentOwnerKey() -> String? {
        let key = AuthManager.shared.sessionCacheKey()
        if !key.isEmpty { return key }
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return "__xctest__"
        }
        #endif
        return nil
    }

    private func loadFromDisk() {
        if let stored = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String]] {
            removedIdsByUser = stored.mapValues { values in
                Set(values.map { LimiDeviceNaming.normalizedHardwareId($0) }.filter { !$0.isEmpty })
            }
        }
    }

    private func persist() {
        lock.lock()
        let payload = removedIdsByUser.mapValues { Array($0).sorted() }
        lock.unlock()
        UserDefaults.standard.set(payload, forKey: defaultsKey)
    }

    private func migrateLegacyIfNeeded() {
        lock.lock()
        if didMigrateLegacy {
            lock.unlock()
            return
        }
        didMigrateLegacy = true
        lock.unlock()

        guard let legacy = UserDefaults.standard.array(forKey: legacyDefaultsKey) as? [String],
              !legacy.isEmpty else {
            return
        }

        guard let owner = currentOwnerKey(), !owner.isEmpty else { return }

        lock.lock()
        var set = removedIdsByUser[owner, default: []]
        for raw in legacy {
            let key = LimiDeviceNaming.normalizedHardwareId(raw)
            if !key.isEmpty { set.insert(key) }
        }
        removedIdsByUser[owner] = set
        lock.unlock()

        persist()
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        DeviceConsole.log(.config, "migrated legacy locally-removed ids to user=\(owner)")
    }
}
