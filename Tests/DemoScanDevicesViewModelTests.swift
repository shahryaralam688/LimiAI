//
//  DemoScanDevicesViewModelTests.swift
//  LimiTests
//

import XCTest
import Combine
@testable import LIMI_AI

final class DemoScanDevicesViewModelTests: XCTestCase {

    private final class MockBonjourBrowser: BonjourWiFiBrowsing, ObservableObject {
        let objectWillChange = ObservableObjectPublisher()
        @Published var discoveredWiFiDevices: [BLEDevice] = []

        func startBrowsing() {}
        func stopBrowsing() {}
        func removeCompletelyMatching(bleName: String, bleId: String) {}
    }

    private final class MockBLEController: DemoScanBluetoothControlling, ObservableObject {
        let objectWillChange = ObservableObjectPublisher()
        @Published private(set) var isBluetoothOn = true
        @Published private(set) var isConnected = false
        @Published private(set) var lastDisconnectedDeviceID: String?
        @Published private(set) var bleLastSeenById: [String: Date] = [:]

        func connectedBLEDevices() -> [BLEDevice] { [] }
        func isDeviceConnected(uuid: String) -> Bool { false }
        func startScanning(completion: @escaping ([BLEDevice]) -> Void) { completion([]) }
        func stopScanning() {}
        func selectAndConnect(name: String, uuidString: String) {}
        func readWifiList(completion: @escaping ([String]) -> Void) { completion([]) }
    }

    func testOrderedDevicesIncludesAllowedOnlineWiFi() {
        let bonjour = MockBonjourBrowser()
        bonjour.discoveredWiFiDevices = [
            BLEDevice(name: "1 CH-HUB", uuid: "wifi-1", deviceType: .wifi, reachability: .online),
            BLEDevice(name: "Other", uuid: "wifi-2", deviceType: .wifi, reachability: .online)
        ]

        let viewModel = DemoScanDevicesViewModel(
            ble: MockBLEController(),
            bonjour: bonjour,
            allowedNames: ["1 CH-HUB"]
        )

        viewModel.onAppear()

        XCTAssertEqual(viewModel.orderedDevices.count, 1)
        XCTAssertEqual(viewModel.orderedDevices.first?.name, "1 CH-HUB")
        XCTAssertTrue(viewModel.shouldShowContinue)
    }

    func testConnectBLEDeviceSetsConnectingState() {
        let viewModel = DemoScanDevicesViewModel(ble: MockBLEController(), bonjour: MockBonjourBrowser())

        viewModel.connectBLEDevice(name: "Mini Controller", id: "ble-99")

        XCTAssertTrue(viewModel.isConnectingToBLE)
        XCTAssertEqual(viewModel.selectedName, "Mini Controller")
        XCTAssertEqual(viewModel.selectedId, "ble-99")
    }
}
