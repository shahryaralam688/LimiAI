import SwiftUI
import Combine

final class DemoScanDevicesViewModel: ObservableObject {
    @Published private(set) var scannedDevices: [BLEDevice] = []
    @Published private(set) var orderedDevices: [BLEDevice] = []
    @Published private(set) var shouldShowContinue = false

    @Published var showAddWifi = false
    @Published var selectedName: String?
    @Published var selectedId: String?
    @Published var selectedChannelMac = ""
    @Published var isShowingPWM2LEDSheet = false
    @Published var isShowingRGBDataSheet = false
    @Published var showLiginSkip = false
    @Published var ssidNameArray: [String] = []
    @Published var isConnectingToBLE = false
    @Published private(set) var isBLEConnected = false
    @Published private(set) var lastDisconnectedBLEDeviceID: String?

    private let allowedNames: Set<String>
    private let ble: DemoScanBluetoothControlling
    private let bonjour: BonjourWiFiBrowsing
    private var bleMissedCycles: [String: Int] = [:]
    private var bleDisconnectedRecently = Set<String>()
    private var cancellables: Set<AnyCancellable> = []
    private var presenceTimer: AnyCancellable?

    private let bleCycleInterval: TimeInterval = 5.0
    private let bleGreyAfterCycles = 2
    private let bleRemoveAfterCycles = 3

    init(
        ble: DemoScanBluetoothControlling = DemoScanBluetoothAdapter(),
        bonjour: BonjourWiFiBrowsing = BonjourServiceBrowser.shared,
        allowedNames: Set<String> = [
            "limi1ch-EC3564", "1 CH-HUB", "4 CH-HUB", "8 CH-HUB",
            "16 CH-HUB", "Mini Controller", "LIMI Device"
        ]
    ) {
        self.ble = ble
        self.bonjour = bonjour
        self.allowedNames = allowedNames

        wireLiveObservers()

        $scannedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildDeviceList() }
            .store(in: &cancellables)
    }

    func onAppear() {
        ble.startScanning { [weak self] devices in
            DispatchQueue.main.async { self?.scannedDevices = devices }
        }
        bonjour.startBrowsing()
        presenceTimer = Timer.publish(every: bleCycleInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateBLEPresence() }
        rebuildDeviceList()
    }

    private func wireLiveObservers() {
        if let browser = bonjour as? BonjourServiceBrowser {
            browser.$discoveredWiFiDevices
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildDeviceList() }
                .store(in: &cancellables)
        }

        if let adapter = ble as? DemoScanBluetoothAdapter {
            adapter.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    guard let self else { return }
                    let wasConnected = self.isBLEConnected
                    self.isBLEConnected = connected
                    self.rebuildDeviceList()
                    if !wasConnected && connected && self.isConnectingToBLE {
                        self.handleBLEConnected()
                    }
                }
                .store(in: &cancellables)

            adapter.$lastDisconnectedDeviceID
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.lastDisconnectedBLEDeviceID = $0 }
                .store(in: &cancellables)

            adapter.$isBluetoothOn
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildDeviceList() }
                .store(in: &cancellables)
        }
    }

    func onDisappear() {
        ble.stopScanning()
        bonjour.stopBrowsing()
        presenceTimer?.cancel()
        presenceTimer = nil
    }

    func handleDisconnectedDeviceID(_ id: String?) {
        guard let id else { return }
        bleDisconnectedRecently.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.bleDisconnectedRecently.remove(id)
        }
    }

    func handleBLEConnected() {
        guard ble.isConnected, isConnectingToBLE else { return }
        ble.readWifiList { [weak self] list in
            DispatchQueue.main.async {
                guard let self else { return }
                self.ssidNameArray = list
                self.isConnectingToBLE = false
                self.showAddWifi = true
            }
        }
    }

    func connectBLEDevice(name: String, id: String) {
        selectedName = name
        selectedId = id
        ssidNameArray = []
        isConnectingToBLE = true
        bonjour.removeCompletelyMatching(bleName: name, bleId: id)
        ble.selectAndConnect(name: name, uuidString: id)
    }

    func connectWiFiDevice(_ device: BLEDevice) {
        guard device.reachability == .online else { return }
        if let txt = device.txtRecord,
           let channelCountStr = txt["channelCount"],
           let channelCount = Int(channelCountStr),
           let channelMac = txt["deviceId"] {
            if channelCount == 1 {
                selectedChannelMac = channelMac
                isShowingPWM2LEDSheet = true
            } else {
                selectedName = device.name
                selectedId = device.uuid
                isShowingRGBDataSheet = true
            }
        } else {
            selectedName = device.name
            selectedId = device.uuid
            showAddWifi = true
        }
    }

    func isDeviceConnected(_ device: BLEDevice) -> Bool {
        if device.deviceType == .bluetooth {
            return ble.isDeviceConnected(uuid: device.uuid)
        }
        return device.reachability == .online
    }

    func deviceOpacity(_ device: BLEDevice) -> Double {
        if device.deviceType == .wifi { return 1.0 }
        if ble.isDeviceConnected(uuid: device.uuid) { return 1.0 }
        return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles ? 0.4 : 1.0
    }

    func isDeviceDisabled(_ device: BLEDevice) -> Bool {
        if device.deviceType == .wifi { return device.reachability == .offline }
        if ble.isDeviceConnected(uuid: device.uuid) { return false }
        return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles
    }

    func shouldRender(_ device: BLEDevice) -> Bool {
        (device.deviceType == .bluetooth && ble.isBluetoothOn) || device.deviceType == .wifi
    }

    private func rebuildDeviceList() {
        let wifiDevices = bonjour.discoveredWiFiDevices
            .filter { allowedNames.contains($0.name) }
            .sorted { ($0.reachability == .online ? 0 : 1, $0.name) < ($1.reachability == .online ? 0 : 1, $1.name) }

        let connected = ble.connectedBLEDevices()
        let allBLEDevices = scannedDevices + connected
        let mergedBLEById = allBLEDevices.reduce(into: [String: BLEDevice]()) { dict, dev in
            dict[dev.uuid] = dev
        }
        let bleDevices = Array(mergedBLEById.values).filter { allowedNames.contains($0.name) }
        let bleFiltered = bleDevices.filter {
            ble.isDeviceConnected(uuid: $0.uuid) || ((bleMissedCycles[$0.uuid] ?? 0) < bleRemoveAfterCycles)
        }

        orderedDevices = wifiDevices + bleFiltered

        let hasAllowedBonjour = bonjour.discoveredWiFiDevices.contains {
            allowedNames.contains($0.name) && $0.reachability == .online
        }
        let hasAllowedConnectedBLE = ble.connectedBLEDevices().contains {
            allowedNames.contains($0.name)
        }
        shouldShowContinue = hasAllowedBonjour || hasAllowedConnectedBLE
    }

    private func updateBLEPresence() {
        let now = Date()
        var allIds = Set(scannedDevices.map(\.uuid))
        for device in ble.connectedBLEDevices() { allIds.insert(device.uuid) }
        for id in bleMissedCycles.keys { allIds.insert(id) }
        for id in ble.bleLastSeenById.keys { allIds.insert(id) }

        for id in allIds {
            if let last = ble.bleLastSeenById[id], now.timeIntervalSince(last) <= bleCycleInterval * 1.2 {
                bleMissedCycles[id] = 0
            } else {
                bleMissedCycles[id] = (bleMissedCycles[id] ?? 0) + 1
            }
        }
        rebuildDeviceList()
    }
}
