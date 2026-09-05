//
//  DevicePresenceCoordinator.swift
//  Limi
//
//  Silent background presence refresh (MQTT → BLE ads). No blocking Home overlay.
//  Debounced so tab switches do not re-run a full probe every time.
//

import Combine
import Foundation

@MainActor
public final class DevicePresenceCoordinator: ObservableObject {
    public static let shared = DevicePresenceCoordinator()

    public enum Reason: String {
        case coldStart
        case homeAppear
        case mqttReconnect
    }

    /// True while a background refresh task is running (subtle UI only — never blocks taps).
    @Published public private(set) var isRefreshing = false

    /// First full refresh finished this app session.
    @Published public private(set) var sessionRefreshCompleted = false

    /// One-shot hint when every device is offline after a cold-start refresh.
    @Published public var powerOffHint: String?

    private var refreshTask: Task<Void, Never>?
    private var lastRefreshCompletedAt: Date?
    private var didEmitPowerOffHintThisSession = false

    private let refreshCooldown: TimeInterval = 60

    private init() {}

    public func requestRefresh(
        deviceIds: Set<String>,
        reason: Reason,
        force: Bool = false
    ) {
        if !force, let last = lastRefreshCompletedAt,
           Date().timeIntervalSince(last) < refreshCooldown,
           reason == .homeAppear {
            DeviceConsole.log(.home, "presence refresh skipped — cooldown")
            return
        }
        if isRefreshing, reason == .homeAppear, !force {
            DeviceConsole.log(.home, "presence refresh skipped — already refreshing")
            return
        }

        refreshTask?.cancel()
        isRefreshing = true

        refreshTask = Task { @MainActor in
            defer {
                BLECloudFallbackService.shared.stopAdvertisementListen()
                isRefreshing = false
                lastRefreshCompletedAt = Date()
                sessionRefreshCompleted = true
            }

            // Cold start only: wipe leftover in-memory flags so a powered-off hub
            // cannot resurrect as Online. Do NOT clear again on mqttReconnect —
            // SocketPresenceLifecycle already cleared on disconnect, and a second
            // wipe drops a live `device_status=on` that the backend may not resend.
            if reason == .coldStart {
                DeviceTransportRegistry.shared.clearLiveMQTTPresence()
            }

            DeviceConsole.log(.home, "silent presence refresh — \(reason.rawValue)")

            _ = await BluetoothManager.shared.waitUntilPoweredOn(timeout: 2)
            BLECloudFallbackService.shared.startAdvertisementListenForConfiguredDevices()

            for _ in 0..<40 {
                if Task.isCancelled { return }
                if LightControllingSocket.shared.isConnected { break }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            try? await Task.sleep(nanoseconds: 800_000_000)

            let ids = deviceIds
                .map { LimiDeviceNaming.normalizedHardwareId($0) }
                .filter { !$0.isEmpty }
            DeviceConsole.log(
                .home,
                "socket=\(LightControllingSocket.shared.isConnected ? "connected" : "down") refreshing \(ids.count) device(s) expected=\(ids.sorted().joined(separator: ","))"
            )

            // Give Socket.IO time to push device_status for every expected hub.
            for _ in 0..<12 {
                if Task.isCancelled { return }
                let pendingSocket = ids.filter {
                    !DeviceTransportRegistry.shared.state(for: $0).mqttConnected
                }
                if pendingSocket.isEmpty { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            Self.logSocketPresenceAudit(expectedIds: ids)

            let bleCandidates = ids.filter { id in
                !DeviceTransportRegistry.shared.state(for: id).mqttConnected
                    && ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: id)
            }
            if bleCandidates.contains(where: {
                BLECloudFallbackService.shared.presenceKind(for: $0) == .unreachable
            }) {
                for _ in 0..<8 {
                    if Task.isCancelled { return }
                    let stillPending = bleCandidates.contains {
                        BLECloudFallbackService.shared.presenceKind(for: $0) == .unreachable
                    }
                    if !stillPending { break }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }

            for id in ids {
                if Task.isCancelled { return }
                let state = DeviceTransportRegistry.shared.state(for: id)

                // Last `on` stays Online until backend `off` (about 2 min) or that window expires.
                if state.mqttConnected {
                    if state.isCloudPresenceFresh(ttl: VirtualMasterPresence.backendOfflineGrace) {
                        BLECloudFallbackService.shared.releaseIfCloudRestored(hardwareId: id)
                        PresenceSnapshotStore.shared.record(deviceId: id, isOnline: true, path: .cloud)
                    } else {
                        DeviceTransportRegistry.shared.markCloudPresenceDropped(id)
                        DeviceConsole.focus("heartbeat timeout id=\(id) — no on for 2m → Offline")
                    }
                    continue
                }

                // Socket already said `off` (or never `on`) — BLE is setup-only, not hub Online.
                guard ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: id) else { continue }
                let bleKind = BLECloudFallbackService.shared.presenceKind(for: id)
                switch bleKind {
                case .liveConnected, .advertising:
                    PresenceSnapshotStore.shared.record(deviceId: id, isOnline: true, path: .ble)
                case .unreachable:
                    PresenceSnapshotStore.shared.record(deviceId: id, isOnline: false, path: .offline)
                }
            }

            if Task.isCancelled { return }

            emitPowerOffHintIfNeeded(deviceIds: Set(ids), reason: reason)
        }
    }

    public func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        BLECloudFallbackService.shared.stopAdvertisementListen()
    }

    /// Prints which expected hubs got a Socket `device_status` reply vs which did not.
    private static func logSocketPresenceAudit(expectedIds: [String]) {
        let ordered = expectedIds.sorted()
        guard !ordered.isEmpty else { return }
        DeviceConsole.banner("SOCKET PRESENCE AUDIT")
        DeviceConsole.log(
            .presence,
            "waiting done — checking Socket.IO device_status for \(ordered.count) hub(s)"
        )
        var got: [String] = []
        var missing: [String] = []
        for id in ordered {
            let mqtt = DeviceTransportRegistry.shared.state(for: id).mqttConnected
            if mqtt {
                got.append(id)
                DeviceConsole.log(
                    .presence,
                    "GOT socket reply — id=\(id) mqttConnected=true (device_status received)"
                )
            } else {
                missing.append(id)
                DeviceConsole.log(
                    .presence,
                    "NO socket reply — id=\(id) mqttConnected=false (device_status NOT received from Socket)"
                )
            }
        }
        if missing.isEmpty {
            DeviceConsole.log(.presence, "AUDIT OK — all expected hubs have Socket device_status")
        } else {
            DeviceConsole.log(
                .presence,
                "AUDIT FAIL — missing Socket device_status for: \(missing.joined(separator: ","))"
            )
            DeviceConsole.log(
                .presence,
                "AUDIT got Socket reply for: \(got.isEmpty ? "(none)" : got.joined(separator: ","))"
            )
        }
    }

    private func emitPowerOffHintIfNeeded(deviceIds: Set<String>, reason: Reason) {
        guard reason == .coldStart || reason == .mqttReconnect else { return }
        guard !didEmitPowerOffHintThisSession, !deviceIds.isEmpty else { return }

        let anyLiveOnline = deviceIds.contains { id in
            if DeviceTransportRegistry.shared.state(for: id).mqttConnected { return true }
            if VirtualMasterPresence.effectiveCloudOnline(hardwareId: id) { return true }
            if ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: id) {
                switch BLECloudFallbackService.shared.presenceKind(for: id) {
                case .liveConnected, .advertising: return true
                case .unreachable: break
                }
            }
            return false
        }

        guard !anyLiveOnline else { return }
        didEmitPowerOffHintThisSession = true
        powerOffHint = "Device Power Off"
        if let first = deviceIds.first {
            CloudOfflineLocalSwitchCoordinator.shared.offerBonjourIfNeeded(deviceId: first)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if powerOffHint == "Device Power Off" {
                powerOffHint = nil
            }
        }
    }
}
