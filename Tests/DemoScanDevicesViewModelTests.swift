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

    func testOrderedDevicesIncludesLIMIDeviceNumberedSuffix() {
        let bonjour = MockBonjourBrowser()
        bonjour.discoveredWiFiDevices = [
            BLEDevice(
                name: "LIMI Device",
                uuid: "wifi-1",
                deviceType: .wifi,
                ipAddress: "192.168.18.109",
                txtRecord: ["deviceId": "limi1ch-80B54ECCA7F4"],
                reachability: .online
            ),
            BLEDevice(
                name: "LIMI Device-2",
                uuid: "wifi-2",
                deviceType: .wifi,
                ipAddress: "192.168.18.217",
                txtRecord: ["deviceId": "limi1ch-80B54EC1C270"],
                reachability: .online
            )
        ]

        let viewModel = DemoScanDevicesViewModel(
            ble: MockBLEController(),
            bonjour: bonjour
        )
        viewModel.onAppear()

        let names = Set(viewModel.orderedDevices.map(\.name))
        XCTAssertEqual(viewModel.orderedDevices.count, 2)
        XCTAssertTrue(names.contains("LIMI Device"))
        XCTAssertTrue(names.contains("LIMI Device-2"))
    }

    func testDedupeWifiCollapsesSameIPRenameGhost() {
        let devices = [
            BLEDevice(
                name: "LIMI Device",
                uuid: "LIMI Device|192.168.18.109",
                deviceType: .wifi,
                ipAddress: "192.168.18.109",
                txtRecord: ["deviceId": "limi1ch-80B54ECCA7F4"],
                reachability: .online,
                lastSeen: Date().addingTimeInterval(-10)
            ),
            BLEDevice(
                name: "LIMI Device",
                uuid: "LIMI Device|192.168.18.217",
                deviceType: .wifi,
                ipAddress: "192.168.18.217",
                txtRecord: ["deviceId": "limi1ch-80B54EC1C270"],
                reachability: .online,
                lastSeen: Date().addingTimeInterval(-5)
            ),
            BLEDevice(
                name: "LIMI Device-2",
                uuid: "LIMI Device-2|192.168.18.217",
                deviceType: .wifi,
                ipAddress: "192.168.18.217",
                txtRecord: ["deviceId": "limi1ch-80B54EC1C270"],
                reachability: .online,
                lastSeen: Date()
            )
        ]

        let deduped = DemoScanDevicesViewModel.dedupeWifiByHardwareOrIP(devices)
        XCTAssertEqual(deduped.count, 2)
        let ips = Set(deduped.compactMap(\.ipAddress))
        XCTAssertEqual(ips, ["192.168.18.109", "192.168.18.217"])
        XCTAssertTrue(deduped.contains { $0.name == "LIMI Device-2" && $0.ipAddress == "192.168.18.217" })
        XCTAssertFalse(deduped.contains { $0.name == "LIMI Device" && $0.ipAddress == "192.168.18.217" })
    }

    func testWifiExcludesGhostWithoutMQTTWhenBLEHubAdvertising() {
        let liveId = "80B54ECCA7F4"
        let ghostId = "80B54EC1C270"
        DeviceTransportRegistry.shared.state(for: liveId).updateMQTTPresence(connected: true)
        DeviceTransportRegistry.shared.state(for: ghostId).updateMQTTPresence(connected: false)

        let wifi = [
            BLEDevice(
                name: "LIMI Device",
                uuid: liveId,
                deviceType: .wifi,
                ipAddress: "192.168.18.109",
                txtRecord: ["deviceId": "limi1ch-\(liveId)"],
                reachability: .online
            ),
            BLEDevice(
                name: "LIMI Device-2",
                uuid: ghostId,
                deviceType: .wifi,
                ipAddress: "192.168.18.217",
                txtRecord: ["deviceId": "limi1ch-\(ghostId)"],
                reachability: .online
            )
        ]
        let ble = BLEDevice(
            name: "1 CH-HUB",
            uuid: "BLE-UUID-RESET",
            deviceType: .bluetooth,
            reachability: .online
        )

        let kept = DemoScanDevicesViewModel.wifiDevicesExcludingBLEDuplicates(
            wifiDevices: wifi,
            bleDevices: [ble],
            cloudConnected: true
        )

        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.name, "LIMI Device")
        XCTAssertEqual(kept.first?.ipAddress, "192.168.18.109")

        DeviceTransportRegistry.shared.forgetDevice(deviceId: liveId)
        DeviceTransportRegistry.shared.forgetDevice(deviceId: ghostId)
    }

    func testApplyVirtualMasterHidesMembersAndShowsMasterRow() {
        let macA = "80B54ECCA7F4"
        let macB = "80B54EC1C270"
        DeviceTransportRegistry.shared.state(for: macA).updateMQTTPresence(connected: true)
        defer {
            DeviceTransportRegistry.shared.forgetDevice(deviceId: macA)
            DeviceTransportRegistry.shared.forgetDevice(deviceId: macB)
        }

        XCTAssertTrue(VirtualMasterPresence.isAnyMemberCloudOnline(memberHardwareIds: [macA, macB]))
        XCTAssertEqual(
            VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [macA, macB]),
            "Online · 1/2 hubs"
        )
    }

    func testApplyVirtualMasterScanGroupingHidesMembers() {
        let macA = "80B54ECCA7F4"
        let macB = "80B54EC1C270"
        let devices = [
            BLEDevice(
                name: "LIMI Device",
                uuid: macA,
                deviceType: .wifi,
                ipAddress: "192.168.18.109",
                txtRecord: ["deviceId": "limi1ch-\(macA)"],
                reachability: .online
            ),
            BLEDevice(
                name: "LIMI Device-2",
                uuid: macB,
                deviceType: .wifi,
                ipAddress: "192.168.18.217",
                txtRecord: ["deviceId": "limi1ch-\(macB)"],
                reachability: .online
            ),
        ]

        let grouped = VirtualDeviceScanGrouping.apply(
            devices: devices,
            enabledMemberHardwareIds: [macA, macB],
            virtualDeviceID: "vd-test-1"
        )

        XCTAssertEqual(grouped.count, 1)
        XCTAssertTrue(grouped.first?.isVirtualMaster == true)
        XCTAssertEqual(grouped.first?.name, "Master Device")
        XCTAssertEqual(grouped.first?.virtualMaster?.memberHardwareIds, [macA, macB])
        XCTAssertEqual(grouped.first?.reachability, .online)
    }

    func testApplyMultipleVirtualMasterGroupsOnHome() {
        let macA = "3CDC75FEBF48"
        let macB = "3CDC75FDF1C4"
        let macC = "3CDC75FDEC54"
        DeviceTransportRegistry.shared.state(for: macA).updateMQTTPresence(connected: true)
        DeviceTransportRegistry.shared.state(for: macC).updateMQTTPresence(connected: true)
        defer {
            for mac in [macA, macB, macC] {
                DeviceTransportRegistry.shared.forgetDevice(deviceId: mac)
            }
        }

        let groupOne = VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [macA, macB])
        let groupTwo = VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [macC])

        XCTAssertEqual(groupOne, "Online · 1/2 hubs")
        XCTAssertEqual(groupTwo, "Online · Cloud")
    }

    func testVirtualDeviceListEnvelopeDecodesArrayPayload() throws {
        let json = """
        {
            "success": true,
            "data": [
                {
                    "virtual_device_id": "vd-3f8a72c1",
                    "mac_addresses": ["3CDC75FEBF48", "3CDC75FDF1C4"]
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VirtualDeviceListEnvelope.self, from: json)
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data.count, 1)
        XCTAssertEqual(decoded.data.first?.virtual_device_id, "vd-3f8a72c1")
        XCTAssertEqual(decoded.data.first?.mac_addresses.count, 2)
    }

    func testVirtualDeviceAPIEnvelopeDecodesPostSuccessPayload() throws {
        let json = """
        {
          "success": true,
          "message": "Virtual device saved successfully",
          "data": {
            "virtual_device_id": "vd-123",
            "mac_addresses": [
              "AA:BB:CC:DD:EE:FF",
              "11:22:33:44:55:66"
            ]
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VirtualDeviceAPIEnvelope.self, from: json)
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.message, "Virtual device saved successfully")
        XCTAssertEqual(decoded.data?.virtual_device_id, "vd-123")
        XCTAssertEqual(decoded.data?.mac_addresses, ["AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66"])
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
