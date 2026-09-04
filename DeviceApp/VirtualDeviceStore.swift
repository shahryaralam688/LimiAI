//
//  VirtualDeviceStore.swift
//  LIMI AI Device
//
//  Per-user cloud sync: GET loads groups. Enable toggle POSTs MAC list (Bearer token).
//

import Foundation
import SwiftData
import Combine

@MainActor
final class VirtualDeviceStore: ObservableObject {
    static let shared = VirtualDeviceStore()

    @Published private(set) var virtualDeviceID: String = ""
    @Published private(set) var enabledHardwareIds: [String] = []
    @Published private(set) var remoteGroups: [VirtualDeviceRemotePayload] = []
    @Published private(set) var lastSyncMessage: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isSyncing = false

    /// Automatic GET throttle — manual refresh and screen-open bypass this.
    private let autoRefreshInterval: TimeInterval = 45
    private var modelContext: ModelContext?
    private var hasCompletedInitialPull = false
    private var syncTask: Task<Void, Never>?
    private var ownerUserKey: String = ""

    private init() {
        NotificationCenter.default.addObserver(
            forName: .limiAuthSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !AuthManager.shared.isAuthenticated || AuthManager.shared.getToken() == nil {
                    self.resetForSignOut()
                } else {
                    self.adoptCurrentUserAndPull()
                }
            }
        }
    }

    /// Clears cache when the signed-in user changes or signs out.
    func resetForSignOut() {
        clearInMemoryState()
        deletePersistedRow()
    }

    func configure(context: ModelContext) {
        modelContext = context
        adoptCurrentUserAndPull()
    }

    // MARK: - Home grouping

    /// Every cloud virtual device from GET — shown as a Home master card.
    func cloudHomeGroupingSpecs() -> [VirtualDeviceGroupingSpec] {
        homeGroupingSpecs()
    }

    /// Cloud groups that include at least one hub configured on this phone (Add Device / toggles).
    func homeGroupingSpecs(relevantHardwareIds: Set<String>) -> [VirtualDeviceGroupingSpec] {
        let relevant = Set(
            relevantHardwareIds
                .map { LimiDeviceNaming.normalizedHardwareId($0) }
                .filter { !$0.isEmpty }
        )

        func groupTouchesPhone(_ group: VirtualDeviceRemotePayload) -> Bool {
            group.mac_addresses.contains {
                relevant.contains(LimiDeviceNaming.normalizedHardwareIdFromMAC($0))
            }
        }

        let filtered = remoteGroups.filter(groupTouchesPhone)
        guard !filtered.isEmpty else { return [] }

        let useShortLabel = filtered.count > 1
        return filtered.compactMap {
            VirtualDeviceGroupingSpec.fromRemote($0, useShortLabel: useShortLabel)
        }
    }

    /// Legacy — prefers every cloud group (avoid; pass `relevantHardwareIds` from the home screen).
    func homeGroupingSpecs() -> [VirtualDeviceGroupingSpec] {
        guard !remoteGroups.isEmpty else { return [] }
        let useShortLabel = remoteGroups.count > 1
        return remoteGroups.compactMap {
            VirtualDeviceGroupingSpec.fromRemote($0, useShortLabel: useShortLabel)
        }
    }

    func isMemberOfAnyRemoteGroup(hardwareId: String) -> Bool {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        return remoteGroups.contains { group in
            group.mac_addresses.contains {
                LimiDeviceNaming.normalizedHardwareIdFromMAC($0) == key
            }
        }
    }

    func isEnabled(hardwareId: String) -> Bool {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        // Optimistic local list first so the Connected Devices toggle updates immediately.
        if enabledHardwareIds.contains(key) { return true }
        return isMemberOfAnyRemoteGroup(hardwareId: key)
    }

    /// Enable / disable a hub in the virtual device. Always POSTs (with Bearer token)
    /// the updated MAC list for the target `virtual_device_id`.
    func setEnabled(_ enabled: Bool, hardwareId: String) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }

        guard AuthManager.shared.authorizationHeaderValue() != nil else {
            lastSyncMessage = "Sign in to update virtual devices."
            return
        }

        var nextEnabled = Set(enabledHardwareIds)
        if enabled {
            nextEnabled.insert(key)
        } else {
            nextEnabled.remove(key)
        }
        enabledHardwareIds = nextEnabled.sorted()

        let target = resolvePostTarget(hardwareId: key, enabling: enabled)
        virtualDeviceID = target.virtualDeviceId
        persist()

        DeviceConsole.log(
            .config,
            "virtual-device toggle \(enabled ? "ON" : "OFF") id=\(target.virtualDeviceId) mac=\(key) postMacs=\(target.macAddresses.count)"
        )

        enqueueSync {
            await self.postGroupUpdate(
                virtualDeviceId: target.virtualDeviceId,
                macAddresses: target.macAddresses
            )
            await self.refreshFromBackend(force: true)
        }
    }

    /// Explicitly create a BRAND-NEW virtual device from the given hardware ids.
    /// Never merges into an existing cloud group — always a fresh `vd-` id.
    /// Ids already belonging to a group should be filtered out by the caller.
    func createVirtualDevice(hardwareIds: [String]) {
        let keys = hardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
        let unique = Array(Set(keys)).sorted()

        guard !unique.isEmpty else {
            lastSyncMessage = "Select at least one online device to group."
            return
        }
        guard AuthManager.shared.authorizationHeaderValue() != nil else {
            lastSyncMessage = "Sign in to create a virtual device."
            return
        }

        let newId = Self.generateVirtualDeviceID()
        let colonMacs = unique.map { LimiDeviceNaming.colonSeparatedMAC(from: $0) }

        // Optimistic local reflection so Home/toggles update immediately.
        var next = Set(enabledHardwareIds)
        unique.forEach { next.insert($0) }
        enabledHardwareIds = next.sorted()
        virtualDeviceID = newId
        persist()

        DeviceConsole.log(
            .config,
            "virtual-device CREATE NEW id=\(newId) macs=\(unique.joined(separator: " | "))"
        )

        enqueueSync {
            await self.postGroupUpdate(virtualDeviceId: newId, macAddresses: colonMacs)
            await self.refreshFromBackend(force: true)
        }
    }

    /// Fresh cloud-style id (`vd-XXXXXXXX`) — always unique, never reuses existing.
    private static func generateVirtualDeviceID() -> String {
        "vd-" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
    }

    /// Picks which cloud / local virtual device to update, and the full MAC list to POST.
    private func resolvePostTarget(
        hardwareId: String,
        enabling: Bool
    ) -> (virtualDeviceId: String, macAddresses: [String]) {
        let colonKey = LimiDeviceNaming.colonSeparatedMAC(from: hardwareId)

        if let group = cloudGroupForMembershipChange(hardwareId: hardwareId, enabling: enabling) {
            var macs = normalizedColonMACs(from: group.mac_addresses)
            if enabling {
                if !macs.contains(where: {
                    LimiDeviceNaming.normalizedHardwareIdFromMAC($0) == hardwareId
                }) {
                    macs.append(colonKey)
                    macs.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                }
            } else {
                macs.removeAll {
                    LimiDeviceNaming.normalizedHardwareIdFromMAC($0) == hardwareId
                }
            }
            return (group.virtual_device_id, macs)
        }

        // No matching cloud group — create / reuse a short cloud-style id and POST
        // every hub currently enabled on this phone.
        let id = ensureVirtualDeviceID()
        return (id, colonMACAddressesForAPI())
    }

    /// Creates `vd-XXXXXXXX` when the user enables the first hub (matches API / cloud style).
    @discardableResult
    private func ensureVirtualDeviceID() -> String {
        let existing = virtualDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty { return existing }
        if let first = remoteGroups.first(where: { !$0.virtual_device_id.isEmpty }) {
            virtualDeviceID = first.virtual_device_id
            return first.virtual_device_id
        }
        let generated = "vd-" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
        virtualDeviceID = generated
        DeviceConsole.log(.config, "virtual-device created local id \(generated)")
        return generated
    }

    func colonMACAddressesForAPI() -> [String] {
        enabledHardwareIds.map { LimiDeviceNaming.colonSeparatedMAC(from: $0) }
    }

    /// Pull cloud for the signed-in user and fully replace local cache (no POST).
    func syncNow() async {
        await enqueueSyncAndWait {
            await self.refreshFromBackend(force: true)
        }
    }

    /// GET /virtual-device — Bearer token; `data` array replaces SwiftData for this user.
    func refreshFromBackend(force: Bool = false) async {
        guard modelContext != nil else { return }
        guard AuthManager.shared.authorizationHeaderValue() != nil else {
            lastSyncMessage = "Sign in to load virtual devices from cloud."
            DeviceConsole.log(.config, "virtual-device GET skipped — no auth token")
            return
        }

        let currentOwner = Self.currentOwnerUserKey()
        if ownerUserKey != currentOwner {
            clearInMemoryState()
            ownerUserKey = currentOwner
            deletePersistedRow()
            hasCompletedInitialPull = false
        }

        if !force {
            if !hasCompletedInitialPull {
                // Always allow the first pull once per install/session.
            } else if let lastSyncedAt,
                      Date().timeIntervalSince(lastSyncedAt) < autoRefreshInterval {
                return
            }
        }

        lastSyncMessage = nil
        DeviceConsole.log(.config, "virtual-device GET (replace local for user)")

        do {
            let envelope = try await LimiDeviceAPI.listVirtualDevices(scopeVirtualDeviceId: nil)
            guard envelope.success else {
                throw LimiAPIError.backend(message: envelope.message ?? "Could not load virtual devices.")
            }
            replaceLocalWithCloud(envelope.data, syncedAt: Date())
            hasCompletedInitialPull = true
            lastSyncMessage = envelope.data.isEmpty
                ? "No virtual devices on cloud for this account."
                : "Synced \(envelope.data.count) virtual device(s) for this account"
            DeviceConsole.log(
                .config,
                "virtual-device GET OK count=\(envelope.data.count) — local cache replaced"
            )
        } catch let api as LimiAPIError {
            if case .httpStatus(404, _) = api {
                hasCompletedInitialPull = true
                replaceLocalWithCloud([], syncedAt: Date())
                lastSyncMessage = "No virtual devices on cloud for this account."
                DeviceConsole.log(.config, "virtual-device GET 404 — local cleared")
            } else {
                lastSyncMessage = api.errorDescription
                DeviceConsole.log(.config, "virtual-device GET FAIL \(api.errorDescription ?? "")")
            }
        } catch {
            lastSyncMessage = error.localizedDescription
            DeviceConsole.log(.config, "virtual-device GET FAIL \(error.localizedDescription)")
        }
    }

    /// Backward-compatible name — pull only (cloud replaces local).
    func syncToBackend() {
        enqueueSync { await self.refreshFromBackend(force: true) }
    }

    func refreshFromBackendIfNeeded() {
        enqueueSync { await self.refreshFromBackend(force: false) }
    }

    // MARK: - Auth / owner

    private func adoptCurrentUserAndPull() {
        let currentOwner = Self.currentOwnerUserKey()
        if currentOwner.isEmpty {
            resetForSignOut()
            return
        }

        reloadFromDisk()
        sanitizeStaleLocalState()

        if ownerUserKey != currentOwner {
            DeviceConsole.log(.config, "virtual-device owner changed — clearing local cache")
            clearInMemoryState()
            ownerUserKey = currentOwner
            deletePersistedRow()
            hasCompletedInitialPull = false
        } else if ownerUserKey.isEmpty {
            ownerUserKey = currentOwner
        }

        enqueueSync { await self.refreshFromBackend(force: true) }
    }

    private static func currentOwnerUserKey() -> String {
        AuthManager.shared.sessionCacheKey()
    }

    // MARK: - Sync queue

    private func enqueueSync(_ work: @escaping () async -> Void) {
        let previous = syncTask
        syncTask = Task {
            _ = await previous?.value
            isSyncing = true
            defer { isSyncing = false }
            await work()
        }
    }

    private func enqueueSyncAndWait(_ work: @escaping () async -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let previous = syncTask
            syncTask = Task {
                _ = await previous?.value
                isSyncing = true
                defer { isSyncing = false }
                await work()
                continuation.resume()
            }
        }
    }

    // MARK: - Push (Bearer token + enabled MAC list)

    private func postGroupUpdate(virtualDeviceId: String, macAddresses: [String]) async {
        let cloudId = virtualDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cloudId.isEmpty else {
            lastSyncMessage = "Cannot save — missing virtual device id."
            DeviceConsole.log(.config, "virtual-device POST skipped — empty id")
            return
        }

        DeviceConsole.log(
            .config,
            "virtual-device POST id=\(cloudId) macs=\(macAddresses.joined(separator: " | "))"
        )

        do {
            let envelope = try await LimiDeviceAPI.postVirtualDevice(
                virtualDeviceId: cloudId,
                macAddresses: macAddresses
            )
            let savedId = envelope.data?.virtual_device_id ?? cloudId
            if !savedId.isEmpty {
                virtualDeviceID = savedId
            }
            lastSyncMessage = envelope.message ?? "Virtual device saved successfully"
            DeviceConsole.log(
                .config,
                "virtual-device POST OK id=\(savedId) macs=\(envelope.data?.mac_addresses.count ?? macAddresses.count)"
            )
        } catch {
            DeviceConsole.log(.config, "virtual-device POST FAIL \(error.localizedDescription)")
            lastSyncMessage = "Cloud save failed — \(error.localizedDescription)"
        }
    }

    private func cloudGroupForMembershipChange(hardwareId: String, enabling: Bool) -> VirtualDeviceRemotePayload? {
        if let existing = remoteGroups.first(where: { group in
            group.mac_addresses.contains {
                LimiDeviceNaming.normalizedHardwareIdFromMAC($0) == hardwareId
            }
        }) {
            return existing
        }

        guard enabling else { return nil }

        // Add to a cloud group that already shares another hub on this phone.
        let localKeys = Set(enabledHardwareIds)
        return remoteGroups.first { group in
            group.mac_addresses.contains { mac in
                localKeys.contains(LimiDeviceNaming.normalizedHardwareIdFromMAC(mac))
            }
        }
    }

    private func normalizedColonMACs(from macAddresses: [String]) -> [String] {
        macAddresses
            .map { LimiDeviceNaming.colonSeparatedMAC(from: LimiDeviceNaming.normalizedHardwareIdFromMAC($0)) }
            .filter { LimiDeviceNaming.normalizedHardwareIdFromMAC($0).count == 12 }
    }

    // MARK: - Remote → local (full replace)

    private func replaceLocalWithCloud(_ remotes: [VirtualDeviceRemotePayload], syncedAt: Date) {
        remoteGroups = remotes
        ownerUserKey = Self.currentOwnerUserKey()

        let allMacs = remotes
            .flatMap(\.mac_addresses)
            .map { LimiDeviceNaming.normalizedHardwareIdFromMAC($0) }
            .filter { !$0.isEmpty }
        enabledHardwareIds = Array(Set(allMacs)).sorted()

        if let primary = remotes.first(where: { !$0.virtual_device_id.isEmpty }) {
            virtualDeviceID = primary.virtual_device_id
        } else {
            virtualDeviceID = ""
        }

        lastSyncedAt = syncedAt
        persist(lastRemoteSyncAt: syncedAt, replaceEntirely: true)
    }

    private func clearInMemoryState() {
        remoteGroups = []
        virtualDeviceID = ""
        enabledHardwareIds = []
        hasCompletedInitialPull = false
        lastSyncedAt = nil
        lastSyncMessage = nil
        ownerUserKey = ""
    }

    private func sanitizeStaleLocalState() {
        // Keep locally enabled hubs + a generated id until the first successful cloud POST/GET.
        // Only drop client UUID-style ids that are clearly not cloud `vd-XXXXXXXX`.
        if !virtualDeviceID.isEmpty,
           !Self.isCloudOriginatedVirtualDeviceID(virtualDeviceID),
           !remoteGroups.contains(where: { $0.virtual_device_id == virtualDeviceID }),
           enabledHardwareIds.isEmpty {
            DeviceConsole.log(.config, "virtual-device clearing unused non-cloud id \(virtualDeviceID)")
            virtualDeviceID = ""
        }
    }

    /// Cloud ids look like `vd-3f8a72c1`. Client-generated ids use full UUIDs (`vd-2f985a5a-e23d-...`).
    private static func isCloudOriginatedVirtualDeviceID(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("vd-"), trimmed.count > 3 else { return false }
        let suffix = String(trimmed.dropFirst(3))
        return !suffix.contains("-")
    }

    // MARK: - Persistence

    private func reloadFromDisk() {
        guard let modelContext else { return }
        let key = VirtualDeviceGroup.primaryKey
        let descriptor = FetchDescriptor<VirtualDeviceGroup>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        guard let row = try? modelContext.fetch(descriptor).first else {
            clearInMemoryState()
            return
        }

        ownerUserKey = row.ownerUserKey
        virtualDeviceID = row.virtualDeviceID
        enabledHardwareIds = row.enabledHardwareIds
        lastSyncedAt = row.lastRemoteSyncAt
        hasCompletedInitialPull = row.lastRemoteSyncAt != nil
        remoteGroups = Self.decodeRemoteGroups(from: row.remoteGroupsJSON)
    }

    private func persist(lastRemoteSyncAt: Date? = nil, replaceEntirely: Bool = false) {
        guard let modelContext else { return }
        let key = VirtualDeviceGroup.primaryKey
        let descriptor = FetchDescriptor<VirtualDeviceGroup>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        let syncStamp = lastRemoteSyncAt ?? lastSyncedAt
        let json = Self.encodeRemoteGroups(remoteGroups)
        let owner = ownerUserKey.isEmpty ? Self.currentOwnerUserKey() : ownerUserKey

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                if replaceEntirely || !virtualDeviceID.isEmpty {
                    existing.virtualDeviceID = virtualDeviceID
                }
                existing.enabledHardwareIds = enabledHardwareIds
                existing.updatedAt = Date()
                existing.ownerUserKey = owner
                existing.remoteGroupsJSON = json
                if let syncStamp {
                    existing.lastRemoteSyncAt = syncStamp
                    lastSyncedAt = syncStamp
                }
            } else {
                let row = VirtualDeviceGroup(
                    virtualDeviceID: virtualDeviceID,
                    enabledHardwareIds: enabledHardwareIds,
                    lastRemoteSyncAt: syncStamp,
                    ownerUserKey: owner,
                    remoteGroupsJSON: json
                )
                modelContext.insert(row)
            }
            try modelContext.save()
        } catch {
            DeviceConsole.log(.config, "virtual-device persist FAIL \(error.localizedDescription)")
        }
    }

    private func deletePersistedRow() {
        guard let modelContext else { return }
        let key = VirtualDeviceGroup.primaryKey
        let descriptor = FetchDescriptor<VirtualDeviceGroup>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        if let row = try? modelContext.fetch(descriptor).first {
            modelContext.delete(row)
            try? modelContext.save()
        }
    }

    private static func encodeRemoteGroups(_ groups: [VirtualDeviceRemotePayload]) -> String {
        let payload = groups.map { group -> [String: Any] in
            [
                "virtual_device_id": group.virtual_device_id,
                "mac_addresses": group.mac_addresses
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func decodeRemoteGroups(from json: String) -> [VirtualDeviceRemotePayload] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict in
            guard let id = dict["virtual_device_id"] as? String else { return nil }
            let macs = dict["mac_addresses"] as? [String] ?? []
            return VirtualDeviceRemotePayload(virtual_device_id: id, mac_addresses: macs)
        }
    }
}
