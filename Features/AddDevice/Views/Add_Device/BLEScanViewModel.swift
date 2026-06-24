import SwiftUI

final class BLEScanViewModel: ObservableObject {
    @Published var discovered: [(name: String, id: String)] = []
    @Published var isNavigating = false
    @Published var isScanning = false
    @Published var statusText = "Preparing Bluetooth..."

    func handleAppear(isBluetoothOn: Bool, startScan: () -> Void) {
        if isBluetoothOn {
            startScan()
        } else {
            statusText = "Waiting for Bluetooth to power on..."
        }
    }

    func handleDisappear(stopScan: () -> Void) {
        stopScan()
        isScanning = false
    }

    func handleBluetoothStateChanged(_ poweredOn: Bool, startScan: () -> Void) {
        if poweredOn {
            startScan()
        } else {
            statusText = "Bluetooth is off. Please enable it."
            isScanning = false
            discovered.removeAll()
        }
    }

    func handleConnectionChanged(_ connected: Bool) {
        if connected {
            isNavigating = true
        }
    }

    func handleDeviceSelection(
        _ device: (name: String, id: String),
        stopScan: () -> Void,
        connect: (String) -> Void
    ) {
        stopScan()
        isScanning = false
        statusText = "Connecting to \(device.name)..."
        connect(device.id)
    }

    func startScan(isBluetoothOn: Bool, scan: (@escaping ([(name: String, id: String)]) -> Void) -> Void) {
        guard isBluetoothOn else { return }
        statusText = "Scanning for BLE devices..."
        isScanning = true

        scan { [weak self] devices in
            DispatchQueue.main.async {
                self?.discovered = devices
                self?.statusText = devices.isEmpty ? "No devices found yet..." : "Tap a device to connect"
            }
        }
    }
}
