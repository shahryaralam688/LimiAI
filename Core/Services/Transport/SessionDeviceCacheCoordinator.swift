//
//  SessionDeviceCacheCoordinator.swift
//  Limi
//
//  Phone-local device diaries have no user id. Logout / login only changes
//  the token unless we wipe those diaries here. Add-device, provisioning,
//  and presence logic stay the same — Home just cannot read the previous
//  account's leftover hubs.
//

import Foundation

extension Notification.Name {
    /// Posted after session device caches have been wiped for the new owner.
    static let limiDeviceSessionDidChange = Notification.Name("limiDeviceSessionDidChange")
}

/// App-global owner of "which account may see phone-local device memory".
@MainActor
final class SessionDeviceCacheCoordinator {
    static let shared = SessionDeviceCacheCoordinator()

    private var started = false
    private var lastOwner: String?
    /// Device app injects SwiftData remembered-hub wipe (Core cannot see that model).
    private var swiftDataWipe: (@MainActor () -> Void)?

    private init() {}

    func attachSwiftDataWipe(_ wipe: @escaping @MainActor () -> Void) {
        swiftDataWipe = wipe
    }

    /// Idempotent — call on launch. Observes auth so logout/login always switch caches.
    func start() {
        if !started {
            started = true
            lastOwner = AuthManager.shared.sessionCacheKey()
            NotificationCenter.default.addObserver(
                forName: .limiAuthSessionDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.adoptCurrentSession()
                }
            }
        }
        adoptCurrentSession()
    }

    private func adoptCurrentSession() {
        let owner = AuthManager.shared.sessionCacheKey()
        if lastOwner == owner { return }
        lastOwner = owner

        wipePhoneLocalDeviceCaches()

        if owner.isEmpty {
            UserDataManager.shared.resetForSignOut()
            DevicePresenceCoordinator.shared.cancelRefresh()
        }

        DeviceConsole.log(
            .config,
            "session device cache owner=\(owner.isEmpty ? "signed-out" : owner)"
        )
        NotificationCenter.default.post(name: .limiDeviceSessionDidChange, object: nil)
    }

    private func wipePhoneLocalDeviceCaches() {
        ConfiguredBLEDeviceStore.shared.removeAll()
        CloudPresenceMemory.shared.removeAll()
        PresenceSnapshotStore.shared.removeAll()
        DevicePowerMemoryStore.shared.removeAll()
        LocalNetworkAllowStore.shared.removeAll()
        VirtualDeviceSequenceStore.shared.removeAll()
        DeviceTransportRegistry.shared.resetSessionCaches()
        SelectedDevicesStorage.shared.removeAll()
        swiftDataWipe?()
    }
}
