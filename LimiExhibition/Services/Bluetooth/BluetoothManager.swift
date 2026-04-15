//
//  DeviceInfo.swift
//  Limi
//
//  Created by Mac Mini on 19/03/2025.
//

import SwiftUI
import CoreBluetooth

import Combine

struct DeviceInfo: Equatable {
    let name: String
    let id: String
    var receivedBytes: [UInt8] = []
    
    var isNormalMode: Bool {
        return receivedBytes.first == 91
    }
    
    var isDeveloperMode: Bool {
        return receivedBytes.first == 90
    }
}

// MARK: - Global Selected Devices storage (name + uuid), persisted to UserDefaults
struct SelectedDevice: Codable, Equatable, Identifiable {
    var id: String { uuid }
    let name: String
    let uuid: String
}

class SelectedDevicesStorage: ObservableObject {
    static let shared = SelectedDevicesStorage()
    // Expose keys so views can use @AppStorage
    static let listKey = "selected_devices_list"
    static let lastNameKey = "selected_device_last_name"
    static let lastUUIDKey = "selected_device_last_uuid"
    private let listKey = SelectedDevicesStorage.listKey
    private let lastNameKey = SelectedDevicesStorage.lastNameKey
    private let lastUUIDKey = SelectedDevicesStorage.lastUUIDKey

    @Published var items: [SelectedDevice] = []

    private init() {
        load()
    }

    func addOrUpdate(name: String, uuid: String) {
        let new = SelectedDevice(name: name, uuid: uuid)
        if let idx = items.firstIndex(where: { $0.uuid == uuid }) {
            items[idx] = new
        } else {
            items.append(new)
        }
        save()
        // Also store last selected for quick access anywhere
        UserDefaults.standard.set(name, forKey: lastNameKey)
        UserDefaults.standard.set(uuid, forKey: lastUUIDKey)
    }

    func lastSelected() -> SelectedDevice? {
        if let uuid = UserDefaults.standard.string(forKey: lastUUIDKey),
           let name = UserDefaults.standard.string(forKey: lastNameKey) {
            return SelectedDevice(name: name, uuid: uuid)
        }
        return nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: listKey),
              let decoded = try? JSONDecoder().decode([SelectedDevice].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }
}
    

class SharedDevice: ObservableObject {
    static let shared = SharedDevice()
    
    @Published var connectedDevice: DeviceInfo?
    @Published var lastReceivedFF02Value: String?
    @Published var lastReceivedBytes: [UInt8] = [] {
        didSet {
            if lastReceivedBytes.count == 2 {
                let mode = lastReceivedBytes[0]
                let flags = lastReceivedBytes[1]
                print("📊 Received Mode: \(mode == 91 ? "Normal" : mode == 90 ? "Developer" : "Unknown")")
                print("📊 Flags Byte: \(String(format: "%08b", flags))")
            }
        }
    }
    
    var isNormalMode: Bool {
        return lastReceivedBytes.first == 91
    }
    
    var isDeveloperMode: Bool {
        return lastReceivedBytes.first == 90
    }
    
