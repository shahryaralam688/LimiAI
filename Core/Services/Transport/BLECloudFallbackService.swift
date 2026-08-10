//
//  BLECloudFallbackService.swift
//  Limi
//
//  Smooth Cloud → BLE fallback:
//    • After configure, hardwareId ↔ BLE UUID is in ConfiguredBLEDeviceStore.
//    • When MQTT/cloud status is missing, reconnect via stored UUID (foreground).
//    • Command path always ensureConnected (lazy, safe).
//    • Avoid background unrestricted scans — those get the app jetsam’d by iOS.
//

import Combine
import Foundation
import UIKit

@MainActor
public final class BLECloudFallbackService {
    public static let shared = BLECloudFallbackService()

    private static let connectTimeout: TimeInterval = 12
    private static let readyPollInterval: TimeInterval = 0.25
    /// Don't spam reconnect attempts for the same hub.
    private static let prepareCooldown: TimeInterval = 30

    private var inFlight: [String: Task<Void, Never>] = [:]
    private var lastPrepareAt: [String: Date] = [:]
    private var releasedHardwareIds: Set<String> = []

    private init() {}

    private var isAppActive: Bool {
        UIApplication.shared.applicationState == .active
    }

    /// Kick off reconnect when cloud presence drops — foreground only.
    public func prepareBLEIfCloudMissing(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        guard ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: key) else { return }
        guard !DeviceTransportRegistry.shared.state(for: key).mqttConnected else { return }
        guard isAppActive else {
            print("⏭️ [BLEFallback] Skip prepare — app not active (\(key))")
            return
        }
        releasedHardwareIds.remove(key)

        if let last = lastPrepareAt[key],
           Date().timeIntervalSince(last) < Self.prepareCooldown,
           inFlight[key] == nil {
            return
        }
        if inFlight[key] != nil { return }

        lastPrepareAt[key] = Date()
        let task = Task { @MainActor in
            defer { inFlight[key] = nil }
            do {
                try await ensureConnected(hardwareId: key)
                print("🔵 [BLEFallback] Ready for \(key)")
            } catch {
                BluetoothManager.shared.clearReconnectTargetAndStopOrphanScan()
                print("⚠️ [BLEFallback] Prepare failed for \(key): \(error.localizedDescription)")
            }
        }
        inFlight[key] = task
    }

    /// Cancel in-flight work when app backgrounds (prevents OS termination).
    public func cancelAllPreparing() {
        for (key, task) in inFlight {
            task.cancel()
            inFlight[key] = nil
        }
        BluetoothManager.shared.clearReconnectTargetAndStopOrphanScan()
    }

    /// When MQTT returns, drop BLE so cloud stays the active path.
    public func releaseIfCloudRestored(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        releasedHardwareIds.insert(key)
        inFlight[key]?.cancel()
        inFlight[key] = nil

        guard let record = ConfiguredBLEDeviceStore.shared.record(for: key) else { return }
        let ble = BluetoothManager.shared
        guard ble.isConnected,
              let connectedId = ble.connectedPeripheral?.identifier.uuidString,
              connectedId.caseInsensitiveCompare(record.blePeripheralUUID) == .orderedSame
        else { return }
        print("☁️ [BLEFallback] Cloud back — disconnecting BLE for \(key)")
        // Suppress auto-reconnect or BluetoothManager fights MQTT forever → jetsam.
        ble.disconnectCurrentDevice(suppressReconnect: true)
    }

    /// Ensure GATT (FF03) is ready for the configured hardware id before a BLE write.
    public func ensureConnected(hardwareId: String) async throws {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else {
            throw LimiTransportError.deviceUnreachable
        }

        guard let record = ConfiguredBLEDeviceStore.shared.record(for: key) else {
            if BluetoothManager.shared.isPeripheralReady {
                return
            }
            throw LimiTransportError.doorUnavailable(.ble)
        }

        let bleUUID = record.blePeripheralUUID
        let ble = BluetoothManager.shared

        if ble.isReady(forPeripheralUUID: bleUUID) {
            return
        }

        guard ble.isBluetoothOn else {
            throw LimiTransportError.doorUnavailable(.ble)
        }

        // Background: cache-only connect. Foreground: may discovery-scan briefly.
        ble.connectToDevice(deviceId: bleUUID, allowDiscoveryScan: isAppActive)

        let deadline = Date().addingTimeInterval(Self.connectTimeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if ble.isReady(forPeripheralUUID: bleUUID) {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(Self.readyPollInterval * 1_000_000_000))
        }

        ble.clearReconnectTargetAndStopOrphanScan()
        throw LimiTransportError.doorUnavailable(.ble)
    }
}

// MARK: - BluetoothManager readiness helpers

extension BluetoothManager {
    /// Connected and FF03 discovered for writes.
    var isPeripheralReady: Bool {
        isConnected && targetCharacteristic != nil && connectedPeripheral != nil
    }

    func isReady(forPeripheralUUID uuidString: String) -> Bool {
        guard isPeripheralReady,
              let connected = connectedPeripheral
        else { return false }
        return connected.identifier.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame
    }
}
