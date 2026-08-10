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
        for status in ["on", "online", "connected", "true", "1"] {
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

    func testDoor_localWifi_noMQTT_usesWebSocket() {
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        waitForMain()
        XCTAssertEqual(state.activeDoor, .webSocket)
    }

    func testDoor_mqttAndWifi_prefersMQTT() {
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        state.updateBonjour(reachable: true, ip: "192.168.1.50")
        state.updateMQTTPresence(connected: true)
        waitForMain()
        XCTAssertEqual(state.activeDoor, .mqtt)
    }

    func testDoor_offline_fallsToBLE() {
        let state = DeviceTransportState(deviceId: "80B54ECCA7F4")
        waitForMain()
        XCTAssertEqual(state.activeDoor, .ble)
        XCTAssertFalse(state.isAvailableForControl)
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

    // MARK: - Helpers

    private func waitForMain() {
        let exp = expectation(description: "main")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }
}