    private init() {}
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isBluetoothOn = false
    @Published var storedHubs: [Hub] = []
    @Published var connectedDevices: [UUID: (peripheral: CBPeripheral, characteristic: CBCharacteristic)] = [:]
    @Published var bleLastSeen: [String: Date] = [:]
    @Published var lastDisconnectedDeviceID: String? = nil
    @Published var DemostoredHubs: [Hub] = [
        Hub(name: "Living Room"),
        Hub(name: "Bedroom"),
        Hub(name: "Kitchen")
    ]
    func addDummyDevice() {
        // Simulate a delay for adding a device
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let newHub = Hub(name: "LIMI Hub")
            self.DemostoredHubs.append(newHub)
        }
    }
    private var centralManager: CBCentralManager?
    private var discoveredDevices: [(name: String, id: String)] = []
    private var connectedPeripheral: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?
    @Published var connectedDeviceName: String? = nil
    var storedPeripherals: [CBPeripheral] = []
    
    var peripheral: CBPeripheral?
    static let shared = BluetoothManager()
    
    var targetCharacteristic: CBCharacteristic?
    let ff02Value = SharedDevice.shared.lastReceivedFF02Value ?? ""
    @Published var isConnected: Bool = false
    private let FB01 = CBUUID(string: "FB01")
    private let FB02 = CBUUID(string: "FB02")
    private let FB03 = CBUUID(string: "FB03")
    private let FB04 = CBUUID(string: "FB04")
    private let FB05 = CBUUID(string: "FB05")
    private var fbSSIDCharacteristic: CBCharacteristic?
    private var fbPasswordCharacteristic: CBCharacteristic?
    private var fbAckCharacteristic: CBCharacteristic?
    private var fbWifiListCharacteristic: CBCharacteristic?
    private var fb05Characteristic: CBCharacteristic?
    private var fb05ShouldRead: Bool = false
    private var wifiListCompletion: (([String]) -> Void)?
    private var provisionCompletion: (((status: String, message: String)) -> Void)?
    private var provisionTimeout: DispatchWorkItem?
    private struct PendingWrite {
        var retriesLeft: Int
        let data: Data
        let completion: (Bool) -> Void
    }
    private var pendingWritesByUUID: [CBUUID: PendingWrite] = [:]
    // Queue messages to send when connection/characteristic becomes available
    private var pendingWrites: [[UInt8]] = []
    // Track the target we want to (re)connect to
    private var desiredReconnectId: UUID?
    
    var onDevicesUpdated: (([(name: String, id: String)]) -> Void)?
    // If a scan was requested before Bluetooth powered on, start it once powered
    private var deferredScan: Bool = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // Convenience to select a device, persist it globally, and start connection
    func selectAndConnect(name: String, uuidString: String) {
        SelectedDevicesStorage.shared.addOrUpdate(name: name, uuid: uuidString)
        connectToDevice(deviceId: uuidString)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.isBluetoothOn = central.state == .poweredOn
        }
        if central.state == .poweredOn {
            // If we have a device we want to reconnect to, try now
            if let targetId = desiredReconnectId {
                print("⚙️ Bluetooth powered on — attempting reconnect to saved target: \(targetId)")
                attemptReconnect()
            }
            // If a scan was deferred, begin it now
            if deferredScan {
                print("🚀 Bluetooth powered on — starting deferred scan")
                deferredScan = false
                beginScanning()
            }
        }
    }
    
    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void) {
        // Always keep the latest completion handler
        self.onDevicesUpdated = completion
        
        if isBluetoothOn {
            beginScanning()
        } else {
            print("⚠️ Bluetooth is off. Deferring scan until it powers on.")
            deferredScan = true
        }
    }

    private func beginScanning() {
        discoveredDevices.removeAll()
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown Device"
        let id = peripheral.identifier.uuidString
        
        if !storedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            storedPeripherals.append(peripheral)
        }
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
//        print("🔍 Discovered: \(name) | ID: \(id) | \(RSSI)")
//        // 🔎 Print all keys and values from advertisement data
//        print("📡 Advertisement Data:")
//        for (key, value) in advertisementData {
//            print("   \(key): \(value)")
//        }

        DispatchQueue.main.async { [weak self] in
            self?.bleLastSeen[id] = Date()
        }

        if !discoveredDevices.contains(where: { $0.id == id }) {
            discoveredDevices.append((name: name, id: id))
            onDevicesUpdated?(discoveredDevices)
        }

        // Auto-connect if we're in a reconnect flow and this is the target
        if let targetId = desiredReconnectId, peripheral.identifier == targetId {
            print("🔎 Found desired peripheral during scan. Connecting...")
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager?.connect(peripheral, options: nil)
            stopScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        // Remember this for future reconnect attempts
        desiredReconnectId = peripheral.identifier
        
        if !storedHubs.contains(where: { $0.id == peripheral.identifier }) {
            let hub = Hub(peripheral: peripheral)
            storedHubs.append(hub)
            print("📌 Stored Hub: \(hub.name)")
        }
        
        connectedPeripheral = peripheral
        SharedDevice.shared.connectedDevice = DeviceInfo(name: peripheral.name ?? "Unknown", id: peripheral.identifier.uuidString)
        DispatchQueue.main.async {
            self.isConnected = true
        }
        
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        // After services are discovered, this will trigger didDiscoverServices,
        // which will then discover characteristics and automatically send read request
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let disconnectedID = peripheral.identifier.uuidString
        
        print("🔴 Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        targetCharacteristic = nil
        connectedPeripheral = nil
        
        DispatchQueue.main.async {
            SharedDevice.shared.connectedDevice = nil
            self.removeDisconnectedDevice(disconnectedID)
            self.lastDisconnectedDeviceID = disconnectedID
        }
        // Remember the last device we were connected to and try to reconnect
        desiredReconnectId = peripheral.identifier
        attemptReconnect()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("Discovered Service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Error discovering characteristics: \(error.localizedDescription)")
            // Retry discovery after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found!")
            return
        }
        // Track if FF03 is within THIS service
        var foundFF03 = false
        for characteristic in characteristics {
            let props = characteristic.properties
            let propsDesc: [String] = [
                props.contains(.read) ? "read" : nil,
                props.contains(.write) ? "write" : nil,
                props.contains(.writeWithoutResponse) ? "writeNoRsp" : nil,
                props.contains(.notify) ? "notify" : nil,
                props.contains(.indicate) ? "indicate" : nil
            ].compactMap { $0 }
            print("🔎 Discovered Characteristic: \(characteristic.uuid) props=[\(propsDesc.joined(separator: ","))]")

            if characteristic.uuid == CBUUID(string: "FF03") {
                print("✅ FF03 characteristic found!")
                // Always prefer FF03, overriding any previous fallback
                self.targetCharacteristic = characteristic
                connectedDevices[peripheral.identifier] = (peripheral: peripheral, characteristic: characteristic)
                foundFF03 = true
                // Flush any pending writes now that FF03 is available
                flushPendingWrites()
            }

            if characteristic.uuid == CBUUID(string: "FF02") {
                print("✅ FF02 characteristic found!")
                if characteristic.properties.contains(.read) {
                    print("📤 Sending read request for FF02")
                    peripheral.readValue(for: characteristic)
                }
            }

            if service.uuid == FB01 {
                if characteristic.uuid == FB02 {
                    fbSSIDCharacteristic = characteristic
                    print("✅ FB02 (SSID) characteristic found")
                } else if characteristic.uuid == FB03 {
                    fbPasswordCharacteristic = characteristic
                    print("✅ FB03 (Password) characteristic found")
                } else if characteristic.uuid == FB04 {
                    fbWifiListCharacteristic = characteristic
                    print("✅ FB04 (Wi-Fi List) characteristic found")
                    // If someone is waiting for a Wi‑Fi list read, trigger it now
                    if let _ = wifiListCompletion, characteristic.properties.contains(.read) {
                        print("📤 Sending read request for FB04 (Wi‑Fi list)")
                        peripheral.readValue(for: characteristic)
                    }
                } else if characteristic.uuid == FB05 {
                    fb05Characteristic = characteristic
                    print("✅ FB05 characteristic found")
                    if fb05ShouldRead && characteristic.properties.contains(.read) {
                        print("📤 Sending read request for FB05")
                        peripheral.readValue(for: characteristic)
                        fb05ShouldRead = false
                    }
                }
                if characteristic.properties.contains(.notify) {
                    fbAckCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("✅ Subscribed to FB01 notification characteristic: \(characteristic.uuid)")
                }
            }
        }

        // If FF03 was not found IN THIS SERVICE, we may consider a fallback
        // But only do so if we haven't already selected a targetCharacteristic earlier.
        if !foundFF03 {
            if self.targetCharacteristic == nil {
                if let anyWritable = characteristics.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) {
                    print("✅ Using writable characteristic as target (fallback): \(anyWritable.uuid)")
                    self.targetCharacteristic = anyWritable
                    connectedDevices[peripheral.identifier] = (peripheral: peripheral, characteristic: anyWritable)
                    flushPendingWrites()
                } else {
                    print("⚠️ No writable characteristic found on service \(service.uuid)")
                }
            } else {
                // We already have a target (likely FF03 from another service); do not override.
                print("ℹ️ Writable fallback skipped for service \(service.uuid) because targetCharacteristic already set to \(self.targetCharacteristic!.uuid)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid
        if var pending = pendingWritesByUUID[uuid] {
            if let error = error {
                print("❌ Write error on \(uuid): \(error.localizedDescription)")
                if pending.retriesLeft > 0 {
                    pending.retriesLeft -= 1
                    pendingWritesByUUID[uuid] = pending
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        peripheral.writeValue(pending.data, for: characteristic, type: .withResponse)
                    }
                    return
                } else {
                    pendingWritesByUUID.removeValue(forKey: uuid)
                    pending.completion(false)
                    return
                }
            } else {
                pendingWritesByUUID.removeValue(forKey: uuid)
                pending.completion(true)
            }
        } else {
            if let error = error {
                print("❌ Error writing to \(characteristic.uuid): \(error.localizedDescription)")
            } else {
                print("✅ Successfully wrote to \(characteristic.uuid)")
            }
        }
    }
    
    func sendMessageToDevice(to deviceID: UUID, message: [UInt8]) {
        guard let deviceInfo = connectedDevices[deviceID] else {
            print("⚠️ Device not found!")
            return
        }
        
        let peripheral = deviceInfo.peripheral
        let characteristic = deviceInfo.characteristic
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            enqueue(message)
            attemptReconnect()
            return
        }
        
        let data = Data(message)
        let props = characteristic.properties
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : (props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        print("📤 Writing to \(characteristic) (type=\(writeType == .withResponse ? "withResponse" : "withoutResponse")): \(data)")
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    func writeDataToFF03(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found! Reconnecting...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        guard let characteristic = targetCharacteristic else {
            print("⚠️ FF03 characteristic is missing! Rediscovering...")
            enqueue(bytes)
            peripheral.discoverServices(nil)
            return
        }
        
        let dataToSend = Data(bytes)
        let props = characteristic.properties
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : (props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📤 Writing to FF03 (type=\(writeType == .withResponse ? "withResponse" : "withoutResponse")) | name=\(peripheral.name ?? "Unknown"), id=\(peripheral.identifier.uuidString) | bytes=\(bytes) | hex=\(hex)")
        peripheral.writeValue(dataToSend, for: characteristic, type: writeType)
    }
    
    func startKeepAlive() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if self.connectedPeripheral?.state == .connected {
                print("🔄 Sending keep-alive ping...")
                self.writeDataToFF03([0x01, 0x02, 0x03])
            } else {
                print("⚠️ Cannot send keep-alive, peripheral disconnected!")
            }
        }
    }
    
    func attemptReconnect() {
        // Prefer desiredReconnectId if set
        if let targetId = desiredReconnectId {
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [targetId]) ?? []
            if let peripheral = peripherals.first {
                print("♻️ Attempting to reconnect to \(peripheral.name ?? "Unknown Device")...")
                connectedPeripheral = peripheral
                peripheral.delegate = self
                centralManager?.connect(peripheral, options: nil)
                return
            }
            // If not in system cache, scan until we rediscover it (didDiscover will auto-connect)
            print("⚠️ No system-cached peripheral. Scanning to find target again…")
            startScanning { [weak self] _ in
                // didDiscover handles auto-connect when peripheral matches desiredReconnectId
                guard let _ = self else { return }
            }
            return
        }

        // Fallback: use SharedDevice record if available
        if let savedDevice = SharedDevice.shared.connectedDevice,
           let uuid = UUID(uuidString: savedDevice.id) {
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [uuid]) ?? []
            if let peripheral = peripherals.first {
                print("♻️ Attempting to reconnect to \(savedDevice.name)...")
                connectedPeripheral = peripheral
                peripheral.delegate = self
                centralManager?.connect(peripheral, options: nil)
                return
            }
        }

        print("⚠️ No known peripheral to reconnect. Start scanning again.")
        startScanning { _ in }
    }
    
    func removeDisconnectedDevice(_ deviceID: String) {
        if let uuid = UUID(uuidString: deviceID) {
            DispatchQueue.main.async {
                self.storedHubs.removeAll { $0.id == uuid }
                // Also remove from connectedDevices dictionary
                self.connectedDevices.removeValue(forKey: uuid)
            }
        }
    }
    func connectToDevice(deviceId: String) {
        guard let uuid = UUID(uuidString: deviceId) else {
            print("⚠️ Invalid UUID string: \(deviceId)")
            return
        }

        desiredReconnectId = uuid

        // Prefer a recently discovered peripheral (most reliable)
        if let peripheral = storedPeripherals.first(where: { $0.identifier == uuid }) {
            print("🔗 Connecting to \(peripheral.name ?? "Unknown Device") (from discovery cache)")
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager?.connect(peripheral, options: nil)
            return
        }

        // Fallback to system cache
        if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
            print("🔗 Connecting to \(peripheral.name ?? "Unknown Device") (from system cache)")
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager?.connect(peripheral, options: nil)
            return
        }

        // Final fallback: rescan briefly and attempt to connect if found
        print("⚠️ Device not found in discovery or system cache. Rescanning...")
        startScanning { [weak self] devices in
            guard let self = self else { return }
            // Attempt to connect as soon as the target shows up
            if let target = self.storedPeripherals.first(where: { $0.identifier == uuid }) {
                print("🔗 Connecting to \(target.name ?? "Unknown Device") (after rescan)")
                self.connectedPeripheral = target
                target.delegate = self
                self.centralManager?.connect(target, options: nil)
                self.stopScanning()
            }
        }
    }
    
    func disconnectAllDevices() {
        for hub in storedHubs {
            if let peripheral = hub.peripheral { // Ensure peripheral is not nil
                centralManager?.cancelPeripheralConnection(peripheral)
            }
        }
        storedHubs.removeAll()
        connectedDevices.removeAll()
        connectedPeripheral = nil
        targetCharacteristic = nil
        SharedDevice.shared.connectedDevice = nil
        isConnected = false
        print("🔌 All devices have been disconnected.")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Error reading value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("❌ No data received")
            return
        }
        
        if characteristic.uuid == CBUUID(string: "FF02") {
            let bytes = [UInt8](data)  // Convert Data to byte array
            print("📥 FF02 Raw bytes: \(bytes)")
            
            DispatchQueue.main.async {
                // Store raw bytes directly
                SharedDevice.shared.lastReceivedBytes = bytes
                
                if var device = SharedDevice.shared.connectedDevice {
                    device.receivedBytes = bytes
                    SharedDevice.shared.connectedDevice = device
                }
            }
        }
        
        // Handle FB05 generic read/print
        if characteristic.uuid == FB05 {
            let bytes = [UInt8](data)
            let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("📥 FB05 Raw bytes: \(bytes) | hex=\(hex)")
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                print("📥 FB05 UTF-8: \(text)")
            } else {
                print("ℹ️ FB05 value not valid UTF-8 or empty")
            }
            return
        }

        // Handle Wi‑Fi SSID list read from FB04
        if characteristic.uuid == FB04 {
            if let text = String(data: data, encoding: .utf8) {
                print("📥 FB04 raw text: \(text)")
                let ssids: [String] = Self.parseSSIDArrayString(text)
                if !ssids.isEmpty {
                    print("✅ Parsed SSID list (\(ssids.count))")
                } else {
                    print("⚠️ Parsed SSID list is empty")
                }
                DispatchQueue.main.async { [weak self] in
                    self?.wifiListCompletion?(ssids)
                    self?.wifiListCompletion = nil
                }
            } else {
                print("❌ Failed to decode FB04 data as UTF‑8 string")
                DispatchQueue.main.async { [weak self] in
                    self?.wifiListCompletion?([])
                    self?.wifiListCompletion = nil
                }
            }
            return
        }

        if characteristic.service?.uuid == FB01 {
            if characteristic == fbAckCharacteristic {
                provisionTimeout?.cancel()
                provisionTimeout = nil
                let msg = "Wi-Fi credentials written and acknowledged"
                provisionCompletion?((status: "success", message: msg))
                provisionCompletion = nil
                DispatchQueue.main.async {
                    self.isConnected = true
                }
            }
        }
    }
    func disconnectCurrentDevice() {
        if let peripheral = connectedPeripheral {
            print("🔌 Disconnecting current device: \(peripheral.name ?? "Unknown Device")")
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            targetCharacteristic = nil
            SharedDevice.shared.connectedDevice = nil
            isConnected = false
        }
    }
    func writeValue(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found! Reconnecting...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        writeDataToFF03(bytes)
    }

    /// Convenience: send UTF-8 string payloads over FF03
    func writeString(_ text: String) {
        let bytes = Array(text.utf8)
        print("📝 Preparing to send string (UTF-8): \(text)")
        writeValue(bytes)
    }

    /// Simple helper requested: send a plain string message to the connected BLE device.
    /// Logs whether it is queued (not yet connected/ready) or being sent now.
    func BLESend(message: String) {
        print("➡️ BLESend called with message: \(message)")
        writeString(message)
    }

    // MARK: - Pending write helpers
    private func enqueue(_ bytes: [UInt8]) {
        pendingWrites.append(bytes)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("🕓 Queued write until connected/ready: bytes=\(bytes) | hex=\(hex)")
    }

    private func flushPendingWrites() {
        guard !pendingWrites.isEmpty else { return }
        print("🚀 Flushing \(pendingWrites.count) pending write(s)...")
        let writes = pendingWrites
        pendingWrites.removeAll()
        for payload in writes {
            writeDataToFF03(payload)
        }
    }
    func readValue() {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found!")
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            attemptReconnect()
            return
        }
        
        // Find FF02 characteristic in all services
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == CBUUID(string: "FF02") {
                    print("📥 Sending read request for FF02")
                    peripheral.readValue(for: characteristic)
                    return
                }
            }
        }
        
        print("⚠️ FF02 characteristic not found! Rediscovering services...")
        peripheral.discoverServices(nil)
    }

    func provisionWifi(ssid: String, password: String, completion: @escaping ((status: String, message: String)) -> Void) {
        guard let peripheral = connectedPeripheral else {
            completion((status: "error", message: "No connected peripheral"))
            return
        }
        let maxSSID = 32
        let maxPass = 64
        var ssidBytes = Array(ssid.utf8)
        var passBytes = Array(password.utf8)
        if ssidBytes.count > maxSSID { ssidBytes = Array(ssidBytes.prefix(maxSSID)); print("ℹ️ SSID truncated to \(maxSSID) bytes") }
        if passBytes.count > maxPass { passBytes = Array(passBytes.prefix(maxPass)); print("ℹ️ Password truncated to \(maxPass) bytes") }
        guard let ssidChar = fbSSIDCharacteristic, let passChar = fbPasswordCharacteristic else {
            peripheral.discoverServices([FB01])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.fbSSIDCharacteristic == nil || self.fbPasswordCharacteristic == nil {
                    completion((status: "error", message: "Required characteristics FB02/FB03 not found"))
                } else {
                    self.provisionWifi(ssid: ssid, password: password, completion: completion)
                }
            }
            return
        }
        self.provisionCompletion = completion
        writeWithRetry(peripheral: peripheral, characteristic: ssidChar, data: Data(ssidBytes), retriesLeft: 2) { [weak self] ok1 in
            guard let self = self else { return }
            if !ok1 {
                self.provisionCompletion?((status: "error", message: "Failed to write SSID after retries"))
                self.provisionCompletion = nil
                return
            }
            self.writeWithRetry(peripheral: peripheral, characteristic: passChar, data: Data(passBytes), retriesLeft: 2) { ok2 in
                if !ok2 {
                    self.provisionCompletion?((status: "error", message: "Failed to write password after retries"))
                    self.provisionCompletion = nil
                    return
                }
                if self.fbAckCharacteristic != nil {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        self.provisionCompletion?((status: "warning", message: "No acknowledgement received; connection kept"))
                        self.provisionCompletion = nil
                    }
                    self.provisionTimeout?.cancel()
                    self.provisionTimeout = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
                } else {
                    self.provisionCompletion?((status: "warning", message: "No confirmation characteristic; credentials written"))
                    self.provisionCompletion = nil
                }
            }
        }
    }
    func fbo5Wifi(){
        readFB05()
    }

    func readFB05() {
        guard let peripheral = connectedPeripheral else {
            print("❌ readFB05: No connected peripheral")
            fb05ShouldRead = true
            return
        }
        guard peripheral.state == .connected else {
            print("⚠️ readFB05: Peripheral not connected — attempting reconnect")
            fb05ShouldRead = true
            attemptReconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readFB05()
            }
            return
        }
        if let ch = fb05Characteristic, ch.properties.contains(.read) {
            print("📤 readFB05: Using cached FB05 characteristic")
            peripheral.readValue(for: ch)
            return
        }
        // Need to (re)discover within FB01
        print("🔎 readFB05: Discovering FB01/FB05…")
        fb05ShouldRead = true
        peripheral.discoverServices([FB01])
    }

    private func writeWithRetry(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data, retriesLeft: Int, completion: @escaping (Bool) -> Void) {
        pendingWritesByUUID[characteristic.uuid] = PendingWrite(retriesLeft: retriesLeft, data: data, completion: completion)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        print("🔴 Stopped scanning for peripherals.")
    }
}

