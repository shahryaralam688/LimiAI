import Foundation
import SwiftUI

@MainActor
final class HotelRoomDevicesViewModel: ObservableObject {
    @Published var didStartBLE = false
    @Published var showWLEDView = false
    @Published var showWLEDDiscovery = false
    @Published var showPWMView = false
    @Published var showDataRGB = false
    @Published var showMiniController = false
    @Published var selectedHub: Hub?

    var connectedDeviceItems: [DeviceItem] {
        BluetoothManager.shared.connectedDevices
            .compactMap { _, entry in
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

    func presentWLEDDiscovery() {
        showWLEDDiscovery = true
    }

    func handleDeviceCardTap(_ item: DeviceItem, bluetoothManager: BluetoothManager, sharedDevice: SharedDevice) {
        let matchingDevice = bluetoothManager.connectedDevices.first { _, deviceEntry in
            let deviceName = deviceEntry.peripheral.name ?? "Unnamed Device"
            return deviceName == item.title
        }

        guard let match = matchingDevice else {
            print("❌ No matching connected device found for: \(item.title)")
            return
        }

        sharedDevice.connectedDevice = DeviceInfo(
            name: item.title,
            id: match.key.uuidString
        )

        handleDeviceSelection(for: match.key, bluetoothManager: bluetoothManager, sharedDevice: sharedDevice)
    }

    func handleBluetoothStateChanged(isOn: Bool, bluetoothManager: BluetoothManager) {
        guard isOn, !didStartBLE else { return }
        didStartBLE = true

        bluetoothManager.startScanning { devices in
            if let found = devices.first(where: { $0.name == "1 CH-HUB" }) {
                print("🔍 Found newHub, attempting to connect...")
                bluetoothManager.connectToDevice(deviceId: found.id)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if bluetoothManager.isConnected {
                        bluetoothManager.BLESend(message: "Connected device")
                    }
                }
                bluetoothManager.stopScanning()
            }
        }
    }

    private func handleDeviceSelection(for deviceUUID: UUID, bluetoothManager: BluetoothManager, sharedDevice: SharedDevice) {
        guard let deviceEntry = bluetoothManager.connectedDevices[deviceUUID] else {
            print("❌ Device not found in connected devices")
            return
        }

        selectedHub = Hub(peripheral: deviceEntry.peripheral)

        let rawBytes = sharedDevice.lastReceivedBytes

        if !rawBytes.isEmpty, let firstByte = rawBytes.first {
            print("📥 Device byte data: [\(firstByte)]")

            switch firstByte {
            case 1:
                print("🔀 Routing to PWM2LEDView")
                showPWMView = true
            case 2:
                print("🔀 Routing to DataRGB")
                showDataRGB = true
            case 3:
                print("🔀 Routing to MiniController")
                showMiniController = true
            default:
                print("🔀 Unknown byte value [\(firstByte)], defaulting to WLEDView")
                showWLEDView = true
            }
        } else {
            print("⚠️ No raw byte data available, defaulting to WLEDView")
            showWLEDView = true
        }
    }
}
