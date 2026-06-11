//
//  DeviceTransportRegistry.swift
//  Limi
//
//  Owns one `DeviceTransportState` per deviceId. Subscribes to Bonjour
//  reachability and MQTT presence so individual states stay live without any
//  view having to wire them up.
//

import Foundation
import Combine

/// Owns one DeviceTransportState per deviceId.
///
/// All mutations happen on the main thread:
///   • Bonjour fan-out is delivered via `RunLoop.main`.
///   • Presence updates are delivered via `RunLoop.main`.
///   • SwiftUI view inits (the only other caller of `state(for:)`) run on main.
public final class DeviceTransportRegistry {
    public static let shared = DeviceTransportRegistry()

    private var states: [String: DeviceTransportState] = [:]
    private var cancellables: Set<AnyCancellable> = []

    /// Where presence facts come from. Defaults to the existing Socket.IO bridge.
    /// Swap for a real MQTT client later by re-assigning before bootstrap().
    public var presenceProvider: MQTTPresenceProviding = SocketIOMQTTBridge.shared

    private init() {
        bootstrap()
    }

    /// Returns the (cached or newly created) state for a device.
    public func state(for deviceId: String) -> DeviceTransportState {
        let key = deviceId.uppercased()
        if let existing = states[key] { return existing }
        let new = DeviceTransportState(deviceId: key)
        states[key] = new
        // Seed wifi/IP from Bonjour if we already have it.
        seedFromBonjour(state: new)
        return new
    }

    /// Snapshot of all known states (UI debug only).
    public var allStates: [DeviceTransportState] {
        Array(states.values)
    }

    // MARK: - Wiring

    private func bootstrap() {
        // Bonjour: every time the published list of devices changes, fan out
        // reachability + IP into the matching DeviceTransportState.
        BonjourServiceBrowser.shared.$discoveredWiFiDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.applyBonjour(devices)
            }
            .store(in: &cancellables)

        // MQTT presence: feed device_status (or future real MQTT presence/<id>)
        // into the matching state.
        presenceProvider.presencePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                self?.state(for: update.deviceId).updateMQTTPresence(connected: update.connected)
            }
            .store(in: &cancellables)
    }

    private func applyBonjour(_ devices: [BLEDevice]) {
        for device in devices {
            // The TXT record's deviceId is what the rest of the app keys on.
            // Fall back to the Bonjour name if TXT is missing (rare).
            guard let txtId = device.txtRecord?["deviceId"], !txtId.isEmpty else { continue }
            let key = txtId.uppercased()
            let state = states[key] ?? {
                let s = DeviceTransportState(deviceId: key)
                states[key] = s
                return s
            }()
            state.updateBonjour(
                reachable: device.reachability == .online,
                ip: device.ipAddress
            )
        }
    }

    private func seedFromBonjour(state: DeviceTransportState) {
        let match = BonjourServiceBrowser.shared.discoveredWiFiDevices.first {
            ($0.txtRecord?["deviceId"] ?? "").uppercased() == state.deviceId
        }
        guard let match = match else { return }
        state.updateBonjour(
            reachable: match.reachability == .online,
            ip: match.ipAddress
        )
    }
}

// MARK: - Presence provider abstraction

/// Anything that can tell us when a device's MQTT link comes up or down.
public protocol MQTTPresenceProviding {
    /// Stream of `(deviceId, connected)` updates.
    var presencePublisher: AnyPublisher<MQTTPresenceUpdate, Never> { get }
}

public struct MQTTPresenceUpdate: Equatable {
    public let deviceId: String
    public let connected: Bool

    public init(deviceId: String, connected: Bool) {
        self.deviceId = deviceId.uppercased()
        self.connected = connected
    }
}
