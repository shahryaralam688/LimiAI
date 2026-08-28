//
//  CloudPresenceMemory.swift
//  Limi
//
//  Remembers device ids seen on cloud for Home list seeding (Case 3).
//  Does NOT mean live Online — that requires a fresh `device_status`.
//

import Foundation

/// Persists last-known MQTT presence per hardware id (list seed only).
public final class CloudPresenceMemory {
    public static let shared = CloudPresenceMemory()

    private let defaultsKey = "limi.transport.cloudPresenceByDevice"
    private let lock = NSLock()
    private var cache: [String: Bool]

    private init() {
        if let data = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Bool] {
            cache = data
        } else {
            cache = [:]
        }
    }

    /// Record a definite presence update.
    public func record(deviceId: String, connected: Bool) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lock.lock()
        cache[key] = connected
        let snapshot = cache
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }

    /// All device ids we have ever recorded presence for.
    public func knownDeviceIds() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cache.keys)
    }

    /// Last known online flag (nil if never recorded).
    public func lastConnected(deviceId: String) -> Bool? {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    /// Devices last recorded as cloud-online.
    public func lastOnlineDeviceIds() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return cache.compactMap { $0.value ? $0.key : nil }
    }

    /// Drop presence memory for a device (local delete from this phone).
    public func remove(deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lock.lock()
        cache.removeValue(forKey: key)
        let snapshot = cache
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }
}
