//
//  PresenceSnapshotStore.swift
//  Limi
//
//  Last-known online/path per hardware id for stale-while-revalidate Home UI.
//  Live MQTT/BLE/Bonjour always wins when available; snapshot fills the gap
//  during silent background refresh (no blocking overlay).
//

import Foundation

public enum PresenceSnapshotPath: String, Codable {
    case cloud
    case ble
    case local
    case offline
}

public struct DevicePresenceSnapshot: Codable, Equatable {
    public let isOnline: Bool
    public let path: PresenceSnapshotPath
    public let updatedAt: Date

    public var age: TimeInterval {
        Date().timeIntervalSince(updatedAt)
    }
}

/// Persists short-lived presence snapshots for smooth Home UI.
public final class PresenceSnapshotStore {
    public static let shared = PresenceSnapshotStore()

    /// While revalidating, keep showing last online for at most this long.
    public static let staleOnlineTTL: TimeInterval = 120

    private let defaultsKey = "limi.transport.presenceSnapshots"
    private let lock = NSLock()
    private var cache: [String: DevicePresenceSnapshot]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: DevicePresenceSnapshot].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    public func snapshot(for hardwareId: String) -> DevicePresenceSnapshot? {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    public func record(
        deviceId: String,
        isOnline: Bool,
        path: PresenceSnapshotPath
    ) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        let entry = DevicePresenceSnapshot(
            isOnline: isOnline,
            path: path,
            updatedAt: Date()
        )
        lock.lock()
        cache[key] = entry
        let snapshot = cache
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    public func remove(deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lock.lock()
        cache.removeValue(forKey: key)
        let snapshot = cache
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    #if DEBUG
    func resetForTests() {
        lock.lock()
        cache = [:]
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
    #endif
}
