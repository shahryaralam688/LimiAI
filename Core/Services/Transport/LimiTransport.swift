//
//  LimiTransport.swift
//  Limi
//
//  Single entry point for all light commands. Picks the firmware-correct door
//  (MQTT > WebSocket > BLE) for each call by reading DeviceTransportState.
//
//  Hard rules (per spec):
//   • NEVER open a WebSocket while MQTT is active for that device.
//   • If WebSocket returns 503 mqtt_active, log + surface, do NOT retry WS.
//   • Reset is MQTT-only; never mixed into the command channel.
//

import Foundation

/// Notification posted when a 503 mqtt_active response is observed. The UI
/// can listen and show "Cloud active, try again".
public extension Notification.Name {
    static let limiCloudActive = Notification.Name("limi.cloudActive")
}

/// Single entry point for all light commands.
///
/// Plain class (no actor isolation). All async work (Socket.IO send, URLSession
/// WS send) is performed by the underlying door clients which run off-main
/// internally. State reads on `DeviceTransportState` are sync and thread-safe
/// for read because mutations are marshaled to the main thread.
public final class LimiTransport: ObservableObject {
    public static let shared = LimiTransport()

    private let mqtt: MQTTClient
    private let webSocket: DeviceWebSocketClient
    private let ble: BLELightWriter
    private let registry: DeviceTransportRegistry

    public init(
        mqtt: MQTTClient = SocketIOMQTTBridge.shared,
        webSocket: DeviceWebSocketClient = .shared,
        ble: BLELightWriter = .shared,
        registry: DeviceTransportRegistry = .shared
    ) {
        self.mqtt = mqtt
        self.webSocket = webSocket
        self.ble = ble
        self.registry = registry
    }

    // MARK: - Public API

    /// The effective door chosen for outgoing commands — includes manual medium override when set.
    public func door(for deviceId: String) -> Door {
        let state = registry.state(for: deviceId)
        return TransportMediumPreferenceStore.shared.resolvedDoor(for: state)
    }

    /// Firmware-derived door before any manual override (for debugging).
    public func firmwareDoor(for deviceId: String) -> Door {
        registry.state(for: deviceId).activeDoor
    }

    /// Send any LimiCommand. Routes using **effective** door (preference override or firmware rules).
    public func sendCommand(_ command: LimiCommand, for deviceId: String) async throws {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        let state = registry.state(for: key)
        let door = TransportMediumPreferenceStore.shared.resolvedDoor(for: state)

        switch door {
        case .mqtt:
            try await sendOverMQTT(command, deviceId: key)
        case .webSocket:
            try await sendOverWebSocket(command, state: state)
        case .ble:
            try await sendOverBLE(command, deviceId: key)
        case .unreachable:
            throw LimiTransportError.deviceUnreachable
        }
    }

    /// Send one group command for room control.
    /// Emits `{ GroupID, deviceIds, command }` over the Socket.IO MQTT bridge;
    /// backend extracts `command` and publishes to each device over MQTT.
    public func sendGroupCommand(
        _ command: LimiCommand,
        groupId: String = LimiCommand.defaultGroupID,
        deviceIds: [String]
    ) async throws {
        let normalized = deviceIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else {
            throw LimiTransportError.deviceUnreachable
        }
        let payload = command.toGroupJSON(groupId: groupId, deviceIds: normalized)
        try await mqtt.publishGroupCommand(payload)
    }

    /// Send a reset to the device. MQTT-only — never WebSocket, never command topic.
    public func sendReset(for deviceId: String) async throws {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        let state = registry.state(for: key)
        let door = TransportMediumPreferenceStore.shared.resolvedDoor(for: state)
        guard door == .mqtt else {
            throw LimiTransportError.operationNotSupported(door: door)
        }
        try await mqtt.publishReset(deviceId: key)
    }

    // MARK: - Door dispatch

    private func sendOverMQTT(_ command: LimiCommand, deviceId: String) async throws {
        let payload = command.toJSON(deviceId: deviceId)
        try await mqtt.publishCommand(payload, deviceId: deviceId)
    }

    private func sendOverWebSocket(_ command: LimiCommand, state: DeviceTransportState) async throws {
        guard let ip = state.deviceIP, !ip.isEmpty else {
            throw LimiTransportError.missingDeviceIP
        }
        let payload = command.toJSON(deviceId: state.deviceId)
        do {
            try await webSocket.send(payload, deviceId: state.deviceId, ipAddress: ip)
        } catch LimiTransportError.mqttActive {
            // 503 mqtt_active proves MQTT is up. Force the door over and notify.
            state.forceMQTTActive()
            NotificationCenter.default.post(
                name: .limiCloudActive,
                object: nil,
                userInfo: ["deviceId": state.deviceId]
            )
            // Do NOT retry WebSocket. Caller can re-issue and we'll pick MQTT.
            throw LimiTransportError.mqttActive
        }
    }

    private func sendOverBLE(_ command: LimiCommand, deviceId: String) async throws {
        // Safety net: provisioned hubs reject BLE while MQTT is active on firmware.
        if TransportMediumPreferenceStore.shared.preference == .automatic {
            let state = registry.state(for: deviceId)
            if state.activeDoor == .mqtt {
                try await sendOverMQTT(command, deviceId: deviceId)
                return
            }
        }
        // Smooth path: reconnect via stored BLE UUID when cloud is missing.
        try await BLECloudFallbackService.shared.ensureConnected(hardwareId: deviceId)
        let bleUUID = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: deviceId)
        try ble.send(command, toPeripheralUUID: bleUUID)
    }
}
