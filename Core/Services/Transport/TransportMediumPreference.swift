//
//  TransportMediumPreference.swift
//  Limi
//
//  Lets you force which control medium to use while testing (or stay on Automatic
//  firmware-driven door rules). Persisted across app launches.
//

import Combine
import Foundation

/// **Automatic** = MQTT → BLE → WebSocket (Bonjour only after user allow).
public enum TransportMediumPreference: String, CaseIterable, Codable, Hashable {
    /// Use `DeviceTransportState.activeDoor` (MQTT → BLE → allowed Bonjour/WS).
    case automatic
    /// Always try Socket.IO → backend → MQTT bridge.
    case mqtt
    /// Always try LAN `ws://<ip>/ws` when IP is known.
    case webSocket
    /// Always write to BLE characteristic FF03.
    case ble

    public var pickerTitle: String {
        switch self {
        case .automatic: return "Automatic (firmware)"
        case .mqtt: return "MQTT (cloud)"
        case .webSocket: return "LAN WebSocket"
        case .ble: return "Bluetooth (BLE)"
        }
    }

    /// Short badge text for overlay labels.
    public var shortTitle: String {
        switch self {
        case .automatic: return "Auto"
        case .mqtt: return "MQTT"
        case .webSocket: return "WebSocket"
        case .ble: return "BLE"
        }
    }

    /// Compact chip label so Auto / MQTT / LAN / BLE fit one row on all iPhones.
    public var chipTitle: String {
        switch self {
        case .automatic: return "Auto"
        case .mqtt: return "MQTT"
        case .webSocket: return "LAN"
        case .ble: return "BLE"
        }
    }
}

/// Persisted `@Published` store for SwiftUI pickers + LimiTransport reads.
public final class TransportMediumPreferenceStore: ObservableObject {
    public static let shared = TransportMediumPreferenceStore()

    private static let userDefaultsKey = "limi.transport.mediumPreference"

    @Published public var preference: TransportMediumPreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
        preference = TransportMediumPreference(rawValue: raw ?? "") ?? .automatic
    }

    public func resolvedDoor(for state: DeviceTransportState) -> Door {
        switch preference {
        case .automatic:
            return state.activeDoor
        case .mqtt:
            return .mqtt
        case .webSocket:
            // User chose LAN path; missing IP surfaces as `missingDeviceIP` on send.
            return .webSocket
        case .ble:
            return .ble
        }
    }
}