// MARK: - FB04 Wi‑Fi list helpers
extension BluetoothManager {
    /// Request Wi‑Fi SSID list from FB04 characteristic. Calls completion on main thread.
    func readWifiList(completion: @escaping ([String]) -> Void) {
        guard let peripheral = connectedPeripheral else {
            print("❌ readWifiList: No connected peripheral")
            completion([])
            return
        }
        guard peripheral.state == .connected else {
            print("⚠️ readWifiList: Peripheral not connected — attempting reconnect")
            wifiListCompletion = completion
            attemptReconnect()
            // Try again shortly after services rediscovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readWifiList(completion: completion)
            }
            return
        }

        wifiListCompletion = completion

        // If we already have the characteristic, read immediately
        if let fb04 = fbWifiListCharacteristic, fb04.properties.contains(.read) {
            print("📤 readWifiList: Using cached FB04 characteristic")
            peripheral.readValue(for: fb04)
            return
        }

        // Otherwise, rediscover FB01 service; didDiscoverCharacteristics will trigger read if waiting
        print("🔎 readWifiList: Discovering FB01/FB04…")
        peripheral.discoverServices([FB01])
    }

    /// Parse a string that looks like an array into [String]. Prefer JSON, fallback to comma-split.
    private static func parseSSIDArrayString(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try JSON first
        if let data = trimmed.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any] {
            return arr.compactMap { elem in
                if let s = elem as? String { return s }
                if let n = elem as? NSNumber { return n.stringValue }
                return nil
            }
        }
        // Fallback: strip brackets and quotes, then split by comma
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if stripped.isEmpty { return [] }
        return stripped
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { s in
                var v = s
                if v.hasPrefix("\"") && v.hasSuffix("\"") {
                    v = String(v.dropFirst().dropLast())
                }
                return v
            }
    }
}

