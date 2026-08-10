import SwiftUI
import Combine

protocol DemoScanBluetoothControlling: ObservableObject {
    var isBluetoothOn: Bool { get }
    var isConnected: Bool { get }
    var lastDisconnectedDeviceID: String? { get }
    var bleLastSeenById: [String: Date] { get }
    func connectedBLEDevices() -> [BLEDevice]
    func isDeviceConnected(uuid: String) -> Bool
    func startScanning(completion: @escaping ([BLEDevice]) -> Void)
    func stopScanning()
    func selectAndConnect(name: String, uuidString: String)
    func readWifiList(completion: @escaping ([String]) -> Void)
    func refreshScan()
}

final class DemoScanBluetoothAdapter: DemoScanBluetoothControlling {
    @Published private(set) var isBluetoothOn = false
    @Published private(set) var isConnected = false
    @Published private(set) var lastDisconnectedDeviceID: String?
    @Published private(set) var bleLastSeenById: [String: Date] = [:]

    private let manager: BluetoothManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BluetoothManager = .shared) {
        self.manager = manager
        self.isBluetoothOn = manager.isBluetoothOn
        self.isConnected = manager.isConnected
        self.lastDisconnectedDeviceID = manager.lastDisconnectedDeviceID
        self.bleLastSeenById = manager.bleLastSeen

        manager.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isBluetoothOn = $0 }
            .store(in: &cancellables)

        manager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)

        manager.$lastDisconnectedDeviceID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastDisconnectedDeviceID = $0 }
            .store(in: &cancellables)

        manager.$bleLastSeen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.bleLastSeenById = $0 }
            .store(in: &cancellables)
    }

    func connectedBLEDevices() -> [BLEDevice] {
        manager.connectedDevices.compactMap { uuid, tuple in
            guard tuple.peripheral.state == .connected else { return nil }
            return BLEDevice(
                name: tuple.peripheral.name ?? "Unknown Device",
                uuid: uuid.uuidString,
                deviceType: .bluetooth,
                reachability: .online,
                lastSeen: Date()
            )
        }
    }

    func isDeviceConnected(uuid: String) -> Bool {
        guard let id = UUID(uuidString: uuid) else { return false }
        return manager.connectedDevices[id]?.peripheral.state == .connected
    }

    func startScanning(completion: @escaping ([BLEDevice]) -> Void) {
        manager.startScanning { devices in
            let mapped = devices.map {
                BLEDevice(name: $0.name, uuid: $0.id, deviceType: .bluetooth, reachability: .online, lastSeen: Date())
            }
            completion(mapped)
        }
    }

    func stopScanning() {
        manager.stopScanning()
    }

    func selectAndConnect(name: String, uuidString: String) {
        manager.selectAndConnect(name: name, uuidString: uuidString)
    }

    func readWifiList(completion: @escaping ([String]) -> Void) {
        manager.readWifiList(completion: completion)
    }

    func refreshScan() {
        manager.refreshScan()
    }
}
