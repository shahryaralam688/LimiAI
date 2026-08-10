//
//  VoicePendantBluetoothViewModel.swift
//  Limi
//
//  Drives the separate Bluetooth setup flow for Voice Pendants:
//    scan → (tap) → connect → read Wi-Fi list → pick SSID + password →
//    provision over BLE → success.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class VoicePendantBluetoothViewModel: ObservableObject {

    enum Step: Equatable {
        case scanning
        case connecting
        case wifiList
        case password(ssid: String)
        case provisioning(ssid: String)
        case success(ssid: String)
    }

    @Published private(set) var step: Step = .scanning

    /// Bluetooth devices currently visible (live; refreshed by the scanner).
    @Published private(set) var devices: [(name: String, id: String)] = []
    @Published private(set) var selectedDevice: (name: String, id: String)?

    @Published private(set) var wifiNetworks: [String] = []
    @Published private(set) var isLoadingWifi = false

    @Published var passwordInput: String = ""
    @Published var errorMessage: String?

    var isBluetoothOn: Bool { adapter.isBluetoothOn }
    var connectedDeviceName: String? { adapter.connectedDeviceName }

    private let adapter: any VoicePendantBluetoothControlling
    private var cancellables: Set<AnyCancellable> = []
    private var hasConnectedOnce = false

    init(adapter: any VoicePendantBluetoothControlling = VoicePendantBluetoothAdapter()) {
        self.adapter = adapter
        observeConnection()
    }

    // MARK: - Observation

    private func observeConnection() {
        // Bridge the adapter's @Published isConnected into our step machine.
        if let concrete = adapter as? VoicePendantBluetoothAdapter {
            concrete.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    self?.handleConnectionChange(connected)
                }
                .store(in: &cancellables)
        }
    }

    private func handleConnectionChange(_ connected: Bool) {
        guard connected, !hasConnectedOnce else { return }
        // Only advance if we initiated a connection.
        guard step == .connecting else { return }
        hasConnectedOnce = true
        step = .wifiList
        loadWifiList()
    }

    // MARK: - Scanning

    func startScan() {
        guard isBluetoothOn else {
            errorMessage = "Turn on Bluetooth to find your pendant."
            return
        }
        step = .scanning
        adapter.startScanning { [weak self] found in
            DispatchQueue.main.async {
                self?.devices = found
            }
        }
    }

    func stopScan() {
        adapter.stopScanning()
    }

    // MARK: - Connect

    func select(_ device: (name: String, id: String)) {
        guard step == .scanning else { return }
        selectedDevice = device
        adapter.stopScanning()
        hasConnectedOnce = false
        step = .connecting
        adapter.connect(name: device.name, id: device.id)

        // Fallback timeout in case the connection callback never flips.
        Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            await MainActor.run {
                if self.step == .connecting {
                    self.errorMessage = "Couldn't connect. Make sure the pendant is in range and try again."
                    self.step = .scanning
                    self.startScan()
                }
            }
        }
    }

    // MARK: - Wi-Fi

    func loadWifiList() {
        isLoadingWifi = true
        adapter.readWifiList { [weak self] list in
            DispatchQueue.main.async {
                self?.isLoadingWifi = false
                self?.wifiNetworks = list
            }
        }
    }

    func selectNetwork(_ ssid: String) {
        passwordInput = ""
        step = .password(ssid: ssid)
    }

    // MARK: - Provision

    func provision() {
        guard case .password(let ssid) = step else { return }
        guard let device = selectedDevice else { return }
        let password = passwordInput
        step = .provisioning(ssid: ssid)

        WiFiProvisioningCoordinator.shared.provisionAndVerify(
            deviceName: device.name,
            bleDeviceId: device.id,
            ssid: ssid,
            password: password,
            onPhaseUpdate: { _ in },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.step = .success(ssid: ssid)
                case .failure(let failure):
                    self.errorMessage = failure.userMessage
                    self.step = .password(ssid: ssid)
                }
            }
        )
    }

    // MARK: - Navigation helpers

    func backToScan() {
        hasConnectedOnce = false
        selectedDevice = nil
        wifiNetworks = []
        step = .scanning
        startScan()
    }

    func backToWifiList() {
        step = .wifiList
    }

    func finish() {
        adapter.stopScanning()
    }
}
