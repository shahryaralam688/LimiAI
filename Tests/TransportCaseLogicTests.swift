//
//  TransportCaseLogicTests.swift
//  LimiTests
//
//  Logic checks for Case 1/2/3 transport doors + ID / presence helpers.
//  (Does not hit live MQTT / Bonjour / BLE hardware.)
//

import XCTest
@testable import LIMI_AI

final class TransportCaseLogicTests: XCTestCase {

    // MARK: - Hardware ID normalize (Case 3 merge)

    func testNormalizedHardwareId_stripsLimiPrefix() {
        XCTAssertEqual(
            LimiDeviceNaming.normalizedHardwareId("LIMI1CH-80B54ECCA7F4"),
            "80B54ECCA7F4"
        )
    }

    func testNormalizedHardwareId_bareMacUppercased() {
        XCTAssertEqual(
            LimiDeviceNaming.normalizedHardwareId("80b54ecca7f4"),
            "80B54ECCA7F4"
        )
    }

    func testNormalizedHardwareId_matchesAcrossFormats() {
        let a = LimiDeviceNaming.normalizedHardwareId("LIMI1CH-80B54ECCA7F4")
        let b = LimiDeviceNaming.normalizedHardwareId("80B54ECCA7F4")
        XCTAssertEqual(a, b)
    }

    // MARK: - Presence parsing

    func testPresence_definiteOnlineStatuses() {
        for status in ["on", "online", "connected", "true", "1", "boot"] {
            XCTAssertTrue(LimiDeviceNaming.isDefinitePresenceStatus(status), status)
            XCTAssertTrue(LimiDeviceNaming.isOnlinePresenceStatus(status), status)
        }
    }

    func testPresence_definiteOfflineStatuses() {
        for status in ["off", "offline", "disconnected", "false", "0"] {
            XCTAssertTrue(LimiDeviceNaming.isDefinitePresenceStatus(status), status)
            XCTAssertFalse(LimiDeviceNaming.isOnlinePresenceStatus(status), status)
        }
    }

    func testPresence_ackOnlyIgnored() {
        XCTAssertFalse(LimiDeviceNaming.isDefinitePresenceStatus(""))
        XCTAssertFalse(LimiDeviceNaming.isDefinitePresenceStatus("ack"))
        XCTAssertFalse(LimiDeviceNaming.isDefinitePresenceStatus("ok"))
    }

    // MARK: - Door selection (Case 3 critical)

    func testDoor_case3_mqttOnly_noLocalWifi_usesMQTT() {
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateMQTTPresence(connected: true)
        // wifiConnected stays false — remote phone
        waitForMain()
        XCTAssertEqual(state.activeDoor, .mqtt)
        XCTAssertTrue(state.isAvailableForControl)
    }

    func testDoor_localWifi_noMQTT_withoutAllow_usesBLE() {
        LocalNetworkAllowStore.shared.resetForTests()
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        waitForMain()
        // MQTT miss + no Bonjour allow → BLE before WebSocket.
        XCTAssertEqual(state.activeDoor, .ble)
    }

    func testDoor_localWifi_noMQTT_withAllow_usesWebSocket() {
        LocalNetworkAllowStore.shared.resetForTests()
        LocalNetworkAllowStore.shared.allow("80B54ECCA7F4")
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        waitForMain()
        XCTAssertEqual(state.activeDoor, .webSocket)
        LocalNetworkAllowStore.shared.resetForTests()
    }

    func testDoor_mqttAndWifi_prefersMQTT() {
        LocalNetworkAllowStore.shared.resetForTests()
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        state.updateMQTTPresence(connected: true)
        waitForMain()
        XCTAssertEqual(state.activeDoor, .mqtt)
    }

    func testDoor_offline_fallsToBLE() {
        LocalNetworkAllowStore.shared.resetForTests()
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        waitForMain()
        XCTAssertEqual(state.activeDoor, .ble)
        XCTAssertFalse(state.isAvailableForControl)
    }

    func testDoor_cloudMemory_prefersCloudMQTTOverBLE() {
        let id = "80B54ECCA7F4"
        CloudPresenceMemory.shared.record(deviceId: id, connected: true)
        defer { CloudPresenceMemory.shared.remove(deviceId: id) }

        let state = DeviceTransportState(deviceId: id)
        waitForMain()
        XCTAssertEqual(state.activeDoor, .mqtt)
        XCTAssertTrue(state.isAvailableForControl)
    }

