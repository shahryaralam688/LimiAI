//
//  DeviceTransportState.swift
//  Limi
//
//  Per-device observable state. The `activeDoor` value is derived from
//  `wifiConnected` + `mqttConnected` exactly as the firmware spec dictates.
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

    /// Most recently resolved LAN IP from Bonjour. Required to build
    /// `ws://<device-ip>/ws`.
    @Published public private(set) var deviceIP: String? = nil

    /// True when BLE advertising should be expected on the device side.
    /// Per spec: BLE is OFF when MQTT is connected.
    public var bleAdvertisingExpected: Bool { !mqttConnected }

    /// True when the device can be controlled over Wi‑Fi / cloud / configured BLE.
    public var isAvailableForControl: Bool {
        wifiConnected || mqttConnected || ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: deviceId)
    }

    /// The door that LimiTransport must use right now.
    /// Decision logic (Case 3 aware + Cloud-first):
    ///   1) MQTT connected (cloud presence)   -> .mqtt   (highest priority)
    ///   2) Wi-Fi connected & MQTT NOT conn.  -> .webSocket
    ///   3) Otherwise (incl. cloud miss)      -> .ble   (reconnect via stored UUID)
    public var activeDoor: Door {
        if mqttConnected {
            return .mqtt
        }
        if wifiConnected {
            return .webSocket
        }
        return .ble
    }

    public init(deviceId: String) {
        self.deviceId = deviceId.uppercased()
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
            if self.mqttConnected != connected { self.mqttConnected = connected }
        }
    }

    /// Hard override: a WebSocket attempt was rejected with 503 mqtt_active,
    /// proving the device is on MQTT regardless of what we previously believed.
    public func forceMQTTActive() {
        runOnMain { [weak self] in
            guard let self = self else { return }
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
