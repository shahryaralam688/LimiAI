//
//  LocalNetworkAllowStore.swift
//  Limi
//
//  Bonjour / LAN WebSocket is allowed only after the user accepts the
//  local-network modal for a device (or forces WebSocket in preference).
//

import Foundation

/// Per-device permission to use Bonjour / WebSocket after MQTT + BLE miss.
public final class LocalNetworkAllowStore {
    public static let shared = LocalNetworkAllowStore()

    private let defaultsKey = "limi.transport.localNetworkAllowedDeviceIds"
    private let lock = NSLock()
    private var allowedIds: Set<String>

    private init() {
        if let stored = UserDefaults.standard.array(forKey: defaultsKey) as? [String] {
            allowedIds = Set(stored.map { LimiDeviceNaming.normalizedHardwareId($0) }.filter { !$0.isEmpty })
        } else {
            allowedIds = []
        }
    }

    public func isAllowed(for deviceId: String) -> Bool {
        if TransportMediumPreferenceStore.shared.preference == .webSocket {
            return true
        }
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return false }
        lock.lock()
        defer { lock.unlock() }
        return allowedIds.contains(key)
    }

    public func allow(_ deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lock.lock()
        allowedIds.insert(key)
        let snapshot = Array(allowedIds)
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }

    public func revoke(_ deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lock.lock()
        allowedIds.remove(key)
        let snapshot = Array(allowedIds)
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }

    public func removeAll() {
        lock.lock()
        allowedIds.removeAll()
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Test helper — clears session + disk allows.
    public func resetForTests() {
        removeAll()
    }
}
