//
//  CloudOfflineLocalSwitchCoordinator.swift
//  Limi
//
//  First case: App/cloud disconnect (MQTT / Socket.IO off, no internet path).
//  Second case: Board drops MQTT and announces locally (Bonjour/WS/BLE) with
//  reachable status — app offers switch to local network / BLE control.
//
//  Both cases reuse standard doors: MQTT → WebSocket → BLE via
//  TransportMediumPreferenceStore + LimiTransport.
//

import Combine
import Foundation
import Network

/// Why the local-switch modal was offered.
public enum LocalControlSwitchCase: String, Equatable {
    /// App/cloud side lost MQTT / internet; local WS/BLE still possible.
    case firstCloudOffline
    /// Board disconnected from MQTT and is broadcasting locally (WS/BLE).
    case secondBoardLocalAnnounce
}

/// Suggested local path after cloud drops.
public struct LocalControlSwitchOffer: Identifiable, Equatable {
    public let id: UUID
    public let deviceId: String
    /// Preferred path (LAN WS if available, otherwise BLE).
    public let suggested: TransportMediumPreference
    public let canUseWebSocket: Bool
    public let canUseBLE: Bool
    public let switchCase: LocalControlSwitchCase

    public init(
        id: UUID = UUID(),
        deviceId: String,
        suggested: TransportMediumPreference,
        canUseWebSocket: Bool,
        canUseBLE: Bool,
        switchCase: LocalControlSwitchCase
    ) {
        self.id = id
        self.deviceId = deviceId.uppercased()
        self.suggested = suggested
        self.canUseWebSocket = canUseWebSocket
        self.canUseBLE = canUseBLE
        self.switchCase = switchCase
    }

    public var alertMessage: String {
        if canUseWebSocket && !canUseBLE {
            return "Cloud and Bluetooth are unavailable. Allow local network (Bonjour) / WebSocket control for this device?"
        }
        if canUseWebSocket {
            return "Do you want to allow local network (Bonjour) / WebSocket control for this device?"
        }
        var parts: [String] = []
        if canUseBLE { parts.append("BLE") }
        let paths = parts.isEmpty ? "local network / BLE" : parts.joined(separator: " / ")
        return "Your device is not connected to the cloud. Do you want to switch over \(paths) control?"
    }
}

@MainActor
public final class CloudOfflineLocalSwitchCoordinator: ObservableObject {
    public static let shared = CloudOfflineLocalSwitchCoordinator()

    @Published public private(set) var activeOffer: LocalControlSwitchOffer?

    /// Devices the user already declined this app session (avoid spam).
    private var declinedDeviceIds: Set<String> = []
    /// Last known MQTT connected flag per device.
    private var lastMQTTConnected: [String: Bool] = [:]
    /// Last known local Wi‑Fi reachability (Bonjour) per device.
    private var lastWifiReachable: [String: Bool] = [:]
    /// Preference before user accepted a local switch (restore when cloud returns).
    private var preferenceBeforeLocalSwitch: TransportMediumPreference?
    private var switchedForDeviceId: String?

    private var pathMonitor: NWPathMonitor?
    private var pathMonitorQueue = DispatchQueue(label: "limi.localSwitch.pathMonitor")
    private var cancellables = Set<AnyCancellable>()
    /// True when the phone currently has a usable network path (Wi‑Fi/cellular).
    private var phoneHasNetwork = true
    /// True when phone path is expensive/constrained enough to treat cloud as unreliable;
    /// we mainly care about “no internet / unsatisfied” for first case.
    private var phonePathSatisfied = true

    private init() {
        startPathMonitor()
        observeCloudSocket()
    }

    // MARK: - Case 1: cloud / MQTT presence off

    /// Call after `DeviceTransportState` has been updated for this presence event.
    public func handleMQTTPresence(deviceId: String, connected: Bool) {
        let key = normalizeId(deviceId)
        guard !key.isEmpty else { return }

        let previouslyConnected = lastMQTTConnected[key] ?? false
        lastMQTTConnected[key] = connected

        if connected {
            if switchedForDeviceId == key {
                restorePreferenceAfterCloudReturn()
            }
            declinedDeviceIds.remove(key)
            if activeOffer?.deviceId == key {
                activeOffer = nil
            }
            // Cloud restored — release BLE so MQTT stays the active door.
            BLECloudFallbackService.shared.releaseIfCloudRestored(hardwareId: key)
            return
        }

        // Case 1: only on real on→off edge (avoid spam reconnect / jetsam).
        guard previouslyConnected else { return }

        BLECloudFallbackService.shared.prepareBLEIfCloudMissing(hardwareId: key)
        considerOffer(
            deviceId: key,
            switchCase: .firstCloudOffline,
            requireLocalReachable: false
        )
    }

    // MARK: - Case 2: board local announce (Bonjour/WS up while MQTT off)

    /// Call after Bonjour updates a device’s Wi‑Fi reachability / IP.
    /// Second case: board left MQTT and is advertising on the LAN (WS).
    public func handleLocalReachability(deviceId: String, wifiReachable: Bool, hasIP: Bool) {
        let key = normalizeId(deviceId)
        guard !key.isEmpty else { return }

        let wasReachable = lastWifiReachable[key] ?? false
        lastWifiReachable[key] = wifiReachable

        // Board just became locally reachable while MQTT is off (SECOND CASE).
        let becameReachable = wifiReachable && hasIP && !wasReachable
        guard becameReachable else { return }

        let mqttOn = lastMQTTConnected[key]
            ?? DeviceTransportRegistry.shared.state(for: key).mqttConnected
        guard mqttOn == false else { return }

        considerOffer(
            deviceId: key,
            switchCase: .secondBoardLocalAnnounce,
            requireLocalReachable: true
        )
    }

