//
//  DeviceHomeView.swift
//  LIMI AI Device
//
//  Devices home — Bonjour + cloud presence discovery with a smart-home
//  overview layout (featured card, room filters, manage list). Accent is
//  LIMI Emerald; discovery/control paths match ConnectedDevicesView.
//

import SwiftUI
import SwiftData

struct DeviceHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    @ObservedObject private var transportPreference = TransportMediumPreferenceStore.shared
    @ObservedObject private var socket = LightControllingSocket.shared
    @ObservedObject private var bluetooth = BluetoothManager.shared
    @ObservedObject private var userDataManager = UserDataManager.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared
    @ObservedObject private var presenceCoordinator = DevicePresenceCoordinator.shared
    @ObservedObject private var virtualDeviceStore = VirtualDeviceStore.shared
    @ObservedObject private var localSwitchCoordinator = CloudOfflineLocalSwitchCoordinator.shared

    // MARK: - Device state (mirrors ConnectedDevicesView)
    @State private var wifiDevices: [WifiDevice] = []
    /// Home list before virtual-master grouping (Connected Devices / management).
    @State private var rawWifiDevices: [WifiDevice] = []
    @State private var knownWifiDevices: [String: WifiDevice] = [:]
    @State private var allocatedWifiDeviceIds: Set<String> = []
    @State private var uploadedDeviceIds: Set<String> = []

    @State private var selectedDevice: WifiDevice?
    @State private var scheduleDevice: WifiDevice?
    @State private var sequenceTarget: HubSequenceTarget?
    @State private var showAddDevice = false
    @State private var showConfiguredConnected = false
    @State private var showLocalSwitchInbox = false

    // MARK: - Rename (local, SwiftData)
    @State private var renameTargetDevice: WifiDevice?
    @State private var renameInput = ""
    @State private var customDeviceNames: [String: String] = [:]

    // MARK: - Rooms (local, SwiftData)
    @State private var roomAssignments: [String: String] = [:]
    @State private var newRoomTargetDevice: WifiDevice?
    @State private var newRoomInput = ""

    // MARK: - Overview UI
    @State private var selectedRoomFilter: String?
    @State private var featuredDeviceId: String?
    @State private var devicePowerOn: [String: Bool] = [:]
    @State private var selectedMood: DeviceLightMood = .night
    @State private var searchText = ""
    @State private var showSearch = false

    // MARK: - Guidance
    @State private var offlineAlertDevice: WifiDevice?
    @State private var isInitialDiscovery = true
    @State private var groupActionMessage: String?
    @State private var blePresenceRefreshTask: Task<Void, Never>?
    @State private var deleteTargetDevice: WifiDevice?
    @State private var lastHomeListDumpAt: Date = .distantPast

    private var isGuestInstaller: Bool {
        AuthManager.shared.getRole() == "Installer User created"
    }

    private var greetingUserName: String {
        let name = userDataManager.userData?.username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name.split(separator: " ").first.map(String.init) ?? name
        }
        return "there"
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        homeRoot
    }

    /// Keep each chain short — SwiftUI type-checker chokes on one long modifier pile.
    private var homeRoot: some View {
        homeLifecycleScene
    }

    private var homeLifecycleScene: some View {
        homeLifecycleBluetooth
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
    }

    private var homeLifecycleBluetooth: some View {
        homeLifecycleVirtual
            .onChange(of: bluetooth.isConnected) { _, _ in
                refreshDisplayedDevices()
            }
            .onChange(of: bluetooth.isBluetoothOn) { _, _ in
                refreshDisplayedDevices()
            }
            .onChange(of: bluetooth.bleLastSeen) { _, _ in
                scheduleBLEPresenceRefresh()
            }
    }

    private var homeLifecycleVirtual: some View {
        homeLifecycleSocket
            .onChange(of: virtualDeviceStore.enabledHardwareIds) { _, _ in
                refreshDisplayedDevices()
            }
            .onChange(of: virtualDeviceStore.remoteGroups) { _, _ in
                refreshDisplayedDevices()
                requestPresenceRefresh(reason: .homeAppear, force: true)
            }
            .onChange(of: virtualDeviceStore.virtualDeviceID) { _, _ in
                refreshDisplayedDevices()
            }
            .onReceive(NotificationCenter.default.publisher(for: .limiAuthSessionDidChange)) { _ in
                if AuthManager.shared.getToken() != nil {
                    virtualDeviceStore.refreshFromBackendIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .limiDeviceSessionDidChange)) { _ in
                clearHomeListForSessionChange()
            }
    }

    private var homeLifecycleSocket: some View {
        homeLifecyclePresence
            .onChange(of: socket.connectionStatus) { _, status in
                handleSocketStatus(status)
            }
            .onChange(of: presenceCoordinator.isRefreshing) { wasRefreshing, isRefreshing in
                if wasRefreshing, !isRefreshing {
                    refreshDisplayedDevices()
                }
            }
    }

    private var homeLifecyclePresence: some View {
        homeWithAlerts
            .onAppear(perform: handleHomeAppear)
            .onDisappear { bonjourBrowser.stopBrowsing() }
            .onChange(of: presenceCoordinator.powerOffHint) { _, hint in
                guard let hint else { return }
                groupActionMessage = hint
                DeviceAppGuidance.warningNotification()
            }
            .onReceive(bonjourBrowser.$discoveredWiFiDevices) { newDevices in
                processDiscoveredDevices(newDevices)
                if !wifiDevices.isEmpty {
                    isInitialDiscovery = false
                }
            }
            .onReceive(DeviceTransportRegistry.shared.presenceChangePublisher) { update in
                applyCloudPresence(deviceId: update.deviceId, connected: update.connected)
                if update.connected {
                    isInitialDiscovery = false
                }
            }
    }

    private var homeWithAlerts: some View {
        homeWithSheets
            .modifier(DeviceHomeRenameAlertModifier(
                renameTargetDevice: $renameTargetDevice,
                renameInput: $renameInput,
                onSave: {
                    saveCustomDeviceName()
                    renameTargetDevice = nil
                },
                onReset: {
                    renameInput = ""
                    saveCustomDeviceName()
                    renameTargetDevice = nil
                }
            ))
            .modifier(DeviceHomeRoomAlertModifier(
                newRoomTargetDevice: $newRoomTargetDevice,
                newRoomInput: $newRoomInput,
                onCreate: {
                    if let device = newRoomTargetDevice {
                        assignRoom(newRoomInput, to: device)
                    }
                    newRoomTargetDevice = nil
                }
            ))
            .modifier(DeviceHomeOfflineAlertModifier(
                offlineAlertDevice: $offlineAlertDevice,
                onSchedules: {
                    if let device = offlineAlertDevice {
                        scheduleDevice = device
                    }
                    offlineAlertDevice = nil
                }
            ))
            .modifier(DeviceHomeDeleteAlertModifier(
                deleteTargetDevice: $deleteTargetDevice,
                onDelete: {
                    if let device = deleteTargetDevice {
                        deleteConfiguredDevice(device)
                    }
                    deleteTargetDevice = nil
                }
            ))
    }

    private var homeWithSheets: some View {
        homeNavigationRoot
            .sheet(isPresented: $showAddDevice) {
                DeviceAddFlowView()
            }
            .sheet(isPresented: $showConfiguredConnected) {
                configuredConnectedSheet
            }
            .sheet(isPresented: $showLocalSwitchInbox) {
                DeviceLocalSwitchInboxSheet()
            }
            .sheet(item: $selectedDevice) { device in
                selectedDeviceSheet(device)
            }
            .sheet(item: $scheduleDevice) { device in
                scheduleDeviceSheet(device)
            }
            .sheet(item: $sequenceTarget) { target in
                sequenceEditorSheet(target)
            }
    }

    private var homeNavigationRoot: some View {
        NavigationStack {
            Group {
                if isGuestInstaller {
                    guestInstallerUnavailable
                } else {
                    smartHomeOverview
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var guestInstallerUnavailable: some View {
        ContentUnavailableView {
            Label("Sign In Required", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("Please sign in with your account to view and control your Wi-Fi devices.")
        } actions: {
            Button("Sign Out", role: .destructive) {
                AuthManager.shared.clearToken()
            }
            .buttonStyle(.bordered)
        }
    }

    private var configuredConnectedSheet: some View {
        NavigationStack {
            DeviceConfiguredConnectedView(
                items: configuredConnectedPreviewItems,
                managementItems: virtualDeviceManagementItems,
                onOpen: { id in
                    showConfiguredConnected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        openDeviceById(id)
                    }
                },
                onToggle: { toggleVirtualDeviceMembershipById($0) },
                onCreateVirtualDevice: { createVirtualDeviceFromIds($0) },
                onDismiss: { showConfiguredConnected = false }
            )
        }
        .onAppear { refreshConnectedDevicesList() }
    }

    private func selectedDeviceSheet(_ device: WifiDevice) -> some View {
        NavigationStack {
            DeviceControlDestination(device: device, displayName: displayName(for: device))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { selectedDevice = nil }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DeviceSchedulesView(device: device, displayName: displayName(for: device))
                        } label: {
                            Image(systemName: "clock")
                        }
                        .accessibilityLabel("Schedules")
                    }
                }
        }
    }

    private func scheduleDeviceSheet(_ device: WifiDevice) -> some View {
        NavigationStack {
            DeviceSchedulesView(device: device, displayName: displayName(for: device))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { scheduleDevice = nil }
                    }
                }
        }
    }

    private func sequenceEditorSheet(_ target: HubSequenceTarget) -> some View {
        NavigationStack {
            HubSequenceEditorView(target: target) { hardwareId in
                memberSequenceDisplayName(hardwareId: hardwareId, members: target.memberHardwareIds)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func handleHomeAppear() {
        UserDataManager.shared.refreshUserData()
        loadSavedDeviceNames()
        loadRoomAssignments()
        loadSavedPowerStates()
        loadRememberedDevices()
        fetchLinkedDevicesFromCloud()
        seedCloudDevicesFromPresence()
        seedConfiguredBLEDevices()
        virtualDeviceStore.configure(context: modelContext)
        bonjourBrowser.startBrowsing()
        scheduleDiscoveryTimeout()
        refreshDisplayedDevices()
        requestPresenceRefreshIfNeeded()
    }

    private func handleSocketStatus(_ status: LightControllingSocket.ConnectionStatus) {
        // NOTE: the cloud-presence side effects (clear live MQTT on disconnect, BLE/presence
        // re-probe on connect) are owned app-globally by `SocketPresenceLifecycle` so they
        // run on every tab. Here we only do the Home-view UI work (seed rows + rebuild) and
        // must NOT duplicate the clear/refresh — that caused a double clear + a cancelled-and
        // -restarted refresh on every reconnect.
        switch status {
        case .connecting:
            refreshDisplayedDevices()
        case .disconnected:
            refreshDisplayedDevices()
        case .connected:
            seedCloudDevicesFromPresence()
            fetchLinkedDevicesFromCloud()
            refreshDisplayedDevices()
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            bonjourBrowser.startBrowsing()
            requestPresenceRefresh(reason: .homeAppear)
        case .background:
            bonjourBrowser.stopBrowsing()
        default:
            break
        }
    }

    private func scheduleBLEPresenceRefresh() {
        blePresenceRefreshTask?.cancel()
        blePresenceRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            refreshDisplayedDevices()
        }
    }

    private var configuredHardwareIds: Set<String> {
        var ids = configuredHardwareIdsOnPhone()
        for member in virtualDeviceStore.enabledHardwareIds {
            let key = normalizeHardwareId(member)
            if !key.isEmpty { ids.insert(key) }
        }
        for group in virtualDeviceStore.remoteGroups {
            for mac in group.mac_addresses {
                let key = LimiDeviceNaming.normalizedHardwareIdFromMAC(mac)
                if !key.isEmpty {
                    ids.insert(key)
                }
            }
        }
        return ids
    }

    /// Hubs this phone has set up (remembered, BLE, LAN allow, etc.) — used to filter cloud master groups.
    private func configuredHardwareIdsOnPhone() -> Set<String> {
        var ids = Set<String>()

        for device in knownWifiDevices.values {
            let key = normalizeHardwareId(device.chennalMac)
            if isConfiguredOnThisPhone(key) { ids.insert(key) }
        }

        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            let key = normalizeHardwareId(record.hardwareId)
            if !LocallyRemovedDeviceStore.shared.contains(key) {
                ids.insert(key)
            }
        }

        if let rows = try? modelContext.fetch(FetchDescriptor<RememberedLimiDevice>()) {
            for row in rows {
                let key = normalizeHardwareId(row.deviceID)
                if !key.isEmpty, !LocallyRemovedDeviceStore.shared.contains(key) {
                    ids.insert(key)
                }
            }
        }

        return ids
    }

    private func requestPresenceRefreshIfNeeded() {
        let reason: DevicePresenceCoordinator.Reason =
            presenceCoordinator.sessionRefreshCompleted ? .homeAppear : .coldStart
        requestPresenceRefresh(reason: reason)
    }

    private func requestPresenceRefresh(
        reason: DevicePresenceCoordinator.Reason,
        force: Bool = false
    ) {
        presenceCoordinator.requestRefresh(
            deviceIds: configuredHardwareIds,
            reason: reason,
            force: force
        )
    }

    /// Stale-while-revalidate: live paths win; snapshot fills gaps during silent refresh.
    private func resolvedIsOnline(
        hardwareId: String,
        localOnline: Bool,
        cloudOnline: Bool,
        bleOnline: Bool
    ) -> Bool {
        let key = normalizeHardwareId(hardwareId)
        let live = localOnline || cloudOnline || bleOnline
        if live {
            // Only re-record a `.cloud` snapshot when cloud is *live* (fresh heartbeat).
            // A snapshot-derived cloudOnline must NOT rewrite the snapshot — that
            // self-refresh kept "Online · Cloud" alive forever until an app restart.
            let liveCloud = VirtualMasterPresence.isLiveCloudOnline(hardwareId: key)
            if liveCloud {
                PresenceSnapshotStore.shared.record(deviceId: key, isOnline: true, path: .cloud)
            } else if bleOnline {
                PresenceSnapshotStore.shared.record(deviceId: key, isOnline: true, path: .ble)
            } else if localOnline {
                PresenceSnapshotStore.shared.record(deviceId: key, isOnline: true, path: .local)
            }
            // (cloudOnline true but only snapshot-derived: return online for grace, but
            // leave the snapshot untouched so it can age out and flip to BLE/offline.)
            return true
        }

        // Different Wi‑Fi / cloud reconnect: keep last cloud online until TTL expires
        // or a fresh device_status proves offline.
        if socket.isConnected,
           let snap = PresenceSnapshotStore.shared.snapshot(for: key),
           snap.isOnline,
           snap.path == .cloud,
           snap.age <= PresenceSnapshotStore.staleOnlineTTL {
            return true
        }

        if presenceCoordinator.isRefreshing || !presenceCoordinator.sessionRefreshCompleted,
           let snap = PresenceSnapshotStore.shared.snapshot(for: key),
           snap.isOnline,
           snap.age <= PresenceSnapshotStore.staleOnlineTTL {
            return true
        }

        PresenceSnapshotStore.shared.record(deviceId: key, isOnline: false, path: .offline)
        return false
    }

    private func scheduleDiscoveryTimeout() {
        guard isInitialDiscovery else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            isInitialDiscovery = false
        }
    }

    // MARK: - Smart home overview

    /// Room names that currently exist (from assignments), sorted.
    private var knownRooms: [String] {
        Array(Set(roomAssignments.values)).sorted()
    }

    /// Filter chips: only real rooms the user has actually created (no demo placeholders).
    private var filterBarRooms: [String] {
        knownRooms
    }

    private func room(for device: WifiDevice) -> String? {
        roomAssignments[deviceStorageKey(for: device)]
    }

    private func devices(in room: String?) -> [WifiDevice] {
        wifiDevices.filter { self.room(for: $0) == room }
    }

    /// Devices visible for the current room + search filters.
    private var filteredDevices: [WifiDevice] {
        // Ignore a stale room selection that no longer maps to any real room.
        let activeRoomFilter = selectedRoomFilter.flatMap { knownRooms.contains($0) ? $0 : nil }
        return wifiDevices.filter { device in
            if let activeRoomFilter, room(for: device) != activeRoomFilter {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return displayName(for: device).localizedCaseInsensitiveContains(query)
                || (room(for: device)?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Online devices this phone knows and has set up (excludes LAN discovery-only boards).
    private var configuredConnectedDevices: [WifiDevice] {
        wifiDevices.filter { device in
            guard device.isOnline else { return false }
            if device.isVirtualMaster, let members = device.memberChannelMacs {
                return members.contains { isConfiguredOnThisPhone($0) }
            }
            return isConfiguredOnThisPhone(device.chennalMac)
        }
    }

    private var configuredConnectedPreviewItems: [DeviceHomeUIPreviewItem] {
        configuredConnectedDevices.map { device in
            DeviceHomeUIPreviewItem(
                id: device.id,
                name: displayName(for: device),
                subtitle: statusText(for: device),
                isOnline: true,
                isPowerOn: isVirtualDeviceEnabled(for: device)
            )
        }
    }

    /// All configured devices on this phone for virtual-device management (online or offline).
    private var virtualDeviceManagementItems: [DeviceHomeUIPreviewItem] {
        rawWifiDevices
            .filter { isConfiguredOnThisPhone($0.chennalMac) }
            .map { device in
                DeviceHomeUIPreviewItem(
                    id: device.id,
                    name: displayName(for: device),
                    subtitle: device.isOnline ? statusText(for: device) : "Offline",
                    isOnline: device.isOnline,
                    isPowerOn: isVirtualDeviceEnabled(for: device)
                )
            }
    }

    private func isVirtualDeviceEnabled(for device: WifiDevice) -> Bool {
        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            return members.allSatisfy { virtualDeviceStore.isEnabled(hardwareId: $0) }
        }
        return virtualDeviceStore.isEnabled(hardwareId: device.chennalMac)
    }

    private func toggleVirtualDeviceMembershipById(_ id: String) {
        guard let device = wifiDevices.first(where: { $0.id == id }) else { return }
        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            let allEnabled = members.allSatisfy { virtualDeviceStore.isEnabled(hardwareId: $0) }
            let next = !allEnabled
            DeviceAppGuidance.lightImpact()
            for mac in members {
                virtualDeviceStore.setEnabled(next, hardwareId: mac)
            }
            return
        }
        toggleVirtualDeviceMembership(for: device)
    }

    private func toggleVirtualDeviceMembership(for device: WifiDevice) {
        let key = normalizeHardwareId(device.chennalMac)
        guard !key.isEmpty else { return }
        let next = !virtualDeviceStore.isEnabled(hardwareId: key)
        DeviceAppGuidance.lightImpact()
        virtualDeviceStore.setEnabled(next, hardwareId: key)
    }

    /// Resolves selected management-item ids to hardware MACs and creates a brand-new
    /// virtual device (fresh `vd-` id) — never merges into an existing group.
    private func createVirtualDeviceFromIds(_ ids: [String]) {
        let idSet = Set(ids)
        var macs: [String] = []
        for device in rawWifiDevices where idSet.contains(device.id) {
            if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
                macs.append(contentsOf: members.map { normalizeHardwareId($0) })
            } else {
                macs.append(normalizeHardwareId(device.chennalMac))
            }
        }
        let unique = Array(Set(macs.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return }
        DeviceAppGuidance.lightImpact()
        virtualDeviceStore.createVirtualDevice(hardwareIds: unique)
    }

    /// Opens Connected Devices sheet after refreshing live presence (Cloud / BLE / Local).
    private func openConfiguredConnectedSheet() {
        DeviceAppGuidance.lightImpact()
        refreshConnectedDevicesList()
        showConfiguredConnected = true
    }

    /// Re-checks which configured boards are live right now before showing the sheet.
    private func refreshConnectedDevicesList() {
        refreshDisplayedDevices()
        requestPresenceRefreshIfNeeded()
        virtualDeviceStore.refreshFromBackendIfNeeded()
        if let browser = bonjourBrowser as? BonjourServiceBrowser {
            browser.collapseDuplicateDevices(reason: "Connected Devices sheet")
        }
        let live = configuredConnectedDevices
        DeviceConsole.log(.home, "Connected Devices sheet — \(live.count) live configured")
        for device in live {
            DeviceConsole.log(
                .home,
                "  • \(displayName(for: device)) id=\(normalizeHardwareId(device.chennalMac)) \(statusText(for: device))"
            )
        }
    }

    /// True when this phone has set up or engaged with the board (not a transient LAN discovery).
    private func isConfiguredOnThisPhone(_ hardwareId: String) -> Bool {
        let key = normalizeHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        if LocallyRemovedDeviceStore.shared.contains(key) { return false }

        if ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: key) { return true }
        if LocalNetworkAllowStore.shared.isAllowed(for: key) { return true }
        if customDeviceNames[key] != nil { return true }
        if roomAssignments[key] != nil { return true }
        if DevicePowerMemoryStore.shared.isOn(for: key) != nil { return true }

        guard hasRememberedDevice(key) else { return false }
        return isCloudOnline(key)
    }

    private func hasRememberedDevice(_ hardwareId: String) -> Bool {
        let key = normalizeHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        let descriptor = FetchDescriptor<RememberedLimiDevice>(
            predicate: #Predicate { $0.deviceID == key }
        )
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private var featuredDevice: WifiDevice? {
        if let featuredDeviceId,
           let match = filteredDevices.first(where: { $0.id == featuredDeviceId }) {
            return match
        }
        return filteredDevices.first(where: \.isOnline) ?? filteredDevices.first
    }

    private func openDeviceById(_ id: String) {
        guard let device = wifiDevices.first(where: { $0.id == id }) else { return }
        openDevice(device)
    }

    private var smartHomeOverview: some View {
        ZStack {
            HomeUI1AnimatedCanvas()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    DeviceSmartHomeHeader(
                        userName: greetingUserName,
                        greeting: timeGreeting,
                        avatarImage: userDataManager.profileImage,
                        onNotifications: { showLocalSwitchInbox = true },
                        onConnectedDevices: { openConfiguredConnectedSheet() },
                        showsNotificationBadge: localSwitchCoordinator.hasUnreadLocalSwitchOffer
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    DeviceSmartHomeTitleRow(
                        isSearching: $showSearch,
                        searchText: $searchText
                    )
                    .padding(.horizontal, 20)

                    if socket.connectionStatus != .connected {
                        DeviceConnectionBanner()
                            .padding(.horizontal, 20)
                    }

                    if let groupActionMessage {
                        Text(groupActionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    if !filterBarRooms.isEmpty {
                        DeviceRoomFilterBar(
                            rooms: filterBarRooms,
                            selectedRoom: $selectedRoomFilter
                        )
                    }

                    overviewBody
                        .padding(.horizontal, 20)

                    Text(controlPathFooter)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: socket.connectionStatus)
        .animation(.snappy(duration: 0.25), value: groupActionMessage)
        .animation(.snappy(duration: 0.25), value: filteredDevices.map(\.id))
        .onChange(of: filteredDevices.map(\.id)) { _, ids in
            if let featuredDeviceId, !ids.contains(featuredDeviceId) {
                self.featuredDeviceId = ids.first
            } else if featuredDeviceId == nil {
                featuredDeviceId = ids.first
            }
        }
    }

    @ViewBuilder
    private var overviewBody: some View {
        if wifiDevices.isEmpty && isInitialDiscovery {
            overviewEmptyState(
                title: "Looking for Devices",
                message: DeviceAppGuidance.lookingForDevices,
                showsProgress: true
            )
        } else if filteredDevices.isEmpty {
            overviewEmptyState(
                title: wifiDevices.isEmpty ? "No Devices" : "No Matches",
                message: wifiDevices.isEmpty
                    ? DeviceAppGuidance.emptyDevices
                    : "No devices in this room. Try All or add a device.",
                showsProgress: false
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if let featured = featuredDevice {
                    DeviceFeaturedCard(
                        name: displayName(for: featured),
                        subtitle: featuredSubtitle(for: featured),
                        isOnline: featured.isOnline,
                        isPowerOn: isPowerOn(for: featured),
                        channelTypes: featured.channelTypes,
                        selectedMood: selectedMood,
                        onTogglePower: { togglePower(for: featured) },
                        onSelectMood: { applyMood($0, to: featured) },
                        onOpen: { openDevice(featured) }
                    )
                    .contextMenu { deviceContextMenu(for: featured) }
                    .onAppear { registerUploadIfNeeded(featured) }
                }

                DeviceManageSectionHeader {
                    showAddDevice = true
                }
                .padding(.top, 4)

                LazyVStack(spacing: 12) {
                    ForEach(filteredDevices) { device in
                        DeviceManageRowCard(
                            name: displayName(for: device),
                            subtitle: manageSubtitle(for: device),
                            isOnline: device.isOnline,
                            isPowerOn: isPowerOn(for: device),
                            statusBadge: nil,
                            onTogglePower: { togglePower(for: device) },
                            onOpen: {
                                featuredDeviceId = device.id
                                openDevice(device)
                            }
                        )
                        .contextMenu { deviceContextMenu(for: device) }
                        .onAppear { registerUploadIfNeeded(device) }
                    }
                }

                if !knownRooms.isEmpty {
                    roomsQuickLinks
                }
            }
        }
    }

    private var roomsQuickLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rooms")
                .font(HomeUI1Type.title(18))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .padding(.top, 8)

            ForEach(knownRooms, id: \.self) { roomName in
                let roomDevices = devices(in: roomName)
                NavigationLink {
                    RoomControlView(
                        roomName: roomName,
                        allDevices: wifiDevices,
                        roomAssignments: roomAssignments,
                        displayNameProvider: { displayName(for: $0) },
                        statusTextProvider: { statusText(for: $0) }
                    )
                } label: {
                    RoomGroupCard(
                        roomName: roomName,
                        deviceCount: roomDevices.count,
                        onlineCount: roomDevices.filter(\.isOnline).count,
                        style: .homeUI1
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        setRoomPower(devices: roomDevices, on: true)
                    } label: {
                        Label("All On", systemImage: "lightbulb.fill")
                    }
                    .disabled(roomDevices.filter(\.isOnline).isEmpty)
                    Button {
                        setRoomPower(devices: roomDevices, on: false)
                    } label: {
                        Label("All Off", systemImage: "lightbulb.slash")
                    }
                    .disabled(roomDevices.filter(\.isOnline).isEmpty)
                }
            }
        }
    }

    private func overviewEmptyState(title: String, message: String, showsProgress: Bool) -> some View {
        HomeUI1EmptyStateCard(
            title: title,
            message: message,
            showsProgress: showsProgress,
            onAdd: showsProgress ? nil : { showAddDevice = true }
        )
    }

    @ViewBuilder
    private func deviceContextMenu(for device: WifiDevice) -> some View {
        Button {
            beginRenaming(device)
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            scheduleDevice = device
        } label: {
            Label("Schedules", systemImage: "clock")
        }
        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            Button {
                sequenceTarget = HubSequenceTarget(
                    id: virtualDeviceId(for: device),
                    displayName: displayName(for: device),
                    memberHardwareIds: members
                )
            } label: {
                Label("Sequence", systemImage: "list.number")
            }
        }
        Button {
            featuredDeviceId = device.id
        } label: {
            Label("Feature on Home", systemImage: "star")
        }
        roomMenu(for: device)
        Divider()
        Button(role: .destructive) {
            deleteTargetDevice = device
        } label: {
            Label("Delete Device", systemImage: "trash")
        }
    }

    private func deleteConfiguredDevice(_ device: WifiDevice) {
        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            ConfiguredDeviceRemoval.removeVirtualMasterFromAppStore(
                memberHardwareIds: members,
                modelContext: modelContext
            )
            if featuredDeviceId == device.id {
                featuredDeviceId = nil
            }
            if selectedDevice?.id == device.id {
                selectedDevice = nil
            }
            refreshDisplayedDevices()
            if featuredDeviceId == nil {
                featuredDeviceId = filteredDevices.first?.id
            }
            groupActionMessage = "Master device hidden for this account"
            DeviceAppGuidance.successNotification()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if groupActionMessage == "Master device hidden for this account" {
                    groupActionMessage = nil
                }
            }
            return
        }

        let key = normalizeHardwareId(device.chennalMac)
        guard !key.isEmpty else { return }

        let bleUUID = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: key)
            ?? (device.uuid != key ? device.uuid : nil)

        ConfiguredDeviceRemoval.removeFromAppStore(
            hardwareId: key,
            blePeripheralUUID: bleUUID,
            modelContext: modelContext
        )

        if featuredDeviceId == device.id || featuredDeviceId == key {
            featuredDeviceId = nil
        }
        if selectedDevice?.id == device.id {
            selectedDevice = nil
        }
        if scheduleDevice?.id == device.id {
            scheduleDevice = nil
        }

        refreshDisplayedDevices()
        if featuredDeviceId == nil {
            featuredDeviceId = filteredDevices.first?.id
        }
        groupActionMessage = "Device hidden for this account"
        DeviceAppGuidance.successNotification()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if groupActionMessage == "Device hidden for this account" {
                groupActionMessage = nil
            }
        }
    }

    private func featuredSubtitle(for device: WifiDevice) -> String {
        if let roomName = room(for: device), !roomName.isEmpty {
            return "Connected to \(roomName)"
        }
        return statusText(for: device)
    }

    private func manageSubtitle(for device: WifiDevice) -> String {
        if device.isVirtualMaster {
            let pendants = device.chennalCount == 1 ? "1 pendant" : "\(device.chennalCount) pendants"
            return "\(pendants) · \(statusText(for: device))"
        }
        let channels = device.chennalCount == 1 ? "1 channel" : "\(device.chennalCount) channels"
        let types = Set(device.channelTypes).sorted().joined(separator: "/")
        var parts = [types.isEmpty ? channels : "\(channels) · \(types)"]
        if let roomName = room(for: device), !roomName.isEmpty {
            parts.append(roomName)
        }
        parts.append(statusText(for: device))
        return parts.joined(separator: " · ")
    }

    private func powerPreferenceKey(for device: WifiDevice) -> String {
        normalizeHardwareId(deviceStorageKey(for: device))
    }

    private func isPowerOn(for device: WifiDevice) -> Bool {
        let key = powerPreferenceKey(for: device)
        if let stored = devicePowerOn[key] { return stored }
        if let persisted = DevicePowerMemoryStore.shared.isOn(for: key) { return persisted }
        // Hub: derive from members when hub itself has no stored state yet.
        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            return members.contains { memberMac in
                let memberKey = normalizeHardwareId(memberMac)
                if let stored = devicePowerOn[memberKey] { return stored }
                return DevicePowerMemoryStore.shared.isOn(for: memberKey) ?? false
            }
        }
        return false
    }

    private func rememberPowerState(for device: WifiDevice, on: Bool) {
        let key = powerPreferenceKey(for: device)
        devicePowerOn[key] = on
        DevicePowerMemoryStore.shared.setOn(on, for: key)
    }

    private func rememberPowerState(hardwareId: String, on: Bool) {
        let key = normalizeHardwareId(hardwareId)
        guard !key.isEmpty else { return }
        devicePowerOn[key] = on
        DevicePowerMemoryStore.shared.setOn(on, for: key)
    }

    private func loadSavedPowerStates() {
        for device in wifiDevices {
            let key = powerPreferenceKey(for: device)
            guard devicePowerOn[key] == nil else { continue }
            if let saved = DevicePowerMemoryStore.shared.isOn(for: key) {
                devicePowerOn[key] = saved
            }
        }
    }

    private func openDevice(_ device: WifiDevice) {
        DeviceAppGuidance.lightImpact()
        featuredDeviceId = device.id
        selectedDevice = device
    }

    /// Home card power toggle — individual boards via LimiTransport;
    /// Hub OFF → `virtual_light_control`; Hub ON → fan-out to all member MACs.
    private func togglePower(for device: WifiDevice) {
        if device.isVirtualMaster {
            toggleHubPower(for: device)
            return
        }
        toggleIndividualPower(for: device)
    }

    private func toggleIndividualPower(for device: WifiDevice) {
        guard device.isOnline else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
            return
        }
        let next = !isPowerOn(for: device)
        rememberPowerState(for: device, on: next)
        DeviceAppGuidance.lightImpact()
        sendIndividualPower(to: device, on: next)
    }

    private func toggleHubPower(for device: WifiDevice) {
        guard device.isOnline else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
            return
        }
        let members = (device.memberChannelMacs ?? [])
            .map { normalizeHardwareId($0) }
            .filter { !$0.isEmpty }
        guard !members.isEmpty else {
            groupActionMessage = "Hub has no member devices"
            DeviceAppGuidance.warningNotification()
            return
        }

        let next = !isPowerOn(for: device)
        DeviceAppGuidance.lightImpact()
        rememberPowerState(for: device, on: next)
        for mac in members {
            rememberPowerState(hardwareId: mac, on: next)
        }

        if next {
            sendHubPowerOn(memberIds: members, hub: device)
        } else {
            sendHubPowerOff(hub: device, memberIds: members)
        }
    }

    private func virtualDeviceId(for hub: WifiDevice) -> String {
        VirtualDeviceHomeGrouping.virtualDeviceId(from: hub)
    }

    /// OFF: one hub message so backend fans out / master board handles group off.
    private func sendHubPowerOff(hub: WifiDevice, memberIds: [String]) {
        let virtualId = virtualDeviceId(for: hub)
        let command: LimiCommand = .power(channel: 1, on: false)
        LightControllingSocket.shared.connect()

        Task { @MainActor in
            if LightControllingSocket.shared.connectionStatus != .connected {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }

            if !virtualId.isEmpty, LightControllingSocket.shared.connectionStatus == .connected {
                LightControllingSocket.shared.sendVirtualLightControl(
                    virtualDeviceId: virtualId,
                    command: command.toVirtualCommandPayload()
                )
                DeviceConsole.log(.home, "hub power OFF → virtual_light_control id=\(virtualId)")
                DeviceAppGuidance.successNotification()
                return
            }

            do {
                try await LimiTransport.shared.sendGroupCommand(command, deviceIds: memberIds)
                DeviceConsole.log(.home, "hub power OFF → group_light_control members=\(memberIds.count)")
                DeviceAppGuidance.successNotification()
            } catch {
                rememberPowerState(for: hub, on: true)
                for mac in memberIds { rememberPowerState(hardwareId: mac, on: true) }
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    /// ON: turn every member on (group fan-out). Does not depend on local member rows.
    private func sendHubPowerOn(memberIds: [String], hub: WifiDevice) {
        let command: LimiCommand = .cct(channel: 1, brightness: 70, ww: 100, cw: 40)
        LightControllingSocket.shared.connect()

        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendGroupCommand(command, deviceIds: memberIds)
                DeviceConsole.log(.home, "hub power ON → group_light_control members=\(memberIds.count)")
                DeviceAppGuidance.successNotification()
            } catch {
                var anySuccess = false
                for mac in memberIds {
                    do {
                        try await LimiTransport.shared.sendCommand(command, for: mac)
                        anySuccess = true
                    } catch {
                        DeviceConsole.log(.home, "hub power ON member \(mac) failed: \(error.localizedDescription)")
                    }
                }
                if anySuccess {
                    DeviceAppGuidance.successNotification()
                } else {
                    rememberPowerState(for: hub, on: false)
                    for mac in memberIds { rememberPowerState(hardwareId: mac, on: false) }
                    groupActionMessage = DeviceAppGuidance.message(for: error)
                    DeviceAppGuidance.warningNotification()
                }
            }
        }
    }

    /// Hub preset (mood): same path as the hub control screen — one `virtual_light_control`
    /// to the hub's virtual device id. Falls back to a group fan-out when no virtual id exists.
    private func sendHubMood(_ mood: DeviceLightMood, hub: WifiDevice, memberIds: [String]) {
        let virtualId = virtualDeviceId(for: hub)
        let command = mood.command
        LightControllingSocket.shared.connect()

        Task { @MainActor in
            if LightControllingSocket.shared.connectionStatus != .connected {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }

            if !virtualId.isEmpty, LightControllingSocket.shared.connectionStatus == .connected {
                LightControllingSocket.shared.sendVirtualLightControl(
                    virtualDeviceId: virtualId,
                    command: command.toVirtualCommandPayload()
                )
                DeviceConsole.log(.home, "hub mood \(mood.rawValue) → virtual_light_control id=\(virtualId)")
                DeviceAppGuidance.successNotification()
                return
            }

            do {
                try await LimiTransport.shared.sendGroupCommand(command, deviceIds: memberIds)
                DeviceConsole.log(.home, "hub mood \(mood.rawValue) → group_light_control members=\(memberIds.count)")
                DeviceAppGuidance.successNotification()
            } catch {
                rememberPowerState(for: hub, on: false)
                for mac in memberIds { rememberPowerState(hardwareId: mac, on: false) }
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    private func applyMood(_ mood: DeviceLightMood, to device: WifiDevice) {
        guard device.isOnline else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
            return
        }
        selectedMood = mood
        rememberPowerState(for: device, on: true)
        DeviceAppGuidance.lightImpact()

        if device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty {
            let ids = members.map { normalizeHardwareId($0) }.filter { !$0.isEmpty }
            for mac in ids { rememberPowerState(hardwareId: mac, on: true) }
            sendHubMood(mood, hub: device, memberIds: ids)
            return
        }

        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendCommand(mood.command, for: device.chennalMac)
                DeviceAppGuidance.successNotification()
            } catch {
                rememberPowerState(for: device, on: false)
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    private func sendIndividualPower(to device: WifiDevice, on: Bool) {
        let command: LimiCommand = on
            ? .cct(channel: 1, brightness: 70, ww: 100, cw: 40)
            : .power(channel: 1, on: false)
        let key = normalizeHardwareId(device.chennalMac)
        LightControllingSocket.shared.connect()
        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendCommand(command, for: key)
                DeviceConsole.log(.home, "device power \(on ? "ON" : "OFF") → \(key)")
                DeviceAppGuidance.successNotification()
            } catch {
                rememberPowerState(for: device, on: !on)
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    private func registerUploadIfNeeded(_ device: WifiDevice) {
        guard !uploadedDeviceIds.contains(device.chennalMac) else { return }
        uploadedDeviceIds.insert(device.chennalMac)
        sendDeviceToBackend(device: device)
    }

    /// "Room" submenu: move to an existing room, create a new one, or remove.
    private func roomMenu(for device: WifiDevice) -> some View {
        Menu {
            ForEach(knownRooms, id: \.self) { room in
                Button {
                    assignRoom(room, to: device)
                } label: {
                    if self.room(for: device) == room {
                        Label(room, systemImage: "checkmark")
                    } else {
                        Text(room)
                    }
                }
            }

            if !knownRooms.isEmpty { Divider() }

            Button {
                newRoomInput = ""
                newRoomTargetDevice = device
            } label: {
                Label("New Room…", systemImage: "plus")
            }

            if room(for: device) != nil {
                Button(role: .destructive) {
                    assignRoom(nil, to: device)
                } label: {
                    Label("Remove from Room", systemImage: "minus.circle")
                }
            }
        } label: {
            Label("Room", systemImage: "square.split.bottomrightquarter")
        }
    }

    // MARK: - Room group control

    /// Quick All On/Off from the room card — same group_light_control path as RoomControl.
    private func setRoomPower(devices: [WifiDevice], on: Bool) {
        let ids = devices
            .filter(\.isOnline)
            .map { LimiDeviceNaming.normalizedHardwareId($0.chennalMac) }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else {
            groupActionMessage = DeviceAppGuidance.noOnlineInRoom
            DeviceAppGuidance.warningNotification()
            return
        }

        let command: LimiCommand = on
            ? .cct(channel: 1, brightness: 70, ww: 100, cw: 40)
            : .power(channel: 1, on: false)

        Task { @MainActor in
            groupActionMessage = "Sending…"
            do {
                try await LimiTransport.shared.sendGroupCommand(
                    command,
                    groupId: LimiCommand.defaultGroupID,
                    deviceIds: ids
                )
                groupActionMessage = on ? "Room lights on" : "Room lights off"
                DeviceAppGuidance.successNotification()
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if groupActionMessage == (on ? "Room lights on" : "Room lights off") {
                    groupActionMessage = nil
                }
            } catch {
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    private var controlPathFooter: String {
        transportPreference.preference == .automatic
            ? "Checks MQTT, then Bluetooth. Local network needs your permission. Listed devices stay Offline until live."
            : "Testing mode — commands always use \(transportPreference.preference.shortTitle)."
    }

    // MARK: - Bonjour + cloud presence (Case 3)

    private func processDiscoveredDevices(_ newDevices: [BLEDevice]) {
        let filtered = newDevices.filter { LimiDeviceNaming.isAllowedDeviceName($0.name) }
        let currentUUIDs = Set(filtered.map(\.uuid))

        for dev in filtered {
            let mapped = wifiDevice(from: dev)
            let hardwareKey = normalizeHardwareId(mapped.chennalMac)
            // User deleted this device — only bring it back when Bonjour sees it live again.
            if LocallyRemovedDeviceStore.shared.contains(hardwareKey) {
                if mapped.isOnline || dev.reachability == .online {
                    LocallyRemovedDeviceStore.shared.clearRemoved(hardwareKey)
                } else {
                    continue
                }
            }
            knownWifiDevices[dev.uuid] = mapped
            rememberDevice(mapped)

            if dev.reachability == .online,
               let txt = dev.txtRecord,
               let deviceId = txt["deviceId"],
               !allocatedWifiDeviceIds.contains(deviceId) {
                allocatedWifiDeviceIds.insert(deviceId)
                DeviceAllocationService.shared.allocateDevice(deviceId: deviceId)
            }
        }

        // Devices no longer seen on Bonjour: keep listed; local bit off unless cloud is on.
        for (uuid, device) in knownWifiDevices where !currentUUIDs.contains(uuid) {
            var copy = device
            copy.isOnline = false
            knownWifiDevices[uuid] = copy
        }

        refreshDisplayedDevices()
    }

    private func applyCloudPresence(deviceId: String, connected: Bool) {
        let key = normalizeHardwareId(deviceId)
        guard !key.isEmpty else { return }
        if LocallyRemovedDeviceStore.shared.contains(key) {
            // Do not resurrect a user-deleted device from a stale/live presence event alone.
            return
        }
        DeviceConsole.log(.home, "presence event id=\(key) connected=\(connected) → refresh list")

        if connected {
            PresenceSnapshotStore.shared.record(deviceId: key, isOnline: true, path: .cloud)
        } else {
            PresenceSnapshotStore.shared.record(deviceId: key, isOnline: false, path: .offline)
        }

        ensureKnownDeviceStub(
            hardwareId: key,
            displayName: customDeviceNames[key],
            remember: connected
        )
        refreshDisplayedDevices()
    }

    /// Case 3: rebuild cloud rows from known ids (list only — Online stays live-gated).
    private func seedCloudDevicesFromPresence() {
        DeviceTransportRegistry.shared.restorePersistedPresenceIfNeeded()

        var ids = Set(DeviceTransportRegistry.shared.presenceSnapshot().map(\.deviceId))
        for id in CloudPresenceMemory.shared.knownDeviceIds() {
            ids.insert(normalizeHardwareId(id))
        }
        for id in ids where !id.isEmpty {
            if LocallyRemovedDeviceStore.shared.contains(id) { continue }
            ensureKnownDeviceStub(
                hardwareId: id,
                displayName: customDeviceNames[id],
                remember: true
            )
        }
        refreshDisplayedDevices()
        if !wifiDevices.isEmpty {
            isInitialDiscovery = false
        }
    }

    /// Ensures a list row exists for a hardware id (remote / remembered / presence).
    private func ensureKnownDeviceStub(
        hardwareId key: String,
        displayName: String?,
        remember: Bool
    ) {
        guard !key.isEmpty else { return }
        if LocallyRemovedDeviceStore.shared.contains(key) { return }
        if let existing = knownWifiDevices.first(where: {
            normalizeHardwareId($0.value.chennalMac) == key
        }) {
            if remember {
                rememberDevice(existing.value)
            }
            return
        }
        let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? key
        let stub = WifiDevice(
            id: key,
            uuid: key,
            chennalMac: key,
            chennalCount: 1,
            channelTypes: ["CCT"],
            deviceName: name,
            isOnline: false
        )
        knownWifiDevices[key] = stub
        if remember {
            rememberDevice(stub)
        }
    }

    private func refreshDisplayedDevices() {
        // Dedupe by hardware MAC so Bonjour uuid + cloud MAC stubs don't double-list.
        var byHardware: [String: WifiDevice] = [:]
        for device in knownWifiDevices.values {
            let key = normalizeHardwareId(device.chennalMac)
            guard !key.isEmpty else { continue }

            let localOnline = isLocalOnline(device)
            let cloudOnline = isCloudOnline(device.chennalMac)
            let bleOnline = isBLEOnline(device.chennalMac)
            var copy = device
            copy.isOnline = resolvedIsOnline(
                hardwareId: key,
                localOnline: localOnline,
                cloudOnline: cloudOnline,
                bleOnline: bleOnline
            )

            if let existing = byHardware[key] {
                let existingIsBonjour = existing.id != key
                let currentIsBonjour = copy.id != key
                if currentIsBonjour && !existingIsBonjour {
                    copy.isOnline = copy.isOnline || existing.isOnline
                    byHardware[key] = copy
                } else {
                    let useChannels = copy.chennalCount > existing.chennalCount
                    let useName = !copy.deviceName.isEmpty
                        && (existing.deviceName == key || existing.deviceName.count < copy.deviceName.count)
                    byHardware[key] = WifiDevice(
                        id: existing.id,
                        uuid: existing.uuid,
                        chennalMac: existing.chennalMac,
                        chennalCount: useChannels ? copy.chennalCount : existing.chennalCount,
                        channelTypes: useChannels ? copy.channelTypes : existing.channelTypes,
                        deviceName: useName ? copy.deviceName : existing.deviceName,
                        isOnline: existing.isOnline || copy.isOnline
                    )
                }
            } else {
                byHardware[key] = copy
            }
        }

        let sorted = byHardware.values.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
        rawWifiDevices = sorted

        for group in virtualDeviceStore.remoteGroups {
            for mac in group.mac_addresses {
                let key = LimiDeviceNaming.normalizedHardwareIdFromMAC(mac)
                guard !key.isEmpty else { continue }
                _ = DeviceTransportRegistry.shared.state(for: key)
            }
        }

        wifiDevices = applyMasterPresence(
            to: VirtualDeviceHomeGrouping.apply(
                devices: sorted,
                groups: virtualDeviceStore.cloudHomeGroupingSpecs()
            )
        )
        loadSavedPowerStates()

        let now = Date()
        guard now.timeIntervalSince(lastHomeListDumpAt) >= 10.0 else { return }
        lastHomeListDumpAt = now
        let dump = wifiDevices.map { device -> (name: String, hardwareId: String, online: Bool, configured: Bool) in
            let key = normalizeHardwareId(device.chennalMac)
            return (
                name: displayName(for: device),
                hardwareId: key,
                online: device.isOnline,
                configured: isConfiguredOnThisPhone(key)
            )
        }
        DeviceConsole.dumpHomeList(reason: "refreshDisplayedDevices", devices: dump)
    }

    private func isCloudOnline(_ deviceId: String) -> Bool {
        VirtualMasterPresence.effectiveCloudOnline(hardwareId: deviceId)
    }

    private func isLocalOnline(_ device: WifiDevice) -> Bool {
        let key = normalizeHardwareId(device.chennalMac)
        // Bonjour/WS Online only after user allowed local network for this device.
        guard LocalNetworkAllowStore.shared.isAllowed(for: key) else { return false }
        if let raw = knownWifiDevices[device.id] {
            return raw.isOnline
        }
        return DeviceTransportRegistry.shared.state(for: key).wifiConnected
    }

    /// BLE Online: live GATT connection, or a recent advertisement.
    /// Connected hubs often stop advertising — do not require ads in that case.
    /// Cache-only / powered-off boards stay Offline.
    private func isBLEOnline(_ deviceId: String) -> Bool {
        let key = normalizeHardwareId(deviceId)
        guard !key.isEmpty else { return false }
        // isCloudOnline is freshness-aware: a stale cloud hub reports false here so BLE
        // can take over. (No separate raw mqttConnected gate — that kept BLE suppressed
        // while a dropped hub's mqttConnected stayed stale-true.)
        if isCloudOnline(key) { return false }
        guard bluetooth.isBluetoothOn else { return false }
        guard let bleUUID = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: key) else {
            return false
        }
        if bluetooth.isLiveConnected(forPeripheralUUID: bleUUID) { return true }
        if bluetooth.isReady(forPeripheralUUID: bleUUID) { return true }
        return bluetooth.hasRecentAdvertisement(forPeripheralUUID: bleUUID, within: 15)
    }

    private func statusText(for device: WifiDevice) -> String {
        if device.isVirtualMaster, let members = device.memberChannelMacs {
            return masterStatusText(memberHardwareIds: members)
        }
        let cloud = isCloudOnline(device.chennalMac)
        let local = isLocalOnline(device)
        let ble = isBLEOnline(device.chennalMac)

        // Priority labels: Cloud → BLE → Local (Bonjour after allow).
        if cloud { return "Online · Cloud" }
        if ble { return "Online · BLE" }
        if local { return "Online · Local" }
        return "Offline"
    }

    private func masterStatusText(memberHardwareIds: [String]) -> String {
        VirtualMasterPresence.masterCardCloudStatusLabel(memberHardwareIds: memberHardwareIds)
    }

    /// Re-sync master row flags from backend `device_status` (all offline → card offline).
    private func applyMasterPresence(to devices: [WifiDevice]) -> [WifiDevice] {
        devices.map { device in
            guard device.isVirtualMaster, let members = device.memberChannelMacs, !members.isEmpty else {
                return device
            }
            var copy = device
            copy.isOnline = VirtualMasterPresence.isAnyMemberCloudOnline(memberHardwareIds: members)
            return copy
        }
    }

    private func memberIsOnline(_ hardwareId: String) -> Bool {
        let key = normalizeHardwareId(hardwareId)
        guard !key.isEmpty else { return false }
        if isCloudOnline(key) { return true }
        if let row = knownWifiDevices.values.first(where: {
            normalizeHardwareId($0.chennalMac) == key
        }) {
            if isLocalOnline(row) { return true }
        }
        return isBLEOnline(key)
    }

    /// Keep configured BLE hubs in the list even when Bonjour/cloud are quiet.
    private func seedConfiguredBLEDevices() {
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            if LocallyRemovedDeviceStore.shared.contains(record.hardwareId) { continue }
            ensureKnownDeviceStub(
                hardwareId: record.hardwareId,
                displayName: record.displayName.isEmpty ? nil : record.displayName,
                remember: true
            )
        }
        refreshDisplayedDevices()
    }

    private func normalizeHardwareId(_ deviceId: String) -> String {
        LimiDeviceNaming.normalizedHardwareId(deviceId)
    }

    private func wifiDevice(from dev: BLEDevice) -> WifiDevice {
        var channelCount = 1
        var channelTypes: [String] = ["CCT"]
        var mac = dev.uuid
        if let txt = dev.txtRecord {
            if let s = txt["channelCount"], let c = Int(s) { channelCount = c }
            if let p = txt["channelTypes"] {
                let types = p
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                    .filter { $0 == "CCT" || $0 == "RGB" }
                if !types.isEmpty { channelTypes = types }
            }
            if let m = txt["deviceId"] { mac = m }
        }
        return WifiDevice(
            id: dev.uuid,
            uuid: dev.uuid,
            chennalMac: mac,
            chennalCount: channelCount,
            channelTypes: channelTypes,
            deviceName: dev.name,
            isOnline: dev.reachability == .online
        )
    }

    private func sendDeviceToBackend(device: WifiDevice) {
        let body: [String: Any] = [
            "deviceId": device.chennalMac,
            "metadata": [
                "uuid": device.uuid,
                "chennalMac": device.chennalMac,
                "chennalCount": device.chennalCount,
                "channelTypes": device.channelTypes,
                "deviceName": device.deviceName,
                "isOnline": device.isOnline
            ]
        ]
        LimiDeviceAPI.postDeviceUser(body: body, logPrefix: "DeviceApp") { _, _, _ in }
    }

    // MARK: - Remembered + linked devices (Case 3 seed)

    /// Previous account's Home RAM + SwiftData remembered hubs — not rooms/schedules/theme.
    private func clearHomeListForSessionChange() {
        knownWifiDevices.removeAll()
        wifiDevices = []
        rawWifiDevices = []
        allocatedWifiDeviceIds.removeAll()
        uploadedDeviceIds.removeAll()
        devicePowerOn.removeAll()
        featuredDeviceId = nil
        selectedDevice = nil
        deleteRememberedDevices()
        refreshDisplayedDevices()
    }

    private func deleteRememberedDevices() {
        let descriptor = FetchDescriptor<RememberedLimiDevice>()
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        for row in rows {
            modelContext.delete(row)
        }
        try? modelContext.save()
    }

    private func loadRememberedDevices() {
        let descriptor = FetchDescriptor<RememberedLimiDevice>()
        guard let rows = try? modelContext.fetch(descriptor) else { return }

        // Phone-global SwiftData can still hold the previous account's hubs if
        // Home was not mounted at logout. Only keep rows that belong to this
        // session (configured BLE or this user's virtual groups).
        var allowed = Set<String>()
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            let key = normalizeHardwareId(record.hardwareId)
            if !key.isEmpty { allowed.insert(key) }
        }
        for member in virtualDeviceStore.enabledHardwareIds {
            let key = normalizeHardwareId(member)
            if !key.isEmpty { allowed.insert(key) }
        }
        for group in virtualDeviceStore.remoteGroups {
            for mac in group.mac_addresses {
                let key = LimiDeviceNaming.normalizedHardwareIdFromMAC(mac)
                if !key.isEmpty { allowed.insert(key) }
            }
        }

        var didDeleteOrphan = false
        for row in rows {
            let key = normalizeHardwareId(row.deviceID)
            if key.isEmpty || !allowed.contains(key) {
                modelContext.delete(row)
                didDeleteOrphan = true
                continue
            }
            if LocallyRemovedDeviceStore.shared.contains(key) { continue }
            if knownWifiDevices.values.contains(where: { normalizeHardwareId($0.chennalMac) == key }) {
                continue
            }
            knownWifiDevices[key] = WifiDevice(
                id: key,
                uuid: key,
                chennalMac: key,
                chennalCount: row.channelCount,
                channelTypes: row.channelTypes,
                deviceName: row.displayName,
                isOnline: false
            )
        }
        if didDeleteOrphan {
            try? modelContext.save()
        }
    }

    private func rememberDevice(_ device: WifiDevice) {
        let key = normalizeHardwareId(device.chennalMac)
        guard !key.isEmpty else { return }
        if LocallyRemovedDeviceStore.shared.contains(key) { return }
        let descriptor = FetchDescriptor<RememberedLimiDevice>(
            predicate: #Predicate { $0.deviceID == key }
        )
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.displayName = device.deviceName
                existing.channelCount = device.chennalCount
                existing.channelTypesRaw = device.channelTypes.joined(separator: ",")
                existing.updatedAt = Date()
            } else {
                modelContext.insert(
                    RememberedLimiDevice(
                        deviceID: key,
                        displayName: device.deviceName,
                        channelCount: device.chennalCount,
                        channelTypes: device.channelTypes
                    )
                )
            }
            try modelContext.save()
        } catch { /* ignored */ }
    }

    private func fetchLinkedDevicesFromCloud() {
        DeviceService().fetchLinkedDevices { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let devices):
                    for linked in devices {
                        let key = self.normalizeHardwareId(linked.deviceID)
                        guard !key.isEmpty else { continue }
                        if LocallyRemovedDeviceStore.shared.contains(key) { continue }
                        if self.knownWifiDevices.values.contains(where: {
                            self.normalizeHardwareId($0.chennalMac) == key
                        }) {
                            continue
                        }
                        let stub = WifiDevice(
                            id: key,
                            uuid: key,
                            chennalMac: key,
                            chennalCount: 1,
                            channelTypes: ["CCT"],
                            deviceName: linked.name.isEmpty ? key : linked.name,
                            isOnline: false
                        )
                        self.knownWifiDevices[key] = stub
                        self.rememberDevice(stub)
                    }
                    self.refreshDisplayedDevices()
                    if !self.wifiDevices.isEmpty {
                        self.isInitialDiscovery = false
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Rename persistence (same SwiftData model as the main app)

    private func deviceStorageKey(for device: WifiDevice) -> String {
        let trimmedMac = device.chennalMac.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMac.isEmpty ? device.uuid : trimmedMac
    }

    private func displayName(for device: WifiDevice) -> String {
        if let customName = customDeviceNames[deviceStorageKey(for: device)],
           !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        return device.deviceName
    }

    private func memberSequenceDisplayName(hardwareId: String, members: [String]) -> String {
        let hw = normalizeHardwareId(hardwareId)
        if let raw = rawWifiDevices.first(where: { normalizeHardwareId($0.chennalMac) == hw }) {
            return displayName(for: raw)
        }
        if let known = knownWifiDevices.values.first(where: { normalizeHardwareId($0.chennalMac) == hw }) {
            return displayName(for: known)
        }
        if let name = ConfiguredBLEDeviceStore.shared.record(for: hw)?.displayName {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let ordered = members.map { normalizeHardwareId($0) }.filter { !$0.isEmpty }
        if let index = ordered.firstIndex(of: hw) {
            return ordered.count > 1 ? "Hub \(index + 1)" : "Hub"
        }
        return hw
    }

    private func beginRenaming(_ device: WifiDevice) {
        renameTargetDevice = device
        renameInput = customDeviceNames[deviceStorageKey(for: device)] ?? device.deviceName
    }

    private func saveCustomDeviceName() {
        guard let device = renameTargetDevice else { return }
        let key = deviceStorageKey(for: device)
        let trimmedName = renameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<DeviceNamePreference>(
            predicate: #Predicate { $0.deviceID == key }
        )

        do {
            let storedPreference = try modelContext.fetch(descriptor).first
            if trimmedName.isEmpty || trimmedName == device.deviceName {
                if let storedPreference { modelContext.delete(storedPreference) }
            } else if let storedPreference {
                storedPreference.customName = trimmedName
            } else {
                modelContext.insert(DeviceNamePreference(deviceID: key, customName: trimmedName))
            }
            try modelContext.save()
            loadSavedDeviceNames()
            if !trimmedName.isEmpty {
                autoAssignRoomIfNameMatches(deviceKey: key, name: trimmedName)
            }
        } catch { /* ignored */ }
    }

    private func loadSavedDeviceNames() {
        do {
            let storedPreferences = try modelContext.fetch(FetchDescriptor<DeviceNamePreference>())
            customDeviceNames = Dictionary(
                uniqueKeysWithValues: storedPreferences.map { ($0.deviceID, $0.customName) }
            )
        } catch { /* ignored */ }
    }

    // MARK: - Room persistence (local, SwiftData)

    private func loadRoomAssignments() {
        do {
            let stored = try modelContext.fetch(FetchDescriptor<DeviceRoomAssignment>())
            roomAssignments = Dictionary(
                uniqueKeysWithValues: stored.map { ($0.deviceID, $0.roomName) }
            )
        } catch { /* ignored */ }
    }

    /// Pass nil to remove the device from its room.
    private func assignRoom(_ roomName: String?, to device: WifiDevice) {
        let key = deviceStorageKey(for: device)
        let trimmedRoom = roomName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<DeviceRoomAssignment>(
            predicate: #Predicate { $0.deviceID == key }
        )

        do {
            let stored = try modelContext.fetch(descriptor).first
            if let trimmedRoom, !trimmedRoom.isEmpty {
                if let stored {
                    stored.roomName = trimmedRoom
                } else {
                    modelContext.insert(DeviceRoomAssignment(deviceID: key, roomName: trimmedRoom))
                }
            } else if let stored {
                modelContext.delete(stored)
            }
            try modelContext.save()
            loadRoomAssignments()
        } catch { /* ignored */ }
    }

    /// If a device is renamed to something starting with an existing room
    /// name (e.g. "Living Room 1"), drop it into that room automatically.
    private func autoAssignRoomIfNameMatches(deviceKey: String, name: String) {
        let lowered = name.lowercased()
        guard let match = knownRooms.first(where: { lowered.hasPrefix($0.lowercased()) }) else { return }
        guard roomAssignments[deviceKey] != match else { return }
        guard let device = wifiDevices.first(where: { deviceStorageKey(for: $0) == deviceKey }) else { return }
        assignRoom(match, to: device)
    }
}

// MARK: - Row

struct DeviceListRow: View {
    let name: String
    let channelCount: Int
    let channelTypes: [String]
    let isOnline: Bool
    var statusText: String = ""
    var roomName: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.led")
                .font(.title3)
                .foregroundStyle(isOnline ? DeviceTheme.accent : Color.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? DeviceTheme.accent : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(statusText.isEmpty ? (isOnline ? "Online" : "Offline") : statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let channels = channelCount == 1 ? "1 channel" : "\(channelCount) channels"
        let types = Set(channelTypes).sorted().joined(separator: "/")
        var parts = [types.isEmpty ? channels : "\(channels) • \(types)"]
        if let roomName, !roomName.isEmpty {
            parts.append(roomName)
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Control routing (single channel → control, multi → channel list)

struct DeviceControlDestination: View {
    let device: WifiDevice
    let displayName: String

    var body: some View {
        if device.isVirtualMaster {
            VirtualMasterControlView(
                virtualDeviceID: VirtualDeviceHomeGrouping.virtualDeviceId(from: device),
                displayName: displayName,
                memberHardwareIds: device.memberChannelMacs ?? [],
                memberChannelTypes: device.channelTypes
            )
        } else if device.chennalCount <= 1 {
            DeviceControlView(
                deviceName: displayName,
                chennalMac: device.macForChannel(1),
                channel: 1,
                channelType: device.channelTypes.first ?? "CCT"
            )
        } else {
            DeviceChannelsView(device: device, displayName: displayName)
        }
    }
}

struct DeviceChannelsView: View {
    let device: WifiDevice
    let displayName: String

    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }

    var body: some View {
        Group {
            if usesHomeUI1 {
                homeUI1Channels
            } else {
                systemChannels
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
    }

    private var homeUI1Channels: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Each channel controls one connected light.")
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .padding(.horizontal, 4)

                    ForEach(1...max(device.chennalCount, 1), id: \.self) { channel in
                        NavigationLink {
                            DeviceControlView(
                                deviceName: "\(displayName) — Ch \(channel)",
                                chennalMac: device.macForChannel(channel),
                                channel: 1,
                                channelType: channelType(at: channel)
                            )
                        } label: {
                            HomeUI1ControlChannelRow(
                                title: "Channel \(channel)",
                                typeLabel: channelType(at: channel)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var systemChannels: some View {
        List {
            Section {
                ForEach(1...max(device.chennalCount, 1), id: \.self) { channel in
                    NavigationLink {
                        DeviceControlView(
                            deviceName: "\(displayName) — Ch \(channel)",
                            chennalMac: device.macForChannel(channel),
                            channel: 1,
                            channelType: channelType(at: channel)
                        )
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundStyle(DeviceTheme.accent)
                            Text("Channel \(channel)")
                            Spacer()
                            Text(channelType(at: channel))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Each channel controls one connected light.")
            }
        }
    }

    private func channelType(at channel: Int) -> String {
        let index = channel - 1
        guard device.channelTypes.indices.contains(index) else { return "CCT" }
        return device.channelTypes[index].uppercased() == "RGB" ? "RGB" : "CCT"
    }
}

// MARK: - Home alert modifiers (kept in-file so the editor always resolves them)

struct DeviceHomeRenameAlertModifier: ViewModifier {
    @Binding var renameTargetDevice: WifiDevice?
    @Binding var renameInput: String
    var onSave: () -> Void
    var onReset: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Rename Device",
            isPresented: Binding(
                get: { renameTargetDevice != nil },
                set: { if !$0 { renameTargetDevice = nil } }
            )
        ) {
            TextField("Device name", text: $renameInput)
            Button("Save", action: onSave)
            Button("Reset", action: onReset)
            Button("Cancel", role: .cancel) { renameTargetDevice = nil }
        } message: {
            Text("This name will be saved only on this phone. Tip: start it with a room name (e.g. \"Living Room 1\") to group it automatically.")
        }
    }
}

struct DeviceHomeRoomAlertModifier: ViewModifier {
    @Binding var newRoomTargetDevice: WifiDevice?
    @Binding var newRoomInput: String
    var onCreate: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "New Room",
            isPresented: Binding(
                get: { newRoomTargetDevice != nil },
                set: { if !$0 { newRoomTargetDevice = nil } }
            )
        ) {
            TextField("Room name", text: $newRoomInput)
            Button("Create", action: onCreate)
            Button("Cancel", role: .cancel) { newRoomTargetDevice = nil }
        } message: {
            Text("e.g. Living Room, Bedroom, Office")
        }
    }
}

struct DeviceHomeOfflineAlertModifier: ViewModifier {
    @Binding var offlineAlertDevice: WifiDevice?
    var onSchedules: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            DeviceAppGuidance.offlineTitle,
            isPresented: Binding(
                get: { offlineAlertDevice != nil },
                set: { if !$0 { offlineAlertDevice = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
            Button("Schedules", action: onSchedules)
        } message: {
            Text(DeviceAppGuidance.offlineMessage)
        }
    }
}

struct DeviceHomeDeleteAlertModifier: ViewModifier {
    @Binding var deleteTargetDevice: WifiDevice?
    var onDelete: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Remove Device",
            isPresented: Binding(
                get: { deleteTargetDevice != nil },
                set: { if !$0 { deleteTargetDevice = nil } }
            )
        ) {
            Button("Remove", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { deleteTargetDevice = nil }
        } message: {
            Text("Remove this device from this phone? You can add it again later by setting it up or rediscovering it.")
        }
    }
}

// MARK: - Local switch notification inbox

struct DeviceLocalSwitchInboxSheet: View {
    @ObservedObject private var coordinator = CloudOfflineLocalSwitchCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let offer = coordinator.activeOffer {
                    offerList(offer)
                } else {
                    ContentUnavailableView(
                        "You're all caught up",
                        systemImage: "bell.slash",
                        description: Text("Cloud and local control alerts will show up here.")
                    )
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func offerList(_ offer: LocalControlSwitchOffer) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(offer.notificationTitle, systemImage: "icloud.slash")
                        .font(.headline)
                    Text(offer.notificationBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(offer.deviceId)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Text(offer.alertMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    coordinator.accept()
                    dismiss()
                } label: {
                    Label(
                        offer.acceptButtonTitle,
                        systemImage: offer.canUseBLE ? "antenna.radiowaves.left.and.right" : "wifi"
                    )
                }
                .tint(.green)

                Button("Not now", role: .cancel) {
                    coordinator.decline()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    DeviceHomeView()
        .modelContainer(
            for: [DeviceNamePreference.self, DeviceRoomAssignment.self, RememberedLimiDevice.self, VirtualDeviceGroup.self],
            inMemory: true
        )
}
