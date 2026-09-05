//
//  SocketPresenceLifecycle.swift
//  Limi
//
//  App-global (tab-independent) owner of cloud-socket presence side effects.
//
//  Previously these two side effects lived inside
//  `DeviceHomeView.onChange(of: socket.connectionStatus)`, which only runs while
//  the Home tab is mounted (the tab container mounts a single tab at a time). On
//  Schedule / Rooms / Profile a socket disconnect→reconnect therefore never cleared
//  stale MQTT presence nor re-probed — so a powered-off hub could keep showing
//  "Online · Cloud" until the user returned to Home. This observer runs for the
//  whole authenticated session, independent of which tab is on screen.
//
//  It only owns transport/presence plumbing (clear + refresh). All device grouping,
//  provisioning and control logic is untouched.
//

import Combine
import Foundation

@MainActor
final class SocketPresenceLifecycle: ObservableObject {
    static let shared = SocketPresenceLifecycle()

    private var cancellable: AnyCancellable?
    private var started = false
    private var lastStatus: LightControllingSocket.ConnectionStatus?
    private var heartbeatWatchTimer: Timer?

    /// How often to apply the backend 2-minute `heartbeat_timeout` window.
    private static let heartbeatWatchInterval: TimeInterval = 15

    /// Supplies the normalized hardware ids of virtual-device members known to this
    /// phone. The virtual-device store lives in the device app target, so it is injected
    /// here (see `DeviceRootView`) instead of referenced directly — targets without that
    /// store simply contribute no virtual ids.
    static var virtualDeviceIdProvider: @MainActor () -> Set<String> = { [] }

    private init() {}

    /// Begin observing the shared socket. Idempotent — safe to call on every launch.
    func start() {
        guard !started else { return }
        started = true
        DeviceConsole.focus("start — app-global socket presence observer active (runs on every tab)")

        cancellable = LightControllingSocket.shared.$connectionStatus
            .removeDuplicates()
            .sink { [weak self] status in
                Task { @MainActor in self?.handle(status) }
            }

        heartbeatWatchTimer = Timer.scheduledTimer(
            withTimeInterval: Self.heartbeatWatchInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.expireSilentHeartbeats() }
        }
    }

    /// Backend contract: `on` every ~1s. When those stop, `off` arrives after 2 minutes.
    /// If the `off` is late or lost, drop the hub here so Home does not stay Online forever.
    private func expireSilentHeartbeats() {
        guard LightControllingSocket.shared.isConnected else { return }
        for state in DeviceTransportRegistry.shared.allStates {
            guard state.mqttConnected else { continue }
            guard !state.isCloudPresenceFresh(ttl: VirtualMasterPresence.backendOfflineGrace) else {
                continue
            }
            DeviceConsole.focus("heartbeat timeout id=\(state.deviceId) — no on for 2m → Offline")
            DeviceTransportRegistry.shared.markCloudPresenceDropped(state.deviceId)
        }
    }

    private func handle(_ status: LightControllingSocket.ConnectionStatus) {
        let prev = Self.label(lastStatus)
        lastStatus = status

        switch status {
        case .connecting:
            DeviceConsole.focus("socket=connecting (prev=\(prev))")

        case .disconnected:
            // Keep last `on`. Phone socket down ≠ hub off. Fresh `on` or the
            // 2-minute backend `off` / heartbeat window decides Offline.
            DeviceConsole.focus("socket=disconnected (prev=\(prev)) — keeping last device_status")

        case .connected:
            // Don't grab the BLE radio for a presence refresh while the Add Device /
            // provisioning flow is reading a hub's Wi‑Fi list or sending credentials.
            guard !AddDeviceFlowActivityGate.isActive, !WiFiProvisioningActivityGate.isActive else {
                DeviceConsole.focus("socket=connected (prev=\(prev)) → refresh skipped (Add Device / provisioning active)")
                return
            }
            let ids = Self.sessionDeviceIds()
            DeviceConsole.focus("socket=connected (prev=\(prev)) → presence refresh for \(ids.count) hub(s)")
            DevicePresenceCoordinator.shared.requestRefresh(
                deviceIds: ids,
                reason: .mqttReconnect,
                force: true
            )
        }
    }

    /// Persistent device ids known to this phone — computed from stores only, so it
    /// works even when no view (Home) is mounted to supply its transient list.
    private static func sessionDeviceIds() -> Set<String> {
        var ids = Set<String>()

        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            let key = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            if !key.isEmpty, !LocallyRemovedDeviceStore.shared.contains(key) {
                ids.insert(key)
            }
        }
        for id in CloudPresenceMemory.shared.knownDeviceIds() {
            let key = LimiDeviceNaming.normalizedHardwareId(id)
            if !key.isEmpty, !LocallyRemovedDeviceStore.shared.contains(key) {
                ids.insert(key)
            }
        }
        for key in virtualDeviceIdProvider() where !key.isEmpty {
            ids.insert(key)
        }
        return ids
    }

    private static func label(_ status: LightControllingSocket.ConnectionStatus?) -> String {
        switch status {
        case .none: return "none"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        }
    }
}
