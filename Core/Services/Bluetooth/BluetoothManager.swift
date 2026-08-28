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
    /// Invalidates stale `readWifiList` timeouts when a newer read starts or completes.
    var wifiListReadToken: UUID?
    var provisionCompletion: (((status: String, message: String)) -> Void)?
    var provisionTimeout: DispatchWorkItem?
    struct PendingWrite {
        var retriesLeft: Int
        let data: Data
        let completion: (Bool) -> Void
        var timeoutWork: DispatchWorkItem?
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
    /// Always-current ad timestamps (not @Published — avoids per-frame SwiftUI churn).
    private var advertisementSeenAt: [String: Date] = [:]
    private var lastBleLastSeenPublishAt: Date = .distantPast

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
    
    /// Use this for Core Bluetooth commands — `isBluetoothOn` can lag one run-loop.
    var isRadioPoweredOn: Bool {
        centralManager?.state == .poweredOn
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn
        if central.state == .poweredOn {
            // If we have a device we want to reconnect to, try now
            if let targetId = desiredReconnectId {
                attemptReconnect()
            }
            // If a scan was deferred, begin it now
            if deferredScan {
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

        if isRadioPoweredOn {
            if activeScanSessions == 1 {
                beginScanning(clearDiscovered: true)
            } else {
                dispatchDevicesUpdated()
                resumeCentralScanIfNeeded()
            }
        } else {
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
        guard isRadioPoweredOn, activeScanSessions > 0 else { return }
        centralManager?.scanForPeripherals(withServices: nil, options: Self.scanOptions)
    }

    /// Restarts the radio scan while keeping the current session alive (e.g. device booted after scan started).
    func refreshScan() {
        guard activeScanSessions > 0, isRadioPoweredOn else { return }
        centralManager?.stopScan()
        centralManager?.scanForPeripherals(withServices: nil, options: Self.scanOptions)
    }

    /// Cold-start helper: wait until the radio is powered on before scanning.
    func waitUntilPoweredOn(timeout: TimeInterval) async -> Bool {
        if isRadioPoweredOn { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isRadioPoweredOn { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return isRadioPoweredOn
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
            self?.recordAdvertisementSeen(uuid: id)
        }

        let isConfiguredTarget = ConfiguredBLEDeviceStore.shared.allRecords.contains {
            $0.blePeripheralUUID.caseInsensitiveCompare(id) == .orderedSame
        } || (desiredReconnectId?.uuidString.caseInsensitiveCompare(id) == .orderedSame)
        DeviceConsole.bleAdvertisement(
            name: name,
            uuid: id,
            rssi: RSSI,
            isConfiguredTarget: isConfiguredTarget
        )

        if !discoveredDevices.contains(where: { $0.id == id }) {
            discoveredDevices.append((name: name, id: id))
            dispatchDevicesUpdated()
            notifyInterestDeviceIfNeeded(name: name, id: id)
            if LimiDeviceNaming.isAllowedDeviceName(name) {
                DeviceConsole.log(.ble, "scan found name=\(name) uuid=\(id) rssi=\(RSSI)")
            }
        } else if let index = discoveredDevices.firstIndex(where: { $0.id == id }),
                  discoveredDevices[index].name != name,
                  name != "Unknown Device" {
            discoveredDevices[index] = (name: name, id: id)
            dispatchDevicesUpdated()
        }

        // Auto-connect if we're in a reconnect flow and this is the target.
        // Do not stop a Home presence scan — other hubs may still be advertising.
        if let targetId = desiredReconnectId, peripheral.identifier == targetId {
            if peripheral.state != .connected && peripheral.state != .connecting {
                DeviceConsole.log(.ble, "auto-connect configured target uuid=\(id)")
                peripheral.delegate = self
                if activeScanSessions == 0 {
                    centralManager?.stopScan()
                }
                centralManager?.connect(peripheral, options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Remember this for future reconnect attempts
        desiredReconnectId = peripheral.identifier
        DeviceConsole.log(
            .ble,
            "connected name=\(peripheral.name ?? "?") uuid=\(peripheral.identifier.uuidString)"
        )
        
        if !storedHubs.contains(where: { $0.id == peripheral.identifier }) {
            let hub = Hub(peripheral: peripheral)
            storedHubs.append(hub)
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
        DeviceConsole.log(
            .ble,
            "connect FAIL uuid=\(peripheral.identifier.uuidString) \(error?.localizedDescription ?? "")"
        )
        resumeScanAfterConnectionEvent()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let disconnectedID = peripheral.identifier.uuidString
        DeviceConsole.log(
            .ble,
            "disconnected uuid=\(disconnectedID) \(error?.localizedDescription ?? "")"
        )

        connectedDevices.removeValue(forKey: peripheral.identifier)

        let wasCurrent = connectedPeripheral?.identifier == peripheral.identifier
        if wasCurrent {
            connectedPeripheral = nil
            targetCharacteristic = nil
            clearProvisioningCharacteristics()
        }

        // Keep another still-connected hub as the current write target.
        if let other = connectedDevices.first(where: { $0.value.peripheral.state == .connected }) {
            connectedPeripheral = other.value.peripheral
            targetCharacteristic = other.value.characteristic
            DispatchQueue.main.async {
                self.isConnected = true
                self.removeDisconnectedDevice(disconnectedID)
                self.lastDisconnectedDeviceID = disconnectedID
            }
        } else {
            DispatchQueue.main.async {
                self.isConnected = false
                SharedDevice.shared.connectedDevice = nil
                self.removeDisconnectedDevice(disconnectedID)
                self.lastDisconnectedDeviceID = disconnectedID
            }
        }

        let shouldReconnect = !suppressAutoReconnect
        suppressAutoReconnect = false
        if shouldReconnect {
            desiredReconnectId = peripheral.identifier
            attemptReconnect()
        } else if desiredReconnectId == peripheral.identifier {
            desiredReconnectId = nil
        }
        resumeScanAfterConnectionEvent()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            // Retry discovery after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            return
        }
        
        guard let characteristics = service.characteristics else {
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

            if characteristic.uuid == CBUUID(string: "FF03") {
                // Always prefer FF03, overriding any previous fallback
                self.targetCharacteristic = characteristic
                connectedDevices[peripheral.identifier] = (peripheral: peripheral, characteristic: characteristic)
                foundFF03 = true
                // Flush any pending writes now that FF03 is available
                flushPendingWrites()
            }

            if characteristic.uuid == CBUUID(string: "FF02") {
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }

            if service.uuid == FB01 {
                if characteristic.uuid == FB02 {
                    fbSSIDCharacteristic = characteristic
                } else if characteristic.uuid == FB03 {
                    fbPasswordCharacteristic = characteristic
                } else if characteristic.uuid == FB04 {
                    fbWifiListCharacteristic = characteristic
                    // If someone is waiting for a Wi‑Fi list read, trigger it now
                    if let _ = wifiListCompletion, characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                } else if characteristic.uuid == FB05 {
                    fb05Characteristic = characteristic
                    fbAckCharacteristic = characteristic
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    if fb05ShouldRead && characteristic.properties.contains(.read) {
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
                    self.targetCharacteristic = anyWritable
                    connectedDevices[peripheral.identifier] = (peripheral: peripheral, characteristic: anyWritable)
                    flushPendingWrites()
                } else {
                }
            } else if let existing = self.targetCharacteristic {
                // We already have a target (likely FF03 from another service); do not override.
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid
        if var pending = pendingWritesByUUID[uuid] {
            if let error = error {
                if pending.retriesLeft > 0 {
                    pending.retriesLeft -= 1
                    pendingWritesByUUID[uuid] = pending
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        peripheral.writeValue(pending.data, for: characteristic, type: .withResponse)
                    }
                    return
                } else {
                    pending.timeoutWork?.cancel()
                    pendingWritesByUUID.removeValue(forKey: uuid)
                    pending.completion(false)
                    return
                }
            } else {
                pending.timeoutWork?.cancel()
                pendingWritesByUUID.removeValue(forKey: uuid)
                pending.completion(true)
            }
        } else {
            if let error = error {
            } else {
            }
        }
    }
    
    func sendMessageToDevice(to deviceID: UUID, message: [UInt8]) {
        guard let deviceInfo = connectedDevices[deviceID] else {
            return
        }
        
        let peripheral = deviceInfo.peripheral
        let characteristic = deviceInfo.characteristic
        
        if peripheral.state != .connected {
            enqueue(message)
            attemptReconnect()
            return
        }
        
        let data = Data(message)
        let props = characteristic.properties
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : (props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    func startKeepAlive() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if self.connectedPeripheral?.state == .connected {
                self.writeDataToFF03([0x01, 0x02, 0x03])
            } else {
            }
        }
    }
    
    func attemptReconnect() {
        // Prefer desiredReconnectId if set
        if let targetId = desiredReconnectId {
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [targetId]) ?? []
            if let peripheral = peripherals.first {
                connectedPeripheral = peripheral
                peripheral.delegate = self
                centralManager?.connect(peripheral, options: nil)
                return
            }
            // If not in system cache, scan until we rediscover it (didDiscover will auto-connect)
            ensureScanForReconnect()
            return
        }

        // Fallback: use SharedDevice record if available
        if let savedDevice = SharedDevice.shared.connectedDevice,
           let uuid = UUID(uuidString: savedDevice.id) {
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [uuid]) ?? []
            if let peripheral = peripherals.first {
                connectedPeripheral = peripheral
                peripheral.delegate = self
                centralManager?.connect(peripheral, options: nil)
                return
            }
        }

        ensureScanForReconnect()
    }

    private func ensureScanForReconnect() {
        guard isRadioPoweredOn else {
            deferredScan = true
            return
        }
        if activeScanSessions == 0 {
            // No AllowDuplicates — reconnect only needs one discovery hit.
            centralManager?.scanForPeripherals(withServices: nil, options: Self.reconnectScanOptions)
        }
    }

    private func resumeScanAfterConnectionEvent() {
        guard activeScanSessions > 0, isRadioPoweredOn else { return }
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
            DeviceConsole.log(.ble, "connectToDevice FAIL — bad uuid \(deviceId)")
            return
        }

        suppressAutoReconnect = false
        desiredReconnectId = uuid
        DeviceConsole.log(
            .ble,
            "connectToDevice uuid=\(deviceId) allowScan=\(allowDiscoveryScan) stored=\(storedPeripherals.contains(where: { $0.identifier == uuid })) connectedCount=\(connectedDevices.count)"
        )

        // Prefer a recently discovered peripheral (most reliable)
        if let peripheral = storedPeripherals.first(where: { $0.identifier == uuid }) {
            peripheral.delegate = self
            if peripheral.state != .connected {
                DeviceConsole.log(.ble, "connectToDevice — connect stored peripheral state=\(peripheral.state.rawValue)")
                centralManager?.connect(peripheral, options: nil)
            } else {
                DeviceConsole.log(.ble, "connectToDevice — already connected (stored)")
                connectedPeripheral = peripheral
                DispatchQueue.main.async { self.isConnected = true }
            }
            return
        }

        // Fallback to system cache
        if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
            peripheral.delegate = self
            if !storedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                storedPeripherals.append(peripheral)
            }
            if peripheral.state != .connected {
                DeviceConsole.log(.ble, "connectToDevice — connect retrieved peripheral state=\(peripheral.state.rawValue)")
                centralManager?.connect(peripheral, options: nil)
            } else {
                DeviceConsole.log(.ble, "connectToDevice — already connected (retrieved)")
                connectedPeripheral = peripheral
                DispatchQueue.main.async { self.isConnected = true }
            }
            return
        }

        guard allowDiscoveryScan else {
            DeviceConsole.log(.ble, "connectToDevice — not in cache and scan disallowed")
            return
        }

        // Final fallback: rescan until didDiscover auto-connects via desiredReconnectId.
        DeviceConsole.log(.ble, "connectToDevice — scanning to rediscover \(deviceId)")
        ensureScanForReconnect()
    }

    /// True when this peripheral UUID was seen advertising within `seconds`.
    /// Powered-off boards do not advertise — do not treat cache/GATT alone as online.
    func hasRecentAdvertisement(forPeripheralUUID uuidString: String, within seconds: TimeInterval = 12) -> Bool {
        let fromPrivate = advertisementSeenAt.first { $0.key.caseInsensitiveCompare(uuidString) == .orderedSame }?.value
        let fromPublished = bleLastSeen.first { $0.key.caseInsensitiveCompare(uuidString) == .orderedSame }?.value
        guard let seenAt = fromPrivate ?? fromPublished else { return false }
        return Date().timeIntervalSince(seenAt) <= seconds
    }

    /// Live link to this hub — connected peripherals often stop advertising.
    /// Checks the per-UUID map so one connected hub does not hide another.
    func isLiveConnected(forPeripheralUUID uuidString: String) -> Bool {
        if let entry = connectedEntry(forPeripheralUUID: uuidString),
           entry.peripheral.state == .connected {
            return true
        }
        if let connected = connectedPeripheral,
           connected.identifier.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame {
            return connected.state == .connected
        }
        if let match = storedPeripherals.first(where: {
            $0.identifier.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame
        }) {
            return match.state == .connected
        }
        return false
    }

    func connectedEntry(forPeripheralUUID uuidString: String) -> (peripheral: CBPeripheral, characteristic: CBCharacteristic)? {
        if let uuid = UUID(uuidString: uuidString), let entry = connectedDevices[uuid] {
            return entry
        }
        return connectedDevices.first {
            $0.key.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame
        }?.value
    }

    func recordAdvertisementSeen(uuid: String) {
        let now = Date()
        advertisementSeenAt[uuid] = now
        if now.timeIntervalSince(lastBleLastSeenPublishAt) >= 0.4 {
            lastBleLastSeenPublishAt = now
            bleLastSeen = advertisementSeenAt
        }
    }

    /// Stop orphan reconnect scanning after a timed-out ensureConnected attempt.
    func clearReconnectTargetAndStopOrphanScan() {
        desiredReconnectId = nil
        stopCentralScanIfIdle()
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
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
        
        if characteristic.uuid == CBUUID(string: "FF02") {
            let bytes = [UInt8](data)  // Convert Data to byte array
            
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
                let ssids: [String] = Self.parseSSIDArrayString(text)
                if !ssids.isEmpty {
                } else {
                }
                DispatchQueue.main.async { [weak self] in
                    self?.wifiListCompletion?(ssids)
                    self?.wifiListCompletion = nil
                    self?.wifiListReadToken = nil
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.wifiListCompletion?([])
                    self?.wifiListCompletion = nil
                    self?.wifiListReadToken = nil
                }
            }
            return
        }
    }
    /// Disconnect only this hub. Other live BLE links stay up.
    /// Drop cached FB01 characteristics (must run when switching BLE hubs during master provisioning).
    func clearProvisioningCharacteristics() {
        fbSSIDCharacteristic = nil
        fbPasswordCharacteristic = nil
        fbWifiListCharacteristic = nil
        fb05Characteristic = nil
        fbAckCharacteristic = nil
        for pending in pendingWritesByUUID.values {
            pending.timeoutWork?.cancel()
        }
        pendingWritesByUUID.removeAll()
    }

    /// FB02/FB03 must belong to the currently connected peripheral — stale refs hang writes.
    func provisioningCharacteristicsReady(for peripheral: CBPeripheral) -> Bool {
        guard let ssidChar = fbSSIDCharacteristic,
              let passChar = fbPasswordCharacteristic else {
            return false
        }
        let peripheralId = peripheral.identifier
        return ssidChar.service?.peripheral?.identifier == peripheralId
            && passChar.service?.peripheral?.identifier == peripheralId
    }

    /// Wait until FB02 + FB03 are discovered on the target peripheral.
    @MainActor
    func waitForProvisioningReady(peripheralUUID: String, timeout: TimeInterval = 25) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var didRequestDiscovery = false

        while Date() < deadline {
            guard let peripheral = connectedPeripheral,
                  peripheral.identifier.uuidString.caseInsensitiveCompare(peripheralUUID) == .orderedSame,
                  peripheral.state == .connected else {
                try? await Task.sleep(nanoseconds: 200_000_000)
                continue
            }

            if provisioningCharacteristicsReady(for: peripheral) {
                DeviceConsole.log(.ble, "provisioning ready uuid=\(peripheralUUID)")
                return true
            }

            if !didRequestDiscovery {
                didRequestDiscovery = true
                DeviceConsole.log(.ble, "provisioning — discovering FB01 on uuid=\(peripheralUUID)")
                clearProvisioningCharacteristics()
                peripheral.discoverServices([FB01])
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        DeviceConsole.log(.ble, "provisioning ready TIMEOUT uuid=\(peripheralUUID)")
        return false
    }

    func disconnectPeripheral(uuidString: String, suppressReconnect: Bool = false) {
        guard let uuid = UUID(uuidString: uuidString) else { return }
        if suppressReconnect {
            suppressAutoReconnect = true
            if desiredReconnectId == uuid {
                desiredReconnectId = nil
            }
        }
        let peripheral = connectedDevices[uuid]?.peripheral
            ?? storedPeripherals.first(where: { $0.identifier == uuid })
            ?? (connectedPeripheral?.identifier == uuid ? connectedPeripheral : nil)
        guard let peripheral else {
            if suppressReconnect { suppressAutoReconnect = false }
            return
        }
        centralManager?.cancelPeripheralConnection(peripheral)
    }

    /// - Parameter suppressReconnect: Set true when disconnecting on purpose (cloud restored)
    ///   so `didDisconnect` does not immediately reconnect and fight MQTT.
    func disconnectCurrentDevice(suppressReconnect: Bool = false) {
        if let current = connectedPeripheral {
            disconnectPeripheral(
                uuidString: current.identifier.uuidString,
                suppressReconnect: suppressReconnect
            )
            return
        }
        if suppressReconnect {
            suppressAutoReconnect = false
        }
    }
    func stopScanning() {
        activeScanSessions = max(0, activeScanSessions - 1)
        stopCentralScanIfIdle()
    }

    func stopCentralScanIfIdle() {
        guard activeScanSessions == 0 else { return }
        guard isRadioPoweredOn else { return }
        centralManager?.stopScan()
    }
}
