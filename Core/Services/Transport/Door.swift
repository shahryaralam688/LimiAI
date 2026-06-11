//
//  Door.swift
//  Limi
//
//  The three (plus one) firmware control doors. Decision is encoded literally
//  per the firmware spec — see DeviceTransportState.activeDoor.
//

import Foundation

public enum Door: String, Equatable, CustomStringConvertible {
    /// Wi-Fi connected AND MQTT connected. App MUST publish to MQTT only.
    /// WebSocket MUST stay closed (firmware returns 503 mqtt_active).
    case mqtt

    /// Wi-Fi connected but MQTT NOT connected. Use ws://<device-ip>/ws.
    case webSocket

    /// Wi-Fi NOT connected. Talk to the device over BLE (FF03 writes).
    case ble

    /// Device cannot be reached on any door (offline + no BLE link).
    case unreachable

    public var description: String {
        switch self {
        case .mqtt: return "MQTT"
        case .webSocket: return "WebSocket"
        case .ble: return "BLE"
        case .unreachable: return "Unreachable"
        }
    }
}
