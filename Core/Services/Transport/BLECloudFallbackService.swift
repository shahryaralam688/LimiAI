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
    private var advertisementListenActive = false

    private init() {}

    /// Cold launch is `.inactive` for a beat — still allow BLE listen/scan.
    /// Only skip when the app is actually backgrounded (jetsam risk).
    private var canUseBLERadio: Bool {
        UIApplication.shared.applicationState != .background
    }

    /// Kick off reconnect when cloud presence drops — foreground / launch only.
    public func prepareBLEIfCloudMissing(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        guard !WiFiProvisioningActivityGate.isActive else {
            DeviceConsole.log(.ble, "skip prepare — provisioning active id=\(key)")
            return
        }
        guard !AddDeviceFlowActivityGate.isActive else {
            DeviceConsole.log(.ble, "skip prepare — add device flow active id=\(key)")
            return
        }
        guard ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: key) else { return }
        guard !DeviceTransportRegistry.shared.state(for: key).mqttConnected else { return }
        guard canUseBLERadio else {
            DeviceConsole.log(.ble, "skip prepare — background id=\(key)")
            return
        }
        releasedHardwareIds.remove(key)

        if let last = lastPrepareAt[key],
           Date().timeIntervalSince(last) < Self.prepareCooldown,
           inFlight[key] == nil {
            DeviceConsole.log(.ble, "skip prepare — cooldown id=\(key)")
            return
        }
        if inFlight[key] != nil { return }

        lastPrepareAt[key] = Date()
        DeviceConsole.log(.ble, "cloud miss → prepare BLE reconnect id=\(key)")
        let task = Task { @MainActor in
            defer { inFlight[key] = nil }
            do {
                try await ensureConnected(hardwareId: key)
                DeviceConsole.log(.ble, "prepare OK id=\(key)")
            } catch {
                DeviceConsole.log(.ble, "prepare FAIL id=\(key) \(error.localizedDescription)")
                BluetoothManager.shared.clearReconnectTargetAndStopOrphanScan()
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
        stopAdvertisementListen()
    }

    /// Collect BLE ads while Home waits for MQTT. Does not mark the device Online.
    public func startAdvertisementListenForConfiguredDevices() {
        guard canUseBLERadio else { return }
        guard !ConfiguredBLEDeviceStore.shared.allRecords.isEmpty else { return }
        guard !advertisementListenActive else { return }
        advertisementListenActive = true
        DeviceConsole.log(.ble, "listen for ads while MQTT is checked")
        BluetoothManager.shared.startScanning { _ in }
    }

    public func stopAdvertisementListen() {
        guard advertisementListenActive else { return }
        advertisementListenActive = false
        BluetoothManager.shared.stopScanning()
    }

    /// Per-hub BLE presence for Home. Does not connect or disconnect other hubs.
    public enum BLEPresenceKind {
        case liveConnected
        case advertising
        case unreachable
    }

    public func presenceKind(for hardwareId: String) -> BLEPresenceKind {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard let uuid = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: key) else {
            return .unreachable
        }
        let ble = BluetoothManager.shared
        if ble.isLiveConnected(forPeripheralUUID: uuid) || ble.isReady(forPeripheralUUID: uuid) {
            return .liveConnected
        }
        if ble.hasRecentAdvertisement(forPeripheralUUID: uuid, within: 15) {
            return .advertising
        }
        return .unreachable
    }

    /// When MQTT returns, drop BLE so cloud stays the active path.
    public func releaseIfCloudRestored(hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        releasedHardwareIds.insert(key)
        inFlight[key]?.cancel()
        inFlight[key] = nil

        guard let record = ConfiguredBLEDeviceStore.shared.record(for: key) else { return }
        guard BluetoothManager.shared.isLiveConnected(forPeripheralUUID: record.blePeripheralUUID) else { return }
        BluetoothManager.shared.disconnectPeripheral(uuidString: record.blePeripheralUUID, suppressReconnect: true)
        DeviceConsole.log(.ble, "cloud restored → release BLE id=\(key)")
    }

    /// Ensure GATT (FF03) is ready for the configured hardware id before a BLE write.
    /// - Parameter requireAdvertisement: When true (default), only connect if the board
    ///   is currently advertising — powered-off / silent boards stay unreachable.
    public func ensureConnected(hardwareId: String, requireAdvertisement: Bool = true) async throws {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else {
            throw LimiTransportError.deviceUnreachable
        }

        guard let record = ConfiguredBLEDeviceStore.shared.record(for: key) else {
            if BluetoothManager.shared.isPeripheralReady {
                return
            }
            DeviceConsole.log(.ble, "ensureConnected — not configured id=\(key)")
            throw LimiTransportError.doorUnavailable(.ble)
        }

        let bleUUID = record.blePeripheralUUID
        let ble = BluetoothManager.shared

        guard ble.isRadioPoweredOn || ble.isBluetoothOn else {
            DeviceConsole.log(.ble, "ensureConnected — BT off id=\(key)")
            throw LimiTransportError.doorUnavailable(.ble)
        }

        DeviceConsole.log(
            .ble,
            "ensureConnected id=\(key) bleUUID=\(bleUUID) requireAd=\(requireAdvertisement)"
        )

        // Connected hubs usually stop advertising. A live GATT link is proof the board is on.
        if ble.isLiveConnected(forPeripheralUUID: bleUUID) {
            if ble.isReady(forPeripheralUUID: bleUUID) {
                DeviceConsole.log(.ble, "already live connected id=\(key) — skip ad wait")
                return
            }
            DeviceConsole.log(.ble, "live connected, waiting GATT id=\(key)")
            let deadline = Date().addingTimeInterval(Self.connectTimeout)
            while Date() < deadline {
                try Task.checkCancellation()
                if ble.isReady(forPeripheralUUID: bleUUID) {
                    DeviceConsole.log(.ble, "GATT ready id=\(key)")
                    return
                }
                try await Task.sleep(nanoseconds: UInt64(Self.readyPollInterval * 1_000_000_000))
            }
        }

        if requireAdvertisement, !ble.isLiveConnected(forPeripheralUUID: bleUUID) {
            let advertised = await waitForAdvertisement(peripheralUUID: bleUUID, timeout: 8)
            guard advertised else {
                DeviceConsole.log(.ble, "no advertisement within timeout id=\(key)")
                ble.clearReconnectTargetAndStopOrphanScan()
                throw LimiTransportError.doorUnavailable(.ble)
            }
            DeviceConsole.log(.ble, "advertisement seen id=\(key)")
        }

        // Background: cache-only connect. Foreground: may discovery-scan briefly.
        DeviceConsole.log(.ble, "connect/scan id=\(key) allowScan=\(canUseBLERadio)")
        ble.connectToDevice(deviceId: bleUUID, allowDiscoveryScan: canUseBLERadio)

        let deadline = Date().addingTimeInterval(Self.connectTimeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if ble.isReady(forPeripheralUUID: bleUUID) {
                DeviceConsole.log(.ble, "GATT ready id=\(key)")
                return
            }
            try await Task.sleep(nanoseconds: UInt64(Self.readyPollInterval * 1_000_000_000))
        }

        DeviceConsole.log(.ble, "connect timeout id=\(key)")
        ble.clearReconnectTargetAndStopOrphanScan()
        throw LimiTransportError.doorUnavailable(.ble)
    }

    /// Scan until the configured peripheral advertises, or timeout.
    private func waitForAdvertisement(peripheralUUID: String, timeout: TimeInterval) async -> Bool {
        let ble = BluetoothManager.shared
        if ble.isLiveConnected(forPeripheralUUID: peripheralUUID) {
            return true
        }
        if ble.hasRecentAdvertisement(forPeripheralUUID: peripheralUUID, within: 12) {
            return true
        }
        if !ble.isRadioPoweredOn {
            let powered = await ble.waitUntilPoweredOn(timeout: 2)
            if !powered { return false }
            if ble.hasRecentAdvertisement(forPeripheralUUID: peripheralUUID, within: 12) {
                return true
            }
        }
        guard canUseBLERadio else { return false }

        DeviceConsole.log(.ble, "waiting for advertisement uuid=\(peripheralUUID) timeout=\(Int(timeout))s")
        ble.startScanning { _ in }
        defer { ble.stopScanning() }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { return false }
            if ble.hasRecentAdvertisement(forPeripheralUUID: peripheralUUID, within: 12) {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(Self.readyPollInterval * 1_000_000_000))
        }
        return ble.hasRecentAdvertisement(forPeripheralUUID: peripheralUUID, within: 12)
    }
}

// MARK: - BluetoothManager readiness helpers

extension BluetoothManager {
    /// Connected and FF03 discovered for writes.
    var isPeripheralReady: Bool {
        isConnected && targetCharacteristic != nil && connectedPeripheral != nil
    }

    func isReady(forPeripheralUUID uuidString: String) -> Bool {
        if let entry = connectedEntry(forPeripheralUUID: uuidString),
           entry.peripheral.state == .connected {
            return true
        }
        guard isPeripheralReady,
              let connected = connectedPeripheral
        else { return false }
        return connected.identifier.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame
    }
}
