//
//  DevicePowerMemoryStore.swift
//  Limi
//
//  Last known on/off state per hardware id for Home power toggles.
//  Survives app restarts and presence refreshes so Online does not always flash Off.
//

import Foundation

public final class DevicePowerMemoryStore {
    public static let shared = DevicePowerMemoryStore()

    private let defaultsKey = "limi.device.lastPowerOnByHardwareId"
    private let lock = NSLock()
    private var states: [String: Bool]

    private init() {
        if let stored = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Bool] {
            states = stored.reduce(into: [:]) { result, pair in
                let key = LimiDeviceNaming.normalizedHardwareId(pair.key)
                guard !key.isEmpty else { return }
                result[key] = pair.value
            }
        } else {
            states = [:]
        }
    }

    public func isOn(for hardwareId: String) -> Bool? {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return states[key]
    }

    public func setOn(_ isOn: Bool, for hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        lock.lock()
        states[key] = isOn
        let snapshot = states
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }

    public func remove(for hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        lock.lock()
        states.removeValue(forKey: key)
        let snapshot = states
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: defaultsKey)
    }

    /// Test helper — clears session + disk.
    public func resetForTests() {
        lock.lock()
        states.removeAll()
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
