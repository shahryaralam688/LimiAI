//
//  BLEIdentityResolver.swift
//  Limi
//
//  Resolves the hardware MAC of unconfigured LIMI hubs seen over BLE by
//  connecting, reading the F001 (device-name) characteristic which the firmware
//  populates with the board MAC, then persisting a peripheralUUID ↔ MAC mapping
//  in ConfiguredBLEDeviceStore. Once stored, VirtualDeviceScanGrouping can fold
//  the hub into its virtual-device (master) card — on ANY phone, without prior
//  BLE provisioning on this device.
//
//  Design:
//   • Own CBCentralManager (isolated from the app's main BluetoothManager).
//   • Bounded concurrency pool so 60+ hubs resolve fast without radio thrash.
//   • Minimal GATT: discover only F000 → F001, read, disconnect.
//   • Skips hubs already mapped in ConfiguredBLEDeviceStore (no connect).
//   • Fail-fast timeouts with a small retry budget.
//

import CoreBluetooth
import Foundation

final class BLEIdentityResolver: NSObject, ObservableObject {

    /// True while scanning and/or probing hubs for their MAC.
    @Published private(set) var isBusy = false
    /// True once identification has finished (no work) and stayed idle briefly.
    /// While `false`, callers should NOT show unidentified hubs as individual
    /// devices — they may still turn out to be members of a virtual device.
    @Published private(set) var isSettled = true
    /// How many peripheral→MAC mappings this session has learned.
    @Published private(set) var resolvedCount = 0

    /// Fired (main thread) after a new mapping is persisted, so callers can regroup.
    var onResolved: (() -> Void)?

    // MARK: - BLE

    private var central: CBCentralManager?
    private let infoService = CBUUID(string: "F000")
    private let deviceNameChar = CBUUID(string: "F001")

    private let maxConcurrent = 3
    private let connectTimeout: TimeInterval = 10
    private let stepTimeout: TimeInterval = 6
    private let maxAttempts = 2
    /// Idle time after the last probe before we declare identification "settled".
    private let settleDelay: TimeInterval = 3

    private var isActive = false
    private var settleWork: DispatchWorkItem?

    // MARK: - Probe bookkeeping

    private final class ProbeContext {
        var connectStart = Date()
        var stepStart = Date()
        var probeStart = Date()
        var timeout: DispatchWorkItem?
    }

    private var peripherals: [UUID: CBPeripheral] = [:]
    private var contexts: [UUID: ProbeContext] = [:]
    private var pending: [UUID] = []
    private var inFlight: Set<UUID> = []
    private var resolved: Set<UUID> = []
    private var attempts: [UUID: Int] = [:]

    // MARK: - Lifecycle

    func start() {
        isActive = true
        // Entering an identification window — hide unmapped hubs until settled.
        settleWork?.cancel()
        settleWork = nil
        if isSettled { isSettled = false }
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        } else if central?.state == .poweredOn {
            beginScan()
        }
    }

    func stop() {
        isActive = false
        central?.stopScan()
        for uuid in inFlight {
            if let p = peripherals[uuid] { central?.cancelPeripheralConnection(p) }
        }
        for ctx in contexts.values { ctx.timeout?.cancel() }
        contexts.removeAll()
        inFlight.removeAll()
        pending.removeAll()
        settleWork?.cancel()
        settleWork = nil
        // Not actively identifying anymore — reveal remaining rows.
        isSettled = true
        recomputeBusy()
    }

    // MARK: - Scan

    private func beginScan() {
        guard isActive else { return }
        central?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func shouldProbe(name: String?, uuid: UUID) -> Bool {
        guard isActive else { return false }
        guard let name, LimiDeviceNaming.isBLEProvisioningHubName(name) else { return false }
        if resolved.contains(uuid) || inFlight.contains(uuid) || pending.contains(uuid) { return false }
        // Already mapped on this phone → no need to connect.
        let uuidStr = uuid.uuidString
        let alreadyMapped = ConfiguredBLEDeviceStore.shared.allRecords.contains {
            $0.blePeripheralUUID.caseInsensitiveCompare(uuidStr) == .orderedSame
        }
        if alreadyMapped {
            resolved.insert(uuid)
            return false
        }
        return true
    }

    // MARK: - Pool

    private func pump() {
        guard isActive else { return }
        while inFlight.count < maxConcurrent, !pending.isEmpty {
            let uuid = pending.removeFirst()
            guard let peripheral = peripherals[uuid] else { continue }
            startProbe(peripheral)
        }
        recomputeBusy()
    }

    private func startProbe(_ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        inFlight.insert(uuid)
        attempts[uuid, default: 0] += 1
        let ctx = ProbeContext()
        ctx.connectStart = Date()
        ctx.probeStart = Date()
        contexts[uuid] = ctx
        peripheral.delegate = self
        armTimeout(uuid, connectTimeout, reason: "connect")
        central?.connect(peripheral, options: nil)
        recomputeBusy()
    }

    private func finishProbe(_ uuid: UUID, success: Bool) {
        contexts[uuid]?.timeout?.cancel()
        contexts[uuid] = nil
        inFlight.remove(uuid)

        if success {
            resolved.insert(uuid)
        } else if (attempts[uuid] ?? 0) < maxAttempts {
            // Retry later (append to the back of the queue).
            if !pending.contains(uuid) { pending.append(uuid) }
        }
        pump()
    }

    /// Disconnect first; `didDisconnect` calls `finishProbe`. If not connected, finish now.
    private func teardown(_ peripheral: CBPeripheral, success: Bool) {
        let uuid = peripheral.identifier
        contexts[uuid]?.timeout?.cancel()
        if peripheral.state != .disconnected {
            // Stash outcome so didDisconnect can honor it.
            pendingOutcome[uuid] = success
            central?.cancelPeripheralConnection(peripheral)
        } else {
            finishProbe(uuid, success: success)
        }
    }

    private var pendingOutcome: [UUID: Bool] = [:]

    private func armTimeout(_ uuid: UUID, _ seconds: TimeInterval, reason: String) {
        contexts[uuid]?.timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let peripheral = self.peripherals[uuid], self.inFlight.contains(uuid) else { return }
            DeviceConsole.log(.ble, "[IdentityResolver] timeout(\(reason)) uuid=\(self.short(uuid))")
            self.teardown(peripheral, success: false)
        }
        contexts[uuid]?.timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func recomputeBusy() {
        let busy = !inFlight.isEmpty || !pending.isEmpty
        if busy != isBusy { isBusy = busy }
        if busy {
            settleWork?.cancel()
            settleWork = nil
            if isSettled { isSettled = false }
        } else if isActive {
            scheduleSettle()
        }
    }

    /// Declare identification "settled" after a quiet period with no probes.
    private func scheduleSettle() {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.inFlight.isEmpty, self.pending.isEmpty, !self.isSettled {
                self.isSettled = true
            }
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: work)
    }

    private func short(_ uuid: UUID) -> String { String(uuid.uuidString.prefix(8)) }
}

