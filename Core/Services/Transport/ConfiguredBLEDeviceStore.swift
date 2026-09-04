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
        guard let uuid = record(for: hardwareId)?.blePeripheralUUID,
              Self.isUsablePeripheralUUID(uuid, forHardwareId: hardwareId) else {
            return nil
        }
        return uuid
    }

    /// Reject MAC-as-UUID corruption (`80B54EC1C270 ↔ 80B54EC1C270`).
    static func isUsablePeripheralUUID(_ uuid: String, forHardwareId hardwareId: String = "") -> Bool {
        guard LimiDeviceNaming.isValidPeripheralUUID(uuid) else { return false }
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        if !hw.isEmpty, uuid.uppercased() == hw { return false }
        return true
    }

    public func hasConfiguredBLE(for hardwareId: String) -> Bool {
        blePeripheralUUID(for: hardwareId) != nil
    }

    public var allRecords: [ConfiguredBLEDevice] {
        lock.lock()
        defer { lock.unlock() }
        return Array(records.values)
    }

    /// Call on successful BLE provisioning with hardware id + the BLE UUID used to configure.
    /// One CBPeripheral UUID maps to at most one hardware id (clears stale twin mappings).
    public func remember(
        hardwareId: String,
        blePeripheralUUID: String,
        displayName: String
    ) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty, !blePeripheralUUID.isEmpty else { return }
        guard Self.isUsablePeripheralUUID(blePeripheralUUID, forHardwareId: key) else {
            DeviceConsole.log(
                .config,
                "reject save hardwareId=\(key) — invalid bleUUID=\(blePeripheralUUID) (need CBPeripheral UUID)"
            )
            return
        }
        let entry = ConfiguredBLEDevice(
            hardwareId: key,
            blePeripheralUUID: blePeripheralUUID,
            displayName: displayName
        )
        lock.lock()
        let conflictingKeys = records.compactMap { hw, record -> String? in
            guard hw != key else { return nil }
            guard record.blePeripheralUUID.caseInsensitiveCompare(blePeripheralUUID) == .orderedSame else {
                return nil
            }
            return hw
        }
        for otherKey in conflictingKeys {
            records.removeValue(forKey: otherKey)
        }
        records[key] = entry
        lock.unlock()
        for otherKey in conflictingKeys {
            DeviceConsole.log(
                .config,
                "cleared stale map hardwareId=\(otherKey) (BLE UUID reused by \(key))"
            )
        }
        persist()
        DeviceConsole.log(
            .config,
            "saved hardwareId=\(key) bleUUID=\(blePeripheralUUID) name=\(displayName)"
        )
    }

    public func remove(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        lock.lock()
        records.removeValue(forKey: key)
        lock.unlock()
        persist()
        DeviceConsole.log(.config, "removed hardwareId=\(key)")
    }

    /// Logout / account switch — this store is phone-global, not per-user.
    public func removeAll() {
        lock.lock()
        records.removeAll()
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        DeviceConsole.log(.config, "cleared configured BLE devices (session change)")
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
            DeviceConsole.log(.config, "loaded 0 configured BLE devices")
            return
        }
        var map: [String: ConfiguredBLEDevice] = [:]
        for item in decoded {
            let key = LimiDeviceNaming.normalizedHardwareId(item.hardwareId)
            guard !key.isEmpty else { continue }
            guard Self.isUsablePeripheralUUID(item.blePeripheralUUID, forHardwareId: key) else {
                DeviceConsole.log(
                    .config,
                    "purged corrupt map hardwareId=\(key) bleUUID=\(item.blePeripheralUUID)"
                )
                continue
            }
            map[key] = item
        }
        records = map
        DeviceConsole.log(.config, "loaded \(map.count) configured BLE device(s)")
        for item in map.values {
            DeviceConsole.log(
                .config,
                "  • \(item.hardwareId) ↔ \(item.blePeripheralUUID) (\(item.displayName))"
            )
        }
        if map.count != decoded.count {
            persist()
            DeviceConsole.log(.config, "persisted after purging \(decoded.count - map.count) corrupt BLE map(s)")
        }
    }
}
