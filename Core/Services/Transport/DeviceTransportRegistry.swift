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
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else {
            let fallback = deviceId.uppercased()
            if let existing = states[fallback] { return existing }
            let new = DeviceTransportState(deviceId: fallback)
            states[fallback] = new
            return new
        }
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

        // MQTT presence: feed device_status into state, then Case 1 local-switch offer,
        // and notify UI (Case 3 cloud-online list).
        presenceProvider.presencePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] update in
                guard let self else { return }
                DeviceConsole.log(
                    .presence,
                    "registry update id=\(update.deviceId) mqttConnected=\(update.connected)"
                )
                let key = LimiDeviceNaming.normalizedHardwareId(update.deviceId)
                self.state(for: key).updateMQTTPresence(connected: update.connected)
                self.lastPresence[key] = update.connected
                CloudPresenceMemory.shared.record(
                    deviceId: key,
                    connected: update.connected
                )
                PresenceSnapshotStore.shared.record(
                    deviceId: key,
                    isOnline: update.connected,
                    path: update.connected ? .cloud : .offline
                )
                self.presenceChangeSubject.send(update)
                Task { @MainActor in
                    CloudOfflineLocalSwitchCoordinator.shared.handleMQTTPresence(
                        deviceId: update.deviceId,
                        connected: update.connected
                    )
                }
            }
            .store(in: &cancellables)
    }

    private var lastPresence: [String: Bool] = [:]
    private let presenceChangeSubject = PassthroughSubject<MQTTPresenceUpdate, Never>()

    /// UI (e.g. Device home) observes this to refresh cloud-online rows (Case 3).
    public var presenceChangePublisher: AnyPublisher<MQTTPresenceUpdate, Never> {
        presenceChangeSubject.eraseToAnyPublisher()
    }

    /// Snapshot of last in-memory presence (includes events that fired before UI subscribed).
    public func presenceSnapshot() -> [MQTTPresenceUpdate] {
        restorePersistedPresenceIfNeeded()
        return lastPresence.map { MQTTPresenceUpdate(deviceId: $0.key, connected: $0.value) }
    }

    /// Seed device **ids** from UserDefaults so Home can list known boards.
    /// Never treats disk presence as live Online — that caused ghost Online · Cloud
    /// (and fake on/off) when the physical board was powered off.
    public func restorePersistedPresenceIfNeeded() {
        for id in CloudPresenceMemory.shared.knownDeviceIds() {
            let key = LimiDeviceNaming.normalizedHardwareId(id)
            guard !key.isEmpty else { continue }
            if lastPresence[key] != nil { continue }
            // List-only seed. Live Online requires a fresh Socket `device_status`.
            lastPresence[key] = false
        }
    }

    /// Clear live MQTT flags (e.g. Socket reconnect). Fresh `device_status` must re-prove Online.
    public func clearLiveMQTTPresence() {
        for (key, state) in states {
            if state.mqttConnected {
                state.updateMQTTPresence(connected: false)
            }
            lastPresence[key] = false
        }
        DeviceConsole.log(.presence, "cleared live MQTT — waiting for fresh device_status")
    }

    /// Drop registry bookkeeping when the user deletes the device from this phone.
    public func forgetDevice(deviceId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !key.isEmpty else { return }
        lastPresence.removeValue(forKey: key)
        if let state = states.removeValue(forKey: key), state.mqttConnected {
            state.updateMQTTPresence(connected: false)
        }
    }

    private func applyBonjour(_ devices: [BLEDevice]) {
        var presentIds = Set<String>()

        for device in devices {
            guard let txtId = device.txtRecord?["deviceId"], !txtId.isEmpty else { continue }
            let key = LimiDeviceNaming.normalizedHardwareId(txtId)
            guard !key.isEmpty else { continue }
            presentIds.insert(key)
            let state = states[key] ?? {
                let s = DeviceTransportState(deviceId: key)
                states[key] = s
                return s
            }()
            let reachable = device.reachability == .online
            let ip = device.ipAddress
            state.updateBonjour(reachable: reachable, ip: ip)

            // Second case: board left MQTT and is advertising on LAN (WS).
            let hasIP = !(ip?.isEmpty ?? true)
            Task { @MainActor in
                CloudOfflineLocalSwitchCoordinator.shared.handleLocalReachability(
                    deviceId: key,
                    wifiReachable: reachable,
                    hasIP: hasIP
                )
            }
        }

        guard !devices.isEmpty else { return }

        for (key, state) in states where !presentIds.contains(key) && state.wifiConnected {
            state.updateBonjour(reachable: false, ip: nil)
            Task { @MainActor in
                CloudOfflineLocalSwitchCoordinator.shared.handleLocalReachability(
                    deviceId: key,
                    wifiReachable: false,
                    hasIP: false
                )
            }
        }
    }

    private func seedFromBonjour(state: DeviceTransportState) {
        let match = BonjourServiceBrowser.shared.discoveredWiFiDevices.first {
            LimiDeviceNaming.normalizedHardwareId($0.txtRecord?["deviceId"] ?? "") == state.deviceId
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
        self.deviceId = LimiDeviceNaming.normalizedHardwareId(deviceId)
        self.connected = connected
    }
}
