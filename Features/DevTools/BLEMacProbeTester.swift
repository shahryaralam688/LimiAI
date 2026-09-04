//
//  BLEMacProbeTester.swift
//  Limi
//
//  TESTING-ONLY harness. Measures how long it takes to connect to a LIMI
//  "1 CH-HUB" over BLE, read the F001 (device-name) characteristic, and
//  disconnect. Logs the EXACT time of every step (connect / discover / read /
//  disconnect) plus a per-device total and an overall summary.
//
//  Uses its OWN CBCentralManager so it stays isolated from the app's main
//  BluetoothManager. Probes are run SERIALLY so each device's timing is clean.
//
//  NOTE: With current firmware F001 returns a static "LIMI-Smart-Light" string
//  (NOT the MAC). This tool proves that and measures the connect/read cost so we
//  can decide whether a connect-and-read strategy is viable at scale.
//

import CoreBluetooth
import Foundation

/// Isolated, testing-only BLE probe: connect → read F001 → disconnect, timed.
final class BLEMacProbeTester: NSObject, ObservableObject {

    struct LogLine: Identifiable {
        let id = UUID()
        let stamp: Date
        let text: String
    }

    // MARK: - Published state (drives the test UI)

    @Published private(set) var isRunning = false
    @Published private(set) var discoveredCount = 0
    @Published private(set) var probedCount = 0
    @Published private(set) var failedCount = 0
    @Published private(set) var logs: [LogLine] = []

    // MARK: - BLE

    private var central: CBCentralManager?
    private let infoService = CBUUID(string: "F000")   // INFO_SERVICE_UUID
    private let deviceNameChar = CBUUID(string: "F001") // DEVICE_NAME_UUID

    /// Only probe LIMI hubs — skip unrelated peripherals.
    private let nameKeywords = ["CH-HUB", "LIMI"]

    // MARK: - Probe queue (serial)

    private var seenIdentifiers = Set<UUID>()
    private var pendingQueue: [CBPeripheral] = []
    private var current: CBPeripheral?

    // MARK: - Timing

    private var runStart: Date?
    private var connectStart: Date?
    private var stepStart: Date?      // discover/read sub-step
    private var probeStart: Date?     // per-device total
    private var sumProbeMs: Double = 0
    private var timeout: DispatchWorkItem?

