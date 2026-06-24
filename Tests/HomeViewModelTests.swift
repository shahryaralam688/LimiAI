//
//  HomeViewModelTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class HomeViewModelTests: XCTestCase {

    private final class MockDeviceAllocator: HomeDeviceAllocating {
        private(set) var allocatedDeviceIds: [String] = []

        func allocateDevice(deviceId: String) {
            allocatedDeviceIds.append(deviceId)
        }
    }

    private final class MockLocationProvider: HomeLocationProviding {
        var address: String?

        func currentAddress() -> String? { address }
    }

    private final class MockDeviceService: DeviceServiceProtocol {
        func fetchLinkedDevices(completion: @escaping (Result<[DeviceHome], Error>) -> Void) {
            completion(.success([]))
        }
    }

    func testHandleDiscoveredBLEDevicesSetsPendingForAllowedName() {
        let viewModel = HomeViewModel(deviceService: MockDeviceService())
        let allowed: Set<String> = ["1 ch-hub"]

        viewModel.handleDiscoveredBLEDevices(
            [("1 CH-HUB", "ble-001")],
            allowedNames: allowed
        )

        XCTAssertEqual(viewModel.pendingBLEDevice, PendingBLEDevice(name: "1 CH-HUB", id: "ble-001"))
    }

    func testAcceptPendingBLEDeviceStoresSelectionAndClearsPending() {
        let viewModel = HomeViewModel(deviceService: MockDeviceService())
        viewModel.pendingBLEDevice = PendingBLEDevice(name: "Mini Controller", id: "ble-002")

        let accepted = viewModel.acceptPendingBLEDevice()

        XCTAssertEqual(accepted, PendingBLEDevice(name: "Mini Controller", id: "ble-002"))
        XCTAssertNil(viewModel.pendingBLEDevice)
        XCTAssertEqual(viewModel.selectedDeviceName, "Mini Controller")
        XCTAssertEqual(viewModel.selectedDeviceId, "ble-002")
    }

    func testRejectPendingBLEDevicePreventsResurface() {
        let viewModel = HomeViewModel(deviceService: MockDeviceService())
        viewModel.pendingBLEDevice = PendingBLEDevice(name: "4 CH-HUB", id: "ble-003")

        viewModel.rejectPendingBLEDevice()
        viewModel.handleDiscoveredBLEDevices(
            [("4 CH-HUB", "ble-003")],
            allowedNames: ["4 ch-hub"]
        )

        XCTAssertNil(viewModel.pendingBLEDevice)
    }

    func testPresentSetsActiveRoute() {
        let viewModel = HomeViewModel(deviceService: MockDeviceService())

        viewModel.present(.voice)

        XCTAssertEqual(viewModel.activeRoute, .voice)
    }

    func testFetchLinkedDevicesPopulatesListOnSuccess() {
        final class SuccessDeviceService: DeviceServiceProtocol {
            func fetchLinkedDevices(completion: @escaping (Result<[DeviceHome], Error>) -> Void) {
                completion(.success([
                    DeviceHome(id: "1", name: "Kitchen Hub", deviceID: "dev-1", isOn: true)
                ]))
            }
        }

        let viewModel = HomeViewModel(deviceService: SuccessDeviceService())
        let expectation = expectation(description: "devices loaded")

        viewModel.fetchLinkedDevices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(viewModel.linkedDevices.count, 1)
            XCTAssertEqual(viewModel.linkedDevices.first?.name, "Kitchen Hub")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testProcessBonjourWiFiDevicesAllocatesOnlineDeviceOnce() {
        let allocator = MockDeviceAllocator()
        let viewModel = HomeViewModel(
            deviceService: MockDeviceService(),
            deviceAllocator: allocator
        )

        let device = BLEDevice(
            name: "1 CH-HUB",
            uuid: "wifi-uuid-1",
            deviceType: .wifi,
            txtRecord: ["deviceId": "dev-100", "channelCount": "1"],
            reachability: .online
        )

        viewModel.processBonjourWiFiDevices([device], allowedNames: ["1 ch-hub"])
        viewModel.processBonjourWiFiDevices([device], allowedNames: ["1 ch-hub"])

        XCTAssertEqual(allocator.allocatedDeviceIds, ["dev-100"])
        XCTAssertEqual(viewModel.wifiDevices.count, 1)
        XCTAssertEqual(viewModel.wifiDevices.first?.deviceName, "1 CH-HUB")
    }
}
