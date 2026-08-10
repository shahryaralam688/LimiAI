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
        @Published var isConnected = false
        @Published private(set) var lastDisconnectedDeviceID: String?
        @Published private(set) var bleLastSeenById: [String: Date] = [:]

        var connectedUUIDs = Set<String>()
        var wifiListResult: [String] = []

        func connectedBLEDevices() -> [BLEDevice] { [] }
        func isDeviceConnected(uuid: String) -> Bool { connectedUUIDs.contains(uuid) }
        func startScanning(completion: @escaping ([BLEDevice]) -> Void) { completion([]) }
        func stopScanning() {}
        func refreshScan() {}
        func selectAndConnect(name: String, uuidString: String) {}
        func readWifiList(completion: @escaping ([String]) -> Void) { completion(wifiListResult) }
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

    func testConnectAlreadyPairedBLEDeviceLoadsWifiListWithoutReconnect() {
        let ble = MockBLEController()
        ble.connectedUUIDs = ["ble-99"]
        ble.isConnected = true
        ble.wifiListResult = ["HomeWiFi", "OfficeWiFi"]

        let viewModel = DemoScanDevicesViewModel(ble: ble, bonjour: MockBonjourBrowser())
        viewModel.connectBLEDevice(name: "Mini Controller", id: "ble-99")

        let expectation = expectation(description: "Wi-Fi list loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(viewModel.isConnectingToBLE)
            XCTAssertEqual(viewModel.ssidNameArray, ["HomeWiFi", "OfficeWiFi"])
            XCTAssertTrue(viewModel.wifiProvisioningRequested)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