    private let connectTimeout: TimeInterval = 10
    private let stepTimeout: TimeInterval = 6

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        resetState()
        isRunning = true
        runStart = Date()
        log("▶︎ START — creating central, waiting for Bluetooth power…")
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        timeout?.cancel()
        timeout = nil
        central?.stopScan()
        if let p = current {
            central?.cancelPeripheralConnection(p)
        }
        current = nil
        pendingQueue.removeAll()
        printSummary()
        central = nil
    }

    func clear() {
        logs.removeAll()
        discoveredCount = 0
        probedCount = 0
        failedCount = 0
        sumProbeMs = 0
    }

    private func resetState() {
        seenIdentifiers.removeAll()
        pendingQueue.removeAll()
        current = nil
        discoveredCount = 0
        probedCount = 0
        failedCount = 0
        sumProbeMs = 0
        logs.removeAll()
    }

    // MARK: - Scan

    private func beginScan() {
        // Duplicates ON so we keep seeing hubs even if the first packet is missed.
        central?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        log("🔍 Scanning for LIMI hubs…")
    }

    private func matchesLimiHub(name: String?) -> Bool {
        guard let name = name?.uppercased() else { return false }
        return nameKeywords.contains { name.contains($0) }
    }

    // MARK: - Serial probe engine

    private func probeNextIfIdle() {
        guard isRunning, current == nil else { return }
        guard !pendingQueue.isEmpty else { return }
        let peripheral = pendingQueue.removeFirst()
        current = peripheral
        peripheral.delegate = self
        probeStart = Date()
        connectStart = Date()
        log("──────────────")
        log("▶︎ PROBE \(probedCount + failedCount + 1): name=\(peripheral.name ?? "?") uuid=\(short(peripheral.identifier))")
        armTimeout(connectTimeout, reason: "connect")
        central?.connect(peripheral, options: nil)
    }

    private func finishCurrent(success: Bool) {
        timeout?.cancel()
        timeout = nil
        if let p = current, p.state != .disconnected {
            central?.cancelPeripheralConnection(p)
            // didDisconnect will null `current` and pull the next one.
            return
        }
        current = nil
        probeNextIfIdle()
    }

    private func armTimeout(_ seconds: TimeInterval, reason: String) {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let p = self.current else { return }
            self.failedCount += 1
            self.log("⏱️ TIMEOUT (\(reason)) after \(Int(seconds))s — uuid=\(self.short(p.identifier))")
            self.finishCurrent(success: false)
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: - Logging helpers

    private func log(_ text: String) {
        let line = LogLine(stamp: Date(), text: text)
        if Thread.isMainThread {
            logs.append(line)
        } else {
            DispatchQueue.main.async { self.logs.append(line) }
        }
        DeviceConsole.log(.ble, "[MacProbe] \(text)")
    }

    private func ms(since date: Date?) -> String {
        guard let date else { return "?" }
        return String(format: "%.0f ms", Date().timeIntervalSince(date) * 1000)
    }

    private func short(_ uuid: UUID) -> String {
        String(uuid.uuidString.prefix(8))
    }

    private func printSummary() {
        let total = probedCount + failedCount
        let avg = probedCount > 0 ? sumProbeMs / Double(probedCount) : 0
        let elapsed = runStart.map { Date().timeIntervalSince($0) } ?? 0
        log("══════════ SUMMARY ══════════")
        log("Discovered LIMI hubs: \(discoveredCount)")
        log("Probed OK: \(probedCount)   Failed: \(failedCount)   Total attempted: \(total)")
        log(String(format: "Avg per successful device: %.0f ms", avg))
        log(String(format: "Total run time: %.1f s", elapsed))
        if probedCount > 0 {
            let projected60 = avg * 60 / 1000
            log(String(format: "→ Projected serial time for 60 devices: %.0f s (~%.1f min)", projected60, projected60 / 60))
        }
        log("═════════════════════════════")
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEMacProbeTester: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("✅ Bluetooth powered on")
            beginScan()
        case .poweredOff:
            log("❌ Bluetooth is OFF — turn it on and press Start again")
            isRunning = false
        case .unauthorized:
            log("❌ Bluetooth unauthorized — grant permission in Settings")
            isRunning = false
        default:
            log("… central state=\(central.state.rawValue)")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advName
        guard matchesLimiHub(name: name) else { return }
        guard !seenIdentifiers.contains(peripheral.identifier) else { return }
        seenIdentifiers.insert(peripheral.identifier)
        discoveredCount += 1
        pendingQueue.append(peripheral)
        log("📡 FOUND #\(discoveredCount): name=\(name ?? "?") uuid=\(short(peripheral.identifier)) rssi=\(RSSI) → queued")
        probeNextIfIdle()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == current?.identifier else { return }
        log("   • connected in \(ms(since: connectStart))")
        stepStart = Date()
        armTimeout(stepTimeout, reason: "discover services")
        peripheral.discoverServices([infoService]) // minimal: only F000
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral.identifier == current?.identifier else { return }
        failedCount += 1
        log("   ✗ failed to connect: \(error?.localizedDescription ?? "unknown") (\(ms(since: connectStart)))")
        finishCurrent(success: false)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral.identifier == current?.identifier else { return }
        log("   • disconnected")
        current = nil
        probeNextIfIdle()
        if pendingQueue.isEmpty && isRunning {
            // Nothing waiting right now — keep scanning; new hubs may still appear.
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEMacProbeTester: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral.identifier == current?.identifier else { return }
        if let error {
            failedCount += 1
            log("   ✗ discoverServices error: \(error.localizedDescription)")
            finishCurrent(success: false)
            return
        }
        log("   • services discovered in \(ms(since: stepStart))")
        guard let service = peripheral.services?.first(where: { $0.uuid == infoService }) else {
            failedCount += 1
            log("   ✗ F000 (info service) not found")
            finishCurrent(success: false)
            return
        }
        stepStart = Date()
        armTimeout(stepTimeout, reason: "discover characteristics")
        peripheral.discoverCharacteristics([deviceNameChar], for: service) // minimal: only F001
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard peripheral.identifier == current?.identifier else { return }
        if let error {
            failedCount += 1
            log("   ✗ discoverCharacteristics error: \(error.localizedDescription)")
            finishCurrent(success: false)
            return
        }
        log("   • characteristics discovered in \(ms(since: stepStart))")
        guard let char = service.characteristics?.first(where: { $0.uuid == deviceNameChar }) else {
            failedCount += 1
            log("   ✗ F001 characteristic not found")
            finishCurrent(success: false)
            return
        }
        stepStart = Date()
        armTimeout(stepTimeout, reason: "read F001")
        peripheral.readValue(for: char)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard peripheral.identifier == current?.identifier else { return }
        if let error {
            failedCount += 1
            log("   ✗ read F001 error: \(error.localizedDescription)")
            finishCurrent(success: false)
            return
        }
        let readMs = ms(since: stepStart)
        let data = characteristic.value ?? Data()
        let utf8 = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        let hex = data.map { String(format: "%02X", $0) }.joined()
        log("   • F001 read in \(readMs)")
        log("   📛 F001 value utf8='\(utf8)'  hex=\(hex.isEmpty ? "<empty>" : hex)")

        let totalMs = Date().timeIntervalSince(probeStart ?? Date()) * 1000
        sumProbeMs += totalMs
        probedCount += 1
        log(String(format: "   ✔ DEVICE TOTAL (connect→read): %.0f ms", totalMs))
        finishCurrent(success: true)
    }
}
