//
//  VoicePendantBluetoothAdapter.swift
//  Limi
//
//  Bluetooth configuration bridge for the Voice Pendant module.
//
//  This is the SAME real provisioning path used to configure Limi devices
//  (scan → connect → read Wi-Fi list → write SSID/password over BLE), wrapped
//  here so the pendant setup flow stays self-contained. It does not modify any
//  existing Bluetooth code — it only talks to the shared `BluetoothManager`.
//

import Foundation
import Combine

protocol VoicePendantBluetoothControlling: ObservableObject {
    var isBluetoothOn: Bool { get }
    var isConnected: Bool { get }
    var connectedDeviceName: String? { get }

    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void)
    func stopScanning()
    func connect(name: String, id: String)
    func readWifiList(completion: @escaping ([String]) -> Void)
    func provisionWifi(ssid: String, password: String, completion: @escaping ((status: String, message: String)) -> Void)
    func disconnect()
}

final class VoicePendantBluetoothAdapter: VoicePendantBluetoothControlling {
    @Published private(set) var isBluetoothOn = false
    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceName: String?

    private let manager: BluetoothManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BluetoothManager = .shared) {
        self.manager = manager
        self.isBluetoothOn = manager.isBluetoothOn
        self.isConnected = manager.isConnected
        self.connectedDeviceName = manager.connectedDeviceName

        manager.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isBluetoothOn = $0 }
            .store(in: &cancellables)

        manager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)

        manager.$connectedDeviceName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.connectedDeviceName = $0 }
            .store(in: &cancellables)
    }

    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void) {
        manager.startScanning(completion: completion)
    }

    func stopScanning() {
        manager.stopScanning()
    }

    func connect(name: String, id: String) {
        manager.selectAndConnect(name: name, uuidString: id)
    }

    func readWifiList(completion: @escaping ([String]) -> Void) {
        manager.readWifiList(completion: completion)
    }

    func provisionWifi(ssid: String, password: String, completion: @escaping ((status: String, message: String)) -> Void) {
        manager.provisionWifi(ssid: ssid, password: password, completion: completion)
    }

    func disconnect() {
        manager.disconnectCurrentDevice()
    }
}
