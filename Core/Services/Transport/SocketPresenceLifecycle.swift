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
import UIKit

@MainActor
final class SocketPresenceLifecycle: ObservableObject {
    static let shared = SocketPresenceLifecycle()

    private var cancellable: AnyCancellable?
    private var started = false
    private var lastStatus: LightControllingSocket.ConnectionStatus?

    /// How often to actively re-check presence while the app is foregrounded. This is the
    /// standard "presence poll" — every tick we log each hub's live signals and run a
    /// silent refresh so a hub that silently left Wi‑Fi resolves to BLE / offline without
    /// an app restart. Foreground-only so it never drains battery in the background.
    private static let revalidateInterval: TimeInterval = 20
    private var revalidateTimer: Timer?

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

        revalidateTimer = Timer.scheduledTimer(
            withTimeInterval: Self.revalidateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.revalidateStaleCloudPresence() }
        }
    }

    /// Presence poll (foreground only). This does **nothing** while every hub is fresh on
    /// cloud — no BLE scan, no list rebuild, no flicker. It only acts when a hub's cloud
    /// heartbeat has gone stale (silent Wi‑Fi drop), triggering one silent refresh that
    /// resolves ground truth (BLE handoff / offline) without an app restart.
    private func revalidateStaleCloudPresence() {
        guard UIApplication.shared.applicationState != .background else { return }

        // Add Device / provisioning reserves the BLE radio for the Wi‑Fi list read + credential
        // write. A background scan here would make that time out ("try again") — so stay out.
        guard !AddDeviceFlowActivityGate.isActive, !WiFiProvisioningActivityGate.isActive else {
            return
        }

        // Only re-probe when a hub actually looks stale (was on cloud, but the heartbeat
        // stopped arriving within the TTL). Healthy, fresh hubs never trigger extra work.
        let hasStaleHub = DeviceTransportRegistry.shared.allStates.contains {
            $0.mqttConnected && !$0.isCloudPresenceFresh(ttl: VirtualMasterPresence.cloudPresenceTTL)
        }
        guard hasStaleHub else { return }

        let ids = Self.sessionDeviceIds()
        guard !ids.isEmpty else { return }

        DeviceConsole.focus("revalidate — stale cloud hub → presence re-probe (\(ids.count) hub(s))")
        DevicePresenceCoordinator.shared.requestRefresh(
            deviceIds: ids,
            reason: .homeAppear,
            force: true
        )
    }

    private func handle(_ status: LightControllingSocket.ConnectionStatus) {
        let prev = Self.label(lastStatus)
        lastStatus = status

        switch status {
        case .connecting:
            DeviceConsole.focus("socket=connecting (prev=\(prev))")

        case .disconnected:
            DeviceConsole.focus("socket=disconnected (prev=\(prev)) → clearing live MQTT presence")
            DeviceTransportRegistry.shared.clearLiveMQTTPresence()

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