    func testDoor_provisionedHub_prefersCloudMQTTOverBLE() {
        let id = "80B54ECCA7F4"
        ConfiguredBLEDeviceStore.shared.remember(
            hardwareId: id,
            blePeripheralUUID: "AAAA-BBBB-CCCC",
            displayName: "LIMI Device-2"
        )
        defer { ConfiguredBLEDeviceStore.shared.remove(hardwareId: id) }

        LightControllingSocket.shared.connect()
        let state = DeviceTransportState(deviceId: id)
        waitForMain()
        XCTAssertEqual(state.activeDoor, .mqtt)
        XCTAssertTrue(state.isAvailableForControl)
    }

    func testBonjourOffline_doesNotClearMQTT_case3() {
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateMQTTPresence(connected: true)
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        state.updateBonjour(reachable: false, ip: nil)
        waitForMain()
        XCTAssertTrue(state.mqttConnected)
        XCTAssertFalse(state.wifiConnected)
        XCTAssertEqual(state.activeDoor, .mqtt)
    }

    func testMQTTPresenceUpdate_roundTrip() {
        let update = MQTTPresenceUpdate(deviceId: "limi1ch-80b54ecca7f4", connected: true)
        XCTAssertEqual(update.deviceId, "80B54ECCA7F4")
        XCTAssertTrue(update.connected)
    }

    // MARK: - Local delete (KAN-127)

    func testLocalDelete_clearsStoresAndTombstones() {
        // Must be 12 hex chars so LIMI1CH-… normalizes to the bare MAC.
        let id = "D0B54ECCA701"
        let prefixId = "LIMI1CH-\(id)"
        LocallyRemovedDeviceStore.shared.resetForTests()
        LocalNetworkAllowStore.shared.resetForTests()
        ConfiguredBLEDeviceStore.shared.remove(hardwareId: id)
        CloudPresenceMemory.shared.remove(deviceId: id)

        ConfiguredBLEDeviceStore.shared.remember(
            hardwareId: prefixId,
            blePeripheralUUID: "AAAA-BBBB-CCCC-DDDD",
            displayName: "Delete Test Hub"
        )
        CloudPresenceMemory.shared.record(deviceId: prefixId, connected: true)
        LocalNetworkAllowStore.shared.allow(prefixId)
        _ = DeviceTransportRegistry.shared.state(for: prefixId)

        XCTAssertEqual(LimiDeviceNaming.normalizedHardwareId(prefixId), id)
        XCTAssertTrue(ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: id))
        XCTAssertEqual(CloudPresenceMemory.shared.lastConnected(deviceId: id), true)
        XCTAssertTrue(LocalNetworkAllowStore.shared.isAllowed(for: id))

        LocallyRemovedDeviceStore.shared.markRemoved(prefixId)
        ConfiguredBLEDeviceStore.shared.remove(hardwareId: prefixId)
        CloudPresenceMemory.shared.remove(deviceId: prefixId)
        LocalNetworkAllowStore.shared.revoke(prefixId)
        DeviceTransportRegistry.shared.forgetDevice(deviceId: prefixId)

