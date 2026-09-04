//
//  DeviceTransportState.swift
//  Limi
//
//  Per-device observable state. Door priority (app policy):
//    MQTT → BLE → WebSocket (Bonjour only after user modal allow).
//

import Foundation
import Combine

public final class DeviceTransportState: ObservableObject {
    /// Uppercased deviceId (MAC without colons). Stable identity across the app.
    public let deviceId: String

    /// True when the device is reachable on Wi-Fi (Bonjour reports online).
    @Published public private(set) var wifiConnected: Bool = false

    /// True when the device is connected to MQTT (per backend presence event,
    /// or forced true by a 503 mqtt_active response on a WebSocket attempt).
    @Published public private(set) var mqttConnected: Bool = false

    /// Timestamp of the most recent *definite online* presence event. The backend
    /// heart-beats `device_status` while a hub is on cloud, so a long silence means
    /// the hub dropped its Wi‑Fi even though no explicit `off` ever arrived. Used to
    /// expire a stale cloud link so BLE / offline can surface without an app restart.
    @Published public private(set) var lastMQTTPresenceAt: Date?

    /// True when a definite online presence event arrived within `ttl` seconds.
    public func isCloudPresenceFresh(ttl: TimeInterval) -> Bool {
        guard mqttConnected, let last = lastMQTTPresenceAt else { return false }
        return Date().timeIntervalSince(last) <= ttl
    }

    /// Most recently resolved LAN IP from Bonjour. Required to build
    /// `ws://<device-ip>/ws`.
    @Published public private(set) var deviceIP: String? = nil

    /// True when BLE advertising should be expected on the device side.
    /// Per spec: BLE is OFF when MQTT is connected.
    public var bleAdvertisingExpected: Bool { !mqttConnected }

    /// Controllable on live MQTT, LAN WebSocket, or cloud path for Wi‑Fi provisioned hubs.
    public var isAvailableForControl: Bool {
        if mqttConnected { return true }
        if LocalNetworkAllowStore.shared.isAllowed(for: deviceId), wifiConnected {
            return true
        }
        if isWiFiProvisionedHub {
            switch LightControllingSocket.shared.connectionStatus {
            case .connected, .connecting:
                return true
            case .disconnected:
                // Definite cloud-offline from a prior device_status.
                if CloudPresenceMemory.shared.lastConnected(deviceId: deviceId) == false {
                    return false
                }
                // First connect / presence in flight — banner shows "Connecting…".
                return true
            }
        }
        return false
    }

    /// Door selection:
    ///   1) MQTT live
    ///   2) Cloud MQTT for Wi‑Fi provisioned hubs (firmware ignores BLE while MQTT is active)
    ///   3) WebSocket when user allowed local network AND Bonjour reachable
    ///   4) BLE for setup-only / never provisioned boards
    public var activeDoor: Door {
        if mqttConnected {
            return .mqtt
        }
        if isWiFiProvisionedHub {
            return .mqtt
        }
        let localAllowed = LocalNetworkAllowStore.shared.isAllowed(for: deviceId)
        if localAllowed, wifiConnected {
            return .webSocket
        }
        if LightControllingSocket.shared.isConnected {
            return .mqtt
        }
        return .ble
    }

    /// Hub completed BLE Wi‑Fi setup — commands must use cloud MQTT, not BLE GATT.
    private var isWiFiProvisionedHub: Bool {
        if ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: deviceId) {
            return true
        }
        // Seen on cloud before; firmware may ignore BLE while MQTT is active.
        return CloudPresenceMemory.shared.lastConnected(deviceId: deviceId) != nil
    }

    public init(deviceId: String) {
        self.deviceId = LimiDeviceNaming.normalizedHardwareId(deviceId)
    }

    // MARK: - Mutators (called by DeviceTransportRegistry, always on main)

    /// Update Wi-Fi reachability and (optionally) IP from a Bonjour event.
    /// Does not clear MQTT — cloud presence is owned by `updateMQTTPresence` (Case 3).
    public func updateBonjour(reachable: Bool, ip: String?) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if self.wifiConnected != reachable { self.wifiConnected = reachable }
            if let ip = ip, self.deviceIP != ip { self.deviceIP = ip }
            if !reachable, self.deviceIP != nil { self.deviceIP = nil }
        }
    }

    /// Update MQTT presence from a backend presence event.
    public func updateMQTTPresence(connected: Bool) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if connected {
                let previous = self.lastMQTTPresenceAt
                self.lastMQTTPresenceAt = Date()
                if DeviceConsole.focusMode, let previous {
                    let gap = Int(Date().timeIntervalSince(previous).rounded())
                    DeviceConsole.focus("heartbeat id=\(self.deviceId) gap=\(gap)s since last online event")
                }
            }
            if self.mqttConnected != connected { self.mqttConnected = connected }
        }
    }

    /// Hard override: a WebSocket attempt was rejected with 503 mqtt_active,
    /// proving the device is on MQTT regardless of what we previously believed.
    public func forceMQTTActive() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.lastMQTTPresenceAt = Date()
            if !self.mqttConnected { self.mqttConnected = true }
        }
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
