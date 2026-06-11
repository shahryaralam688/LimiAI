//
//  LimiTransportError.swift
//  Limi
//
//  All errors surfaced by LimiTransport.
//

import Foundation

public enum LimiTransportError: Error, LocalizedError, Equatable {
    /// Firmware refused the WebSocket connection because MQTT is active for
    /// this device. Caller MUST NOT retry WebSocket immediately. Show
    /// "Cloud active, try again" to the user.
    case mqttActive

    /// Network/path failure reaching the device on its current door.
    case deviceUnreachable

    /// Device responded that the JSON payload was malformed.
    case badCommand

    /// The chosen door cannot be used right now (e.g. MQTT bridge socket is
    /// disconnected, or BLE peripheral is not connected).
    case doorUnavailable(Door)

    /// The requested operation has no defined encoding for this door
    /// (e.g. Pattern over BLE, or Reset over WebSocket).
    case operationNotSupported(door: Door)

    /// We have no LAN IP for this device (Bonjour hasn't resolved it yet).
    case missingDeviceIP

    public var errorDescription: String? {
        switch self {
        case .mqttActive:
            return "Cloud (MQTT) is active for this device. Try again."
        case .deviceUnreachable:
            return "Device is unreachable on the current connection."
        case .badCommand:
            return "Device rejected the command."
        case .doorUnavailable(let door):
            return "\(door) connection is not available right now."
        case .operationNotSupported(let door):
            return "This operation is not supported on \(door)."
        case .missingDeviceIP:
            return "Device IP not yet discovered."
        }
    }
}
