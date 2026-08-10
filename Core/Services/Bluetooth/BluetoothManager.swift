//
//  BluetoothManager.swift
//  Limi
//

import CoreBluetooth
import Combine

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
    var centralManager: CBCentralManager?
    var discoveredDevices: [(name: String, id: String)] = []
    var connectedPeripheral: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?
    @Published var connectedDeviceName: String? = nil
    var storedPeripherals: [CBPeripheral] = []
    
    var peripheral: CBPeripheral?
    static let shared = BluetoothManager()
    
    var targetCharacteristic: CBCharacteristic?
    let ff02Value = SharedDevice.shared.lastReceivedFF02Value ?? ""
    @Published var isConnected: Bool = false
    let FB01 = CBUUID(string: "FB01")
    let FB02 = CBUUID(string: "FB02")
    let FB03 = CBUUID(string: "FB03")
    let FB04 = CBUUID(string: "FB04")
    let FB05 = CBUUID(string: "FB05")
    var fbSSIDCharacteristic: CBCharacteristic?
    var fbPasswordCharacteristic: CBCharacteristic?
    var fbAckCharacteristic: CBCharacteristic?
    var fbWifiListCharacteristic: CBCharacteristic?
    var fb05Characteristic: CBCharacteristic?
    var fb05ShouldRead: Bool = false
    var wifiListCompletion: (([String]) -> Void)?
    var provisionCompletion: (((status: String, message: String)) -> Void)?
    var provisionTimeout: DispatchWorkItem?
    struct PendingWrite {
        var retriesLeft: Int
        let data: Data
        let completion: (Bool) -> Void
    }
    var pendingWritesByUUID: [CBUUID: PendingWrite] = [:]
    // Queue messages to send when connection/characteristic becomes available
    var pendingWrites: [[UInt8]] = []
    // Track the target we want to (re)connect to
    private var desiredReconnectId: UUID?
    /// When true, the next `didDisconnect` must not auto-reconnect (intentional cloud handoff).
    private var suppressAutoReconnect = false
    
    var onDevicesUpdated: (([(name: String, id: String)]) -> Void)?
    // If a scan was requested before Bluetooth powered on, start it once powered
    var deferredScan: Bool = false
    /// Number of UI/features that requested an active BLE scan (Home, Add Device, etc.).
    private(set) var activeScanSessions: Int = 0

    private static let scanOptions: [String: Any] = [
        CBCentralManagerScanOptionAllowDuplicatesKey: true
    ]
    /// Background-safe scan must not use `AllowDuplicates` / nil-service thrash.
    private static let reconnectScanOptions: [String: Any] = [:]
    
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
                if activeScanSessions > 0 {
                    beginScanning(clearDiscovered: true)
                }
            }
        }
    }
    
    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void) {
        self.onDevicesUpdated = completion
        activeScanSessions += 1

        if isBluetoothOn {
            if activeScanSessions == 1 {
                beginScanning(clearDiscovered: true)
            } else {
                dispatchDevicesUpdated()
                resumeCentralScanIfNeeded()
            }
        } else {
            print("⚠️ Bluetooth is off. Deferring scan until it powers on.")
            deferredScan = true
        }
    }

    private func beginScanning(clearDiscovered: Bool) {
        if clearDiscovered {
            discoveredDevices.removeAll()
            dispatchDevicesUpdated()
        }
        resumeCentralScanIfNeeded()
    }

    private func dispatchDevicesUpdated() {
        let devices = discoveredDevices
        let callback = onDevicesUpdated
        DispatchQueue.main.async {
            callback?(devices)
        }
    }

    private func resumeCentralScanIfNeeded() {
        guard isBluetoothOn, activeScanSessions > 0 else { return }
        centralManager?.scanForPeripherals(withServices: nil, options: Self.scanOptions)
    }

    /// Restarts the radio scan while keeping the current session alive (e.g. device booted after scan started).
    func refreshScan() {
        guard activeScanSessions > 0, isBluetoothOn else { return }
        centralManager?.stopScan()
        centralManager?.scanForPeripherals(withServices: nil, options: Self.scanOptions)
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
            dispatchDevicesUpdated()
            notifyInterestDeviceIfNeeded(name: name, id: id)
        } else if let index = discoveredDevices.firstIndex(where: { $0.id == id }),
                  discoveredDevices[index].name != name,
                  name != "Unknown Device" {
            discoveredDevices[index] = (name: name, id: id)
            dispatchDevicesUpdated()
        }

        // Auto-connect if we're in a reconnect flow and this is the target
        if let targetId = desiredReconnectId, peripheral.identifier == targetId {
            print("🔎 Found desired peripheral during scan. Connecting...")
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager?.stopScan()
            centralManager?.connect(peripheral, options: nil)
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
        
        resumeScanAfterConnectionEvent()
        
        // After services are discovered, this will trigger didDiscoverServices,
        // which will then discover characteristics and automatically send read request
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
        resumeScanAfterConnectionEvent()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let disconnectedID = peripheral.identifier.uuidString
        
        print("🔴 Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        targetCharacteristic = nil
        connectedPeripheral = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            SharedDevice.shared.connectedDevice = nil
            self.removeDisconnectedDevice(disconnectedID)
            self.lastDisconnectedDeviceID = disconnectedID
        }

        let shouldReconnect = !suppressAutoReconnect
        suppressAutoReconnect = false
        if shouldReconnect {
            // Unexpected drop — remember and try to reconnect.
            desiredReconnectId = peripheral.identifier
            attemptReconnect()
        } else {
            // Intentional disconnect (e.g. cloud restored) — do not fight the door.
            desiredReconnectId = nil
            print("🔌 Intentional BLE disconnect — auto-reconnect suppressed")
        }
        resumeScanAfterConnectionEvent()
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
                    fbAckCharacteristic = characteristic
                    print("✅ FB05 (ACK/Notify) characteristic found")
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        print("✅ Subscribed to FB05 provisioning notifications")
                    }
                    if fb05ShouldRead && characteristic.properties.contains(.read) {
                        print("📤 Sending read request for FB05")
                        peripheral.readValue(for: characteristic)
                        fb05ShouldRead = false
                    }
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
            } else if let existing = self.targetCharacteristic {
                // We already have a target (likely FF03 from another service); do not override.
                print("ℹ️ Writable fallback skipped for service \(service.uuid) because targetCharacteristic already set to \(existing.uuid)")
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
            ensureScanForReconnect()
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
        ensureScanForReconnect()
    }

    private func ensureScanForReconnect() {
        guard isBluetoothOn else {
            deferredScan = true
            return
        }
        if activeScanSessions == 0 {
            // No AllowDuplicates — reconnect only needs one discovery hit.
            centralManager?.scanForPeripherals(withServices: nil, options: Self.reconnectScanOptions)
        }
    }

    private func resumeScanAfterConnectionEvent() {
        guard activeScanSessions > 0, isBluetoothOn else { return }
        resumeCentralScanIfNeeded()
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
    /// - Parameter allowDiscoveryScan: When false (app background), only system/retrieve cache —
    ///   never start an unrestricted `scanForPeripherals` (iOS jetsam / background kill risk).
    func connectToDevice(deviceId: String, allowDiscoveryScan: Bool = true) {
        guard let uuid = UUID(uuidString: deviceId) else {
            print("⚠️ Invalid UUID string: \(deviceId)")
            return
        }

        suppressAutoReconnect = false
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

        guard allowDiscoveryScan else {
            print("⚠️ Device not in cache; skipping discovery scan (background-safe)")
            return
        }

        // Final fallback: rescan until didDiscover auto-connects via desiredReconnectId.
        print("⚠️ Device not found in discovery or system cache. Rescanning...")
        ensureScanForReconnect()
    }

    /// Stop orphan reconnect scanning after a timed-out ensureConnected attempt.
    func clearReconnectTargetAndStopOrphanScan() {
        desiredReconnectId = nil
        if activeScanSessions == 0 {
            centralManager?.stopScan()
        }
    }
    
    func disconnectAllDevices() {
        suppressAutoReconnect = true
        for hub in storedHubs {
            if let peripheral = hub.peripheral { // Ensure peripheral is not nil
                centralManager?.cancelPeripheralConnection(peripheral)
            }
        }
        storedHubs.removeAll()
        connectedDevices.removeAll()
        connectedPeripheral = nil
        targetCharacteristic = nil
        desiredReconnectId = nil
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
        
        // Handle FB05 read + notify (provisioning status)
        if characteristic.uuid == FB05 {
            let bytes = [UInt8](data)
            let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("📥 FB05: bytes=\(bytes) hex=\(hex)")
            // FB05 status codes (firmware contract):
            // 0x00 = idle/ready, 0x01 = credentials received, 0x02 = Wi-Fi joined, 0x03 = Wi-Fi failed
            if bytes.first == 0x03, provisionCompletion != nil {
                provisionTimeout?.cancel()
                provisionTimeout = nil
                provisionCompletion?((status: "error", message: "Device could not join the Wi-Fi network"))
                provisionCompletion = nil
            }
            return
        }
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
    }
    /// - Parameter suppressReconnect: Set true when disconnecting on purpose (cloud restored)
    ///   so `didDisconnect` does not immediately reconnect and fight MQTT.
    func disconnectCurrentDevice(suppressReconnect: Bool = false) {
        if suppressReconnect {
            suppressAutoReconnect = true
            desiredReconnectId = nil
        }
        if let peripheral = connectedPeripheral {
            print("🔌 Disconnecting current device: \(peripheral.name ?? "Unknown Device")")
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            targetCharacteristic = nil
            SharedDevice.shared.connectedDevice = nil
            isConnected = false
        } else if suppressReconnect {
            suppressAutoReconnect = false
        }
    }
    func stopScanning() {
        activeScanSessions = max(0, activeScanSessions - 1)
        if activeScanSessions == 0 {
            centralManager?.stopScan()
            print("🔴 Stopped scanning for peripherals.")
        } else {
            print("🔵 BLE scan session ended (\(activeScanSessions) still active).")
        }
    }
}