        XCTAssertTrue(LocallyRemovedDeviceStore.shared.contains(id))
        XCTAssertTrue(LocallyRemovedDeviceStore.shared.contains(prefixId))
        XCTAssertFalse(ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: id))
        XCTAssertNil(CloudPresenceMemory.shared.lastConnected(deviceId: id))
        XCTAssertFalse(LocalNetworkAllowStore.shared.isAllowed(for: id))
        XCTAssertFalse(
            DeviceTransportRegistry.shared.allStates.contains { $0.deviceId == id }
        )

        LocallyRemovedDeviceStore.shared.resetForTests()
        LocalNetworkAllowStore.shared.resetForTests()
    }

    func testLocalDelete_tombstoneClearsOnReadd() {
        let id = "D0B54ECCA702"
        LocallyRemovedDeviceStore.shared.resetForTests()
        LocallyRemovedDeviceStore.shared.markRemoved(id)
        XCTAssertTrue(LocallyRemovedDeviceStore.shared.contains(id))

        LocallyRemovedDeviceStore.shared.clearRemoved("LIMI1CH-\(id)")
        XCTAssertFalse(LocallyRemovedDeviceStore.shared.contains(id))

        LocallyRemovedDeviceStore.shared.resetForTests()
    }

    func testLocalDelete_seedPathsWouldSkipTombstonedId() {
        let id = "D0B54ECCA703"
        LocallyRemovedDeviceStore.shared.resetForTests()
        LocallyRemovedDeviceStore.shared.markRemoved(id)

        var seeded: [String] = []
        for candidate in [id, "D0B54ECCA799"] {
            if LocallyRemovedDeviceStore.shared.contains(candidate) { continue }
            seeded.append(candidate)
        }
        XCTAssertEqual(seeded, ["D0B54ECCA799"])

        LocallyRemovedDeviceStore.shared.resetForTests()
    }

    // MARK: - Add Device list dedupe

    func testAddDevice_wifiExcludesHardwareMatchedByBLE() {
        let id = "D0B54ECCA704"
        ConfiguredBLEDeviceStore.shared.remember(
            hardwareId: id,
            blePeripheralUUID: "BLE-PERIPH-UUID-1",
            displayName: "1 CH-HUB"
        )
        let wifi = BLEDevice(
            name: "LIMI Device",
            uuid: "LIMI Device|192.168.18.109",
            deviceType: .wifi,
            ipAddress: "192.168.18.109",
            txtRecord: ["deviceId": "limi1ch-\(id)"],
            reachability: .online,
            lastSeen: Date()
        )
        let ble = BLEDevice(
            name: "1 CH-HUB",
            uuid: "BLE-PERIPH-UUID-1",
            deviceType: .bluetooth,
            reachability: .online,
            lastSeen: Date()
        )
        let kept = DemoScanDevicesViewModel.wifiDevicesExcludingBLEDuplicates(
            wifiDevices: [wifi],
            bleDevices: [ble]
        )
        XCTAssertTrue(kept.isEmpty)
        ConfiguredBLEDeviceStore.shared.remove(hardwareId: id)
    }

    // MARK: - Home power memory

    func testDevicePowerMemoryStore_persistsOnOffPerHardwareId() {
        DevicePowerMemoryStore.shared.resetForTests()
        let id = "80B54ECCA7F4"
        XCTAssertNil(DevicePowerMemoryStore.shared.isOn(for: id))

        DevicePowerMemoryStore.shared.setOn(true, for: "LIMI1CH-\(id)")
        XCTAssertEqual(DevicePowerMemoryStore.shared.isOn(for: id), true)
        XCTAssertEqual(DevicePowerMemoryStore.shared.isOn(for: "80b54ecca7f4"), true)

        DevicePowerMemoryStore.shared.setOn(false, for: id)
        XCTAssertEqual(DevicePowerMemoryStore.shared.isOn(for: id), false)

        DevicePowerMemoryStore.shared.remove(for: id)
        XCTAssertNil(DevicePowerMemoryStore.shared.isOn(for: id))
        DevicePowerMemoryStore.shared.resetForTests()
    }

    // MARK: - Presence snapshot (stale-while-revalidate)

    func testPresenceSnapshotStore_recordsAndRemovesPerHardwareId() {
        PresenceSnapshotStore.shared.resetForTests()
        let id = "80B54ECCA7F4"
        XCTAssertNil(PresenceSnapshotStore.shared.snapshot(for: id))

        PresenceSnapshotStore.shared.record(deviceId: "LIMI1CH-\(id)", isOnline: true, path: .cloud)
        let snap = PresenceSnapshotStore.shared.snapshot(for: id)
        XCTAssertEqual(snap?.isOnline, true)
        XCTAssertEqual(snap?.path, .cloud)

        PresenceSnapshotStore.shared.record(deviceId: id, isOnline: false, path: .offline)
        XCTAssertEqual(PresenceSnapshotStore.shared.snapshot(for: id)?.isOnline, false)

        PresenceSnapshotStore.shared.remove(deviceId: id)
        XCTAssertNil(PresenceSnapshotStore.shared.snapshot(for: id))
        PresenceSnapshotStore.shared.resetForTests()
    }

    // MARK: - Virtual master presence

    func testVirtualMasterPresence_allMQTTShowsInternet() {
        let macs = ["80B54ECCA7F4", "80B54EC1C270"]
        let summary = VirtualMasterPresence.evaluate(
            memberHardwareIds: macs,
            isMQTTOnline: { _ in true },
            isBLEVisible: { _ in true }
        )
        XCTAssertEqual(summary.transport, .internet)
        XCTAssertEqual(summary.statusLabel, "Online · Internet")
    }

    func testVirtualMasterPresence_allMQTTShowsInternetEvenWhenBLEAlsoVisible() {
        DeviceTransportRegistry.shared.state(for: "80B54ECCA7F4").updateMQTTPresence(connected: true)
        DeviceTransportRegistry.shared.state(for: "80B54EC1C270").updateMQTTPresence(connected: true)
        let summary = VirtualMasterPresence.evaluate(memberHardwareIds: ["80B54ECCA7F4", "80B54EC1C270"])
        XCTAssertEqual(summary.transport, .internet)
        DeviceTransportRegistry.shared.forgetDevice(deviceId: "80B54ECCA7F4")
        DeviceTransportRegistry.shared.forgetDevice(deviceId: "80B54EC1C270")
    }

    func testVirtualMasterPresence_bleWithoutMQTTShowsBLE() {
        let macs = ["80B54ECCA7F4", "80B54EC1C270"]
        let summary = VirtualMasterPresence.evaluate(
            memberHardwareIds: macs,
            isMQTTOnline: { $0 == "80B54ECCA7F4" },
            isBLEVisible: { $0 == "80B54EC1C270" }
        )
        XCTAssertEqual(summary.transport, .ble)
        XCTAssertEqual(summary.statusLabel, "Online · BLE")
    }

    func testVirtualMasterPresence_missingMemberIgnoredStillOnline() {
        let macs = ["80B54ECCA7F4", "80B54EC1C270"]
        let summary = VirtualMasterPresence.evaluate(
            memberHardwareIds: macs,
            isMQTTOnline: { $0 == "80B54ECCA7F4" },
            isBLEVisible: { _ in false }
        )
        XCTAssertEqual(summary.transport, .online)
        XCTAssertTrue(summary.isOnline)
    }

    func testVirtualMasterPresence_allWiFiLANShowsOnline() {
        let macs = ["80B54ECCA7F4", "80B54EC1C270"]
        let summary = VirtualMasterPresence.evaluate(
            memberHardwareIds: macs,
            isMQTTOnline: { _ in false },
            isBLEVisible: { _ in false },
            isWiFiLANOnline: { _ in true }
        )
        XCTAssertEqual(summary.transport, .online)
        XCTAssertTrue(summary.isOnline)
        XCTAssertEqual(summary.scanSubtitleSuffix, "Online")
    }

    func testVirtualMasterPresence_staleCloudSnapshotCountsAsOnline() {
        let mac = "80B54ECCA7F4"
        PresenceSnapshotStore.shared.record(deviceId: mac, isOnline: true, path: .cloud)
        defer { PresenceSnapshotStore.shared.remove(deviceId: mac) }

        let summary = VirtualMasterPresence.evaluate(
            memberHardwareIds: [mac],
            isMQTTOnline: { id in
                guard id == mac,
                      let snap = PresenceSnapshotStore.shared.snapshot(for: mac),
                      snap.isOnline,
                      snap.path == .cloud else { return false }
                return true
            },
            isBLEVisible: { _ in false },
            isWiFiLANOnline: { _ in false }
        )
        XCTAssertEqual(summary.transport, .internet)
        XCTAssertTrue(summary.isOnline)
    }

    // MARK: - Master card cloud presence (backend device_status)

    func testMasterCardCloud_allMembersOffline_cardOffline() {
        let macs = ["3CDC75FEBF48", "3CDC75FDF1C4"]
        XCTAssertFalse(VirtualMasterPresence.isAnyMemberCloudOnline(memberHardwareIds: macs))
        XCTAssertEqual(VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: macs), "Offline")
        let counts = VirtualMasterPresence.cloudOnlineMemberCount(memberHardwareIds: macs)
        XCTAssertEqual(counts.online, 0)
        XCTAssertEqual(counts.total, 2)
    }

    func testMasterCardCloud_anyMemberOnline_cardOnlineWithCount() {
        let macs = ["3CDC75FEBF48", "3CDC75FDF1C4"]
        DeviceTransportRegistry.shared.state(for: "3CDC75FEBF48").updateMQTTPresence(connected: true)
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: "3CDC75FEBF48") }

        XCTAssertTrue(VirtualMasterPresence.isAnyMemberCloudOnline(memberHardwareIds: macs))
        XCTAssertEqual(VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: macs), "Online · 1/2 hubs")
    }

    func testMasterCardCloud_allMembersOnline_showsCloudLabel() {
        let macs = ["3CDC75FEBF48", "3CDC75FDF1C4", "3CDC75FEEBA0"]
        for mac in macs {
            DeviceTransportRegistry.shared.state(for: mac).updateMQTTPresence(connected: true)
        }
        defer {
            for mac in macs {
                DeviceTransportRegistry.shared.forgetDevice(deviceId: mac)
            }
        }

        XCTAssertEqual(VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: macs), "Online · Cloud")
    }

    func testMasterCardCloud_macFormatsMatchBackendIds() {
        DeviceTransportRegistry.shared.state(for: "3CDC75FEBF48").updateMQTTPresence(connected: true)
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: "3CDC75FEBF48") }

        XCTAssertTrue(VirtualMasterPresence.isMemberCloudOnline(hardwareId: "3CDC75FEBF48"))
        XCTAssertTrue(VirtualMasterPresence.isMemberCloudOnline(hardwareId: "3CDC:75:FE:BF:48"))
        XCTAssertTrue(VirtualMasterPresence.isMemberCloudOnline(hardwareId: "LIMI1CH-3CDC75FEBF48"))
    }

    func testMasterCardCloud_offlineRegistryNotCounted() {
        let mac = "3CDC75FDF1C4"
        DeviceTransportRegistry.shared.state(for: mac).updateMQTTPresence(connected: false)
        CloudPresenceMemory.shared.record(deviceId: mac, connected: false)
        defer {
            DeviceTransportRegistry.shared.forgetDevice(deviceId: mac)
            CloudPresenceMemory.shared.remove(deviceId: mac)
        }

        XCTAssertFalse(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
    }

    func testMasterCardCloud_lastOnStaysOnlineWithoutSnapshotOrBLE() {
        let mac = "3CDC75FEBF48"
        DeviceTransportRegistry.shared.state(for: mac).updateMQTTPresence(connected: true)
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: mac) }

        XCTAssertTrue(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
        XCTAssertEqual(
            VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [mac]),
            "Online · Cloud"
        )
    }

    func testMasterCardCloud_staysOnlineDuringBackendTwoMinuteOffWindow() {
        let mac = "80B54EC1C270"
        let state = DeviceTransportRegistry.shared.state(for: mac)
        state.applyMQTTPresenceForTests(
            connected: true,
            lastPresenceAt: Date().addingTimeInterval(-90)
        )
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: mac) }

        XCTAssertTrue(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
    }

    func testMasterCardCloud_offlineAfterTwoMinuteHeartbeatTimeout() {
        let mac = "80B54EC1C270"
        let state = DeviceTransportRegistry.shared.state(for: mac)
        state.applyMQTTPresenceForTests(
            connected: true,
            lastPresenceAt: Date().addingTimeInterval(-121)
        )
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: mac) }

        XCTAssertFalse(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
        XCTAssertEqual(
            VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [mac]),
            "Offline"
        )
    }

    func testMasterCardCloud_explicitOffGoesOfflineImmediately() {
        let mac = "80B54EC1C270"
        DeviceTransportRegistry.shared.state(for: mac).updateMQTTPresence(connected: true)
        DeviceTransportRegistry.shared.state(for: mac).updateMQTTPresence(connected: false)
        defer { DeviceTransportRegistry.shared.forgetDevice(deviceId: mac) }

        XCTAssertFalse(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
    }

    func testMasterCardCloud_snapshotAloneIsNotOnline() {
        let mac = "3CDC75FDF1C4"
        PresenceSnapshotStore.shared.resetForTests()
        PresenceSnapshotStore.shared.record(deviceId: mac, isOnline: true, path: .cloud)
        CloudPresenceMemory.shared.record(deviceId: mac, connected: true)
        defer {
            PresenceSnapshotStore.shared.resetForTests()
            CloudPresenceMemory.shared.remove(deviceId: mac)
            DeviceTransportRegistry.shared.forgetDevice(deviceId: mac)
        }

        XCTAssertFalse(VirtualMasterPresence.isMemberCloudOnline(hardwareId: mac))
        XCTAssertEqual(
            VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: [mac]),
            "Offline"
        )
    }

    // MARK: - Helpers

    private func waitForMain() {
        let exp = expectation(description: "main")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }
}
