import SwiftUI
import Combine
import CoreBluetooth

protocol HotelRoomBluetoothControlling: ObservableObject {
    var isBluetoothOn: Bool { get }
    var isConnected: Bool { get }
    var connectedDeviceItems: [DeviceItem] { get }
    func connectedEntry(for uuid: UUID) -> (peripheral: CBPeripheral, characteristic: CBCharacteristic)?
    func deviceUUID(matchingTitle title: String) -> UUID?
    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void)
    func stopScanning()
    func connectToDevice(deviceId: String)
    func sendBLEMessage(_ message: String)
}

final class HotelRoomBluetoothAdapter: HotelRoomBluetoothControlling {
    @Published private(set) var isBluetoothOn = false
    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceItems: [DeviceItem] = []

    private let manager: BluetoothManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BluetoothManager = .shared) {
        self.manager = manager
        self.isBluetoothOn = manager.isBluetoothOn
        self.isConnected = manager.isConnected
        self.connectedDeviceItems = Self.makeItems(from: manager.connectedDevices)

        manager.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isBluetoothOn = $0 }
            .store(in: &cancellables)

        manager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)

        manager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.connectedDeviceItems = Self.makeItems(from: devices)
            }
            .store(in: &cancellables)
    }

    func connectedEntry(for uuid: UUID) -> (peripheral: CBPeripheral, characteristic: CBCharacteristic)? {
        manager.connectedDevices[uuid]
    }

    func deviceUUID(matchingTitle title: String) -> UUID? {
        manager.connectedDevices.first { _, entry in
            (entry.peripheral.name ?? "Unnamed Device") == title
        }?.key
    }

    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void) {
        manager.startScanning(completion: completion)
    }

    func stopScanning() {
        manager.stopScanning()
    }

    func connectToDevice(deviceId: String) {
        manager.connectToDevice(deviceId: deviceId)
    }

    func sendBLEMessage(_ message: String) {
        manager.BLESend(message: message)
    }

    private static func makeItems(
        from devices: [UUID: (peripheral: CBPeripheral, characteristic: CBCharacteristic)]
    ) -> [DeviceItem] {
        devices.compactMap { _, entry in
            let title = entry.peripheral.name ?? "Unnamed Device"
            return DeviceItem(
                icon: "antenna.radiowaves.left.and.right",
                title: title,
                deviceCount: 1,
                isOn: false
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