    // MARK: - Case 1 helper: app cloud socket dropped

    /// When the phone loses the Socket.IO cloud link, scan known devices for local paths.
    public func handleAppCloudSocketDisconnected() {
        let states = DeviceTransportRegistry.shared.allStates
        for state in states {
            let key = normalizeId(state.deviceId)
            lastMQTTConnected[key] = false
            considerOffer(
                deviceId: key,
                switchCase: .firstCloudOffline,
                requireLocalReachable: false
            )
            if activeOffer != nil { break }
        }
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            if DeviceTransportRegistry.shared.state(for: record.hardwareId).mqttConnected { continue }
            if BluetoothManager.shared.isLiveConnected(forPeripheralUUID: record.blePeripheralUUID) {
                continue
            }
            BLECloudFallbackService.shared.prepareBLEIfCloudMissing(hardwareId: record.hardwareId)
        }
    }

    // MARK: - Shared offer gate

    private func considerOffer(
        deviceId key: String,
        switchCase: LocalControlSwitchCase,
        requireLocalReachable: Bool
    ) {
        guard activeOffer == nil else { return }
        guard !declinedDeviceIds.contains(key) else { return }

        let preference = TransportMediumPreferenceStore.shared.preference
        if preference == .webSocket || preference == .ble {
            return
        }

        let state = DeviceTransportRegistry.shared.state(for: key)
        let canWS = state.wifiConnected && !(state.deviceIP?.isEmpty ?? true)
        let hasConfiguredBLE = ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: key)
        let canBLE = BluetoothManager.shared.isBluetoothOn && (
            hasConfiguredBLE || BluetoothManager.shared.isPeripheralReady
        )

        if requireLocalReachable {
            // Second case: need a real local path from the board.
            guard canWS || canBLE || BluetoothManager.shared.isBluetoothOn else { return }
        } else {
            // First case: flowchart — if neither WS nor BLE, No action.
            guard canWS || canBLE || BluetoothManager.shared.isBluetoothOn else { return }
        }

        // Prefer BLE automatically; offer modal mainly for Bonjour/WS permission.
        let suggested: TransportMediumPreference
        if canWS {
            suggested = .webSocket
        } else {
            suggested = .ble
        }
        let offerCanBLE = canBLE || BluetoothManager.shared.isBluetoothOn
        activeOffer = LocalControlSwitchOffer(
            deviceId: key,
            suggested: suggested,
            canUseWebSocket: canWS,
            canUseBLE: offerCanBLE,
            switchCase: switchCase
        )
    }

    // MARK: - User actions

    /// Home probe failed MQTT+BLE — ask for Bonjour/WS if LAN reachable.
    public func offerBonjourIfNeeded(deviceId: String) {
        considerOffer(
            deviceId: normalizeId(deviceId),
            switchCase: .firstCloudOffline,
            requireLocalReachable: true
        )
    }

    public func accept() {
        guard let offer = activeOffer else { return }
        let store = TransportMediumPreferenceStore.shared
        if preferenceBeforeLocalSwitch == nil {
            preferenceBeforeLocalSwitch = store.preference
        }
        store.preference = offer.suggested
        switchedForDeviceId = offer.deviceId
        // Bonjour / WS requires explicit user Yes.
        if offer.suggested == .webSocket || offer.canUseWebSocket {
            LocalNetworkAllowStore.shared.allow(offer.deviceId)
        }
        // Smooth: start BLE reconnect when user picks BLE (or as backup).
        if offer.suggested == .ble || offer.canUseBLE {
            BLECloudFallbackService.shared.prepareBLEIfCloudMissing(hardwareId: offer.deviceId)
        }
        activeOffer = nil
    }

    public func decline() {
        if let offer = activeOffer {
            declinedDeviceIds.insert(offer.deviceId)
        }
        activeOffer = nil
    }

    // MARK: - Restore

    private func restorePreferenceAfterCloudReturn() {
        guard let previous = preferenceBeforeLocalSwitch else {
            switchedForDeviceId = nil
            return
        }
        TransportMediumPreferenceStore.shared.preference = previous
        preferenceBeforeLocalSwitch = nil
        switchedForDeviceId = nil
    }

    // MARK: - Observers

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let satisfied = path.status == .satisfied
                let wasSatisfied = self.phonePathSatisfied
                self.phonePathSatisfied = satisfied
                self.phoneHasNetwork = satisfied
                // First case: phone lost usable network → try local offers.
                if wasSatisfied && !satisfied {
                    self.handleAppCloudSocketDisconnected()
                }
            }
        }
        monitor.start(queue: pathMonitorQueue)
    }

    private func observeCloudSocket() {
        LightControllingSocket.shared.$connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .disconnected {
                    self.handleAppCloudSocketDisconnected()
                }
            }
            .store(in: &cancellables)
    }

    private func normalizeId(_ deviceId: String) -> String {
        LimiDeviceNaming.normalizedHardwareId(deviceId)
    }
}
