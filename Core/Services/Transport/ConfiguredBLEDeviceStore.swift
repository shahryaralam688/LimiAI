//
//  ConfiguredBLEDeviceStore.swift
//  Limi
//
//  After BLE Wi‑Fi provisioning succeeds, persist hardware deviceId → CBPeripheral
//  UUID so Cloud-miss can scan/reconnect the same board without another setup.
//

import Foundation

/// One configured hub: cloud/hardware id + the BLE peripheral used during setup.
public struct ConfiguredBLEDevice: Codable, Equatable, Identifiable {
    public var id: String { hardwareId }
    /// Normalized hardware id (MAC / deviceId from presence / Bonjour).
    public let hardwareId: String
    /// `CBPeripheral.identifier` string used for CoreBluetooth reconnect.
    public let blePeripheralUUID: String
    public let displayName: String
    public let configuredAt: Date

    public init(
        hardwareId: String,
        blePeripheralUUID: String,
        displayName: String,
        configuredAt: Date = Date()
    ) {
        self.hardwareId = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        self.blePeripheralUUID = blePeripheralUUID
        self.displayName = displayName
        self.configuredAt = configuredAt
    }
}

/// Persists configured BLE mappings across launches.
public final class ConfiguredBLEDeviceStore {
    public static let shared = ConfiguredBLEDeviceStore()

    private static let storageKey = "limi.configured.ble.devices"
    private let lock = NSLock()
    private var records: [String: ConfiguredBLEDevice] = [:]

    private init() {
        load()
    }

    public func record(for hardwareId: String) -> ConfiguredBLEDevice? {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return records[key]
    }

    public func blePeripheralUUID(for hardwareId: String) -> String? {
        record(for: hardwareId)?.blePeripheralUUID
    }

    public func hasConfiguredBLE(for hardwareId: String) -> Bool {
        record(for: hardwareId) != nil
    }

    public var allRecords: [ConfiguredBLEDevice] {
        lock.lock()
        defer { lock.unlock() }
        return Array(records.values)
    }

    /// Call on successful BLE provisioning with hardware id + the BLE UUID used to configure.
    public func remember(
        hardwareId: String,
        blePeripheralUUID: String,
        displayName: String
    ) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty, !blePeripheralUUID.isEmpty else { return }
        let entry = ConfiguredBLEDevice(
            hardwareId: key,
            blePeripheralUUID: blePeripheralUUID,
            displayName: displayName
        )
        lock.lock()
        records[key] = entry
        lock.unlock()
        persist()
        print("💾 [ConfiguredBLE] Stored \(key) → BLE \(blePeripheralUUID)")
    }

    public func remove(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        lock.lock()
        records.removeValue(forKey: key)
        lock.unlock()
        persist()
    }

    private func persist() {
        lock.lock()
        let snapshot = Array(records.values)
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ConfiguredBLEDevice].self, from: data)
        else {
            records = [:]
            return
        }
        var map: [String: ConfiguredBLEDevice] = [:]
        for item in decoded {
            let key = LimiDeviceNaming.normalizedHardwareId(item.hardwareId)
            guard !key.isEmpty else { continue }
            map[key] = item
        }
        records = map
    }
}
