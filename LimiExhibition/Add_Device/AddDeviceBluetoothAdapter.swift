import SwiftUI
import Combine

protocol AddDeviceBluetoothControlling: ObservableObject {
    var isBluetoothOn: Bool { get }
    var isConnected: Bool { get }
    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void)
    func stopScanning()
    func connectToDevice(deviceId: String)
}

final class AddDeviceBluetoothAdapter: AddDeviceBluetoothControlling {
    @Published private(set) var isBluetoothOn = false
    @Published private(set) var isConnected = false

    private let manager: BluetoothManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BluetoothManager = .shared) {
        self.manager = manager
        self.isBluetoothOn = manager.isBluetoothOn
        self.isConnected = manager.isConnected

        manager.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isBluetoothOn = $0 }
            .store(in: &cancellables)

        manager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)
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
}