// MARK: - Background scanning + interest device popup

extension BluetoothManager {
    // Only these get a popup
    private var interestDeviceNames: Set<String> { ["1 CH-HUB", "4 CH-HUB"] }

    // Call once at app launch (e.g., in App.init or SceneDelegate) to keep scanning in the background.
    // Does not require any view to be on-screen.
    func enableBackgroundScan() {
        // Start scanning and route discoveries through our handler
        startScanning { [weak self] devices in
            guard let self = self else { return }
            for item in devices {
                self.handleInterestDeviceDiscovered(name: item.name, id: item.id)
            }
        }
        // Also maintain periodic scan cycles to keep discovery fresh.
        scheduleBackgroundScanTick()
    }

    // MARK: - Internal helpers

    private func scheduleBackgroundScanTick() {
        backgroundScanTimer?.invalidate()
        // Kick off immediately
        startBackgroundScanCycle()
        // Repeat periodically
        backgroundScanTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.startBackgroundScanCycle()
        }
        RunLoop.main.add(backgroundScanTimer!, forMode: .common)
    }

    private func startBackgroundScanCycle() {
        guard let cm = centralManager else { return }
        if cm.state == .poweredOn {
            // Short scan burst with duplicates allowed to catch brief advertisements
            cm.stopScan()
            discoveredDevices.removeAll()
            cm.scanForPeripherals(withServices: nil,
                                  options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                self?.centralManager?.stopScan()
            }
        } else {
            // When BT powers on, startScanning() will pick it up due to internal deferral
            deferredScan = true
        }
    }

    fileprivate func handleInterestDeviceDiscovered(name: String, id: String) {
        guard interestDeviceNames.contains(name) else { return }
        GlobalDevicePopup.shared.showDeviceFound(
            title: "Hub Found",
            deviceName: name,
            deviceId: id
        ) { [weak self] in
            self?.selectAndConnect(name: name, uuidString: id)
        }
    }
}

