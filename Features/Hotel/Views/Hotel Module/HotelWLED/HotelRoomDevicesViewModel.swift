import Foundation
import SwiftUI
import Combine

@MainActor
final class HotelRoomDevicesViewModel: ObservableObject {
    @Published var didStartBLE = false
    @Published var showWLEDView = false
    @Published var showWLEDDiscovery = false
    @Published var showPWMView = false
    @Published var showDataRGB = false
    @Published var showMiniController = false
    @Published var selectedHub: Hub?
    @Published private(set) var isBluetoothOn = false

    private let bluetooth: HotelRoomBluetoothAdapter

    var connectedDeviceItems: [DeviceItem] {
        bluetooth.connectedDeviceItems
    }

    init(bluetooth: HotelRoomBluetoothAdapter = HotelRoomBluetoothAdapter()) {
        self.bluetooth = bluetooth
        self.isBluetoothOn = bluetooth.isBluetoothOn
        wireObservers()
    }

    private func wireObservers() {
        bluetooth.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .assign(to: &$isBluetoothOn)
    }

    func presentWLEDDiscovery() {
        showWLEDDiscovery = true
    }

    func handleDeviceCardTap(_ item: DeviceItem, sharedDevice: SharedDevice) {
        guard let uuid = bluetooth.deviceUUID(matchingTitle: item.title),
              let match = bluetooth.connectedEntry(for: uuid) else {
            print("❌ No matching connected device found for: \(item.title)")
            return
        }

        sharedDevice.connectedDevice = DeviceInfo(
            name: item.title,
            id: match.peripheral.identifier.uuidString
        )

        handleDeviceSelection(for: match.peripheral.identifier, sharedDevice: sharedDevice)
    }

    func handleBluetoothStateChanged(isOn: Bool) {
        guard isOn, !didStartBLE else { return }
        didStartBLE = true

        bluetooth.startScanning { [weak self] devices in
            if let found = devices.first(where: { $0.name == "1 CH-HUB" }) {
                print("🔍 Found newHub, attempting to connect...")
                self?.bluetooth.connectToDevice(deviceId: found.id)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self?.bluetooth.sendBLEMessage("Connected device")
                }
                self?.bluetooth.stopScanning()
            }
        }
    }

    private func handleDeviceSelection(for deviceUUID: UUID, sharedDevice: SharedDevice) {
        guard let deviceEntry = bluetooth.connectedEntry(for: deviceUUID) else {
            print("❌ Device not found in connected devices")
            return
        }

        selectedHub = Hub(peripheral: deviceEntry.peripheral)

        let rawBytes = sharedDevice.lastReceivedBytes

        if !rawBytes.isEmpty, let firstByte = rawBytes.first {
            switch firstByte {
            case 1:
                showPWMView = true
            case 2:
                showDataRGB = true
            case 3:
                showMiniController = true
            default:
                showWLEDView = true
            }
        } else {
            showWLEDView = true
        }
    }
}