// MARK: - CBCentralManagerDelegate

extension BLEIdentityResolver: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { beginScan() }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advName
        let uuid = peripheral.identifier
        guard shouldProbe(name: name, uuid: uuid) else { return }
        peripherals[uuid] = peripheral
        pending.append(uuid)
        DeviceConsole.log(.ble, "[IdentityResolver] queue uuid=\(short(uuid)) name=\(name ?? "?")")
        pump()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        guard inFlight.contains(uuid) else { return }
        contexts[uuid]?.stepStart = Date()
        armTimeout(uuid, stepTimeout, reason: "discover services")
        peripheral.discoverServices([infoService])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        DeviceConsole.log(.ble, "[IdentityResolver] connect fail uuid=\(short(peripheral.identifier)) err=\(error?.localizedDescription ?? "?")")
        finishProbe(peripheral.identifier, success: false)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let uuid = peripheral.identifier
        let success = pendingOutcome[uuid] ?? false
        pendingOutcome[uuid] = nil
        finishProbe(uuid, success: success)
    }
}

// MARK: - CBPeripheralDelegate

extension BLEIdentityResolver: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let uuid = peripheral.identifier
        guard inFlight.contains(uuid) else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == infoService }) else {
            teardown(peripheral, success: false)
            return
        }
        contexts[uuid]?.stepStart = Date()
        armTimeout(uuid, stepTimeout, reason: "discover chars")
        peripheral.discoverCharacteristics([deviceNameChar], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let uuid = peripheral.identifier
        guard inFlight.contains(uuid) else { return }
        guard error == nil,
              let char = service.characteristics?.first(where: { $0.uuid == deviceNameChar }) else {
            teardown(peripheral, success: false)
            return
        }
        contexts[uuid]?.stepStart = Date()
        armTimeout(uuid, stepTimeout, reason: "read F001")
        peripheral.readValue(for: char)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let uuid = peripheral.identifier
        guard inFlight.contains(uuid) else { return }
        guard error == nil, let data = characteristic.value,
              let raw = String(data: data, encoding: .utf8) else {
            teardown(peripheral, success: false)
            return
        }
        let mac = LimiDeviceNaming.normalizedHardwareId(raw)
        guard mac.count == 12, mac.allSatisfy(\.isHexDigit) else {
            // Firmware that returns a non-MAC string (e.g. "LIMI-Smart-Light").
            DeviceConsole.log(.ble, "[IdentityResolver] F001 not a MAC uuid=\(short(uuid)) value='\(raw)'")
            teardown(peripheral, success: false)
            return
        }

        let name = peripheral.name ?? "LIMI Device"
        ConfiguredBLEDeviceStore.shared.remember(
            hardwareId: mac,
            blePeripheralUUID: uuid.uuidString,
            displayName: name
        )
        resolvedCount += 1
        DeviceConsole.log(.ble, "[IdentityResolver] RESOLVED uuid=\(short(uuid)) mac=\(mac)")

        let callback = onResolved
        DispatchQueue.main.async { callback?() }

        teardown(peripheral, success: true)
    }
}