// MARK: - Global popup presenter

final class GlobalDevicePopup {
    static let shared = GlobalDevicePopup()

    private var window: UIWindow?
    private var isShowing = false

    private init() {}

    func showDeviceFound(title: String, deviceName: String, deviceId: String, onConnect: @escaping () -> Void) {
        guard !isShowing else { return }
        isShowing = true

        let root = HubFoundPopupView(
            title: title,
            deviceName: deviceName,
            deviceId: deviceId,
            onConnect: { [weak self] in
                onConnect()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        {
            let window = UIWindow(windowScene: scene)
            window.rootViewController = hosting
            window.windowLevel = .alert + 1
            window.backgroundColor = .clear
            window.isHidden = false
            window.makeKeyAndVisible()
            self.window = window
        } else {
            // Fallback: present on a new window even if no active scene found
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hosting
            window.windowLevel = .alert + 1
            window.backgroundColor = .clear
            window.isHidden = false
            window.makeKeyAndVisible()
            self.window = window
        }

        // Auto-dismiss after a short delay if user does nothing
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard isShowing else { return }
        isShowing = false
        UIView.animate(withDuration: 0.25, animations: {
            self.window?.alpha = 0
        }, completion: { _ in
            self.window?.isHidden = true
            self.window = nil
        })
    }
}

// MARK: - SwiftUI popup content

struct HubFoundPopupView: View {
    let title: String
    let deviceName: String
    let deviceId: String
    let onConnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.themeBlack.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.themeWhite)

                VStack(spacing: 6) {
                    Text(deviceName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.themeWhite)
                    Text(deviceId)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.themeWhite.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeWhite.opacity(0.12))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(10)
                    }

                    Button(action: onConnect) {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.themeBlack.opacity(0.35))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.themeWhite.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Stored properties for timer (same file to access privates)

extension BluetoothManager {
    private struct AssociatedKeys {
        static var backgroundScanTimerKey: UInt8 = 0
    }

    private var backgroundScanTimer: Timer? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
