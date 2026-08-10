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
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    @ObservedObject private var transportPreference = TransportMediumPreferenceStore.shared
    @ObservedObject private var socket = LightControllingSocket.shared
    @ObservedObject private var bluetooth = BluetoothManager.shared
    @ObservedObject private var userDataManager = UserDataManager.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    // MARK: - Device state (mirrors ConnectedDevicesView)
    @State private var wifiDevices: [WifiDevice] = []
    @State private var knownWifiDevices: [String: WifiDevice] = [:]
    @State private var allocatedWifiDeviceIds: Set<String> = []
    @State private var uploadedDeviceIds: Set<String> = []

    @State private var selectedDevice: WifiDevice?
    @State private var scheduleDevice: WifiDevice?
    @State private var showAddDevice = false

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
        NavigationStack {
            Group {
                if isGuestInstaller {
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
                } else {
                    homeThemeContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddDevice) {
            DeviceAddFlowView()
        }
        .sheet(item: $selectedDevice) { device in
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
        .sheet(item: $scheduleDevice) { device in
            NavigationStack {
                DeviceSchedulesView(device: device, displayName: displayName(for: device))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { scheduleDevice = nil }
                        }
                    }
            }
        }
        .alert(
            "Rename Device",
            isPresented: Binding(
                get: { renameTargetDevice != nil },
                set: { if !$0 { renameTargetDevice = nil } }
            )
        ) {
            TextField("Device name", text: $renameInput)
            Button("Save") {
                saveCustomDeviceName()
                renameTargetDevice = nil
            }
            Button("Reset") {
                renameInput = ""
                saveCustomDeviceName()
                renameTargetDevice = nil
            }
            Button("Cancel", role: .cancel) { renameTargetDevice = nil }
        } message: {
            Text("This name will be saved only on this phone. Tip: start it with a room name (e.g. \"Living Room 1\") to group it automatically.")
        }
        .alert(
            "New Room",
            isPresented: Binding(
                get: { newRoomTargetDevice != nil },
                set: { if !$0 { newRoomTargetDevice = nil } }
            )
        ) {
            TextField("Room name", text: $newRoomInput)
            Button("Create") {
                if let device = newRoomTargetDevice {
                    assignRoom(newRoomInput, to: device)
                }
                newRoomTargetDevice = nil
            }
            Button("Cancel", role: .cancel) { newRoomTargetDevice = nil }
        } message: {
            Text("e.g. Living Room, Bedroom, Office")
        }
        .alert(
            DeviceAppGuidance.offlineTitle,
            isPresented: Binding(
                get: { offlineAlertDevice != nil },
                set: { if !$0 { offlineAlertDevice = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
            Button("Schedules") {
                if let device = offlineAlertDevice {
                    scheduleDevice = device
                }
                offlineAlertDevice = nil
            }
        } message: {
            Text(DeviceAppGuidance.offlineMessage)
        }
        .onAppear {
            UserDataManager.shared.refreshUserData()
            loadSavedDeviceNames()
            loadRoomAssignments()
            loadRememberedDevices()
            fetchLinkedDevicesFromCloud()
            seedCloudDevicesFromPresence()
            seedConfiguredBLEDevices()
            bonjourBrowser.startBrowsing()
            scheduleDiscoveryTimeout()
            refreshDisplayedDevices()
        }
        .onDisappear {
            bonjourBrowser.stopBrowsing()
            // Cloud socket stays connected at DeviceRootView while signed in.
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
        .onChange(of: socket.connectionStatus) { _, status in
            if status == .connected {
                // Re-seed after reconnect — presence events may have been missed.
                seedCloudDevicesFromPresence()
                fetchLinkedDevicesFromCloud()
            }
            refreshDisplayedDevices()
        }
        .onChange(of: bluetooth.isConnected) { _, _ in
            refreshDisplayedDevices()
        }
        .onChange(of: bluetooth.isBluetoothOn) { _, _ in
            refreshDisplayedDevices()
        }
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

    /// Filter chips: real rooms + demo Kitchen / Living Room (if missing).
    private var filterBarRooms: [String] {
        var rooms = knownRooms
        for name in ["Kitchen", "Office"] {
            let exists = rooms.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            if !exists { rooms.append(name) }
        }
        return rooms
    }

    private func room(for device: WifiDevice) -> String? {
        roomAssignments[deviceStorageKey(for: device)]
    }

    private func devices(in room: String?) -> [WifiDevice] {
        wifiDevices.filter { self.room(for: $0) == room }
    }

    /// Devices visible for the current room + search filters.
    private var filteredDevices: [WifiDevice] {
        wifiDevices.filter { device in
            if let selectedRoomFilter, room(for: device) != selectedRoomFilter {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return displayName(for: device).localizedCaseInsensitiveContains(query)
                || (room(for: device)?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var featuredDevice: WifiDevice? {
        if let featuredDeviceId,
           let match = filteredDevices.first(where: { $0.id == featuredDeviceId }) {
            return match
        }
        return filteredDevices.first(where: \.isOnline) ?? filteredDevices.first
    }

    /// Temporary: switches Home UI 1–5 for client theme review.
    @ViewBuilder
    private var homeThemeContent: some View {
        Group {
            switch homeUITheme.selected {
            case .one:
                smartHomeOverview
            case .two:
                DeviceHomeUIVariantTwoView(
                    userName: greetingUserName,
                    greeting: timeGreeting,
                    items: previewItems,
                    onOpen: { openDeviceById($0) },
                    onToggle: { togglePowerById($0) },
                    onAdd: { showAddDevice = true }
                )
            case .three:
                DeviceHomeUIVariantThreeView(
                    userName: greetingUserName,
                    items: previewItems,
                    onOpen: { openDeviceById($0) },
                    onToggle: { togglePowerById($0) },
                    onAdd: { showAddDevice = true }
                )
            case .four:
                DeviceHomeUIVariantFourView(
                    userName: greetingUserName,
                    items: previewItems,
                    onOpen: { openDeviceById($0) },
                    onToggle: { togglePowerById($0) },
                    onAdd: { showAddDevice = true }
                )
            case .five:
                DeviceHomeUIVariantFiveView(
                    userName: greetingUserName,
                    greeting: timeGreeting,
                    items: previewItems,
                    onOpen: { openDeviceById($0) },
                    onToggle: { togglePowerById($0) },
                    onAdd: { showAddDevice = true }
                )
            }
        }
        // Force a clean view identity on theme switch to avoid stale
        // SwiftUI attribute-graph nodes (EXC_BAD_ACCESS on teardown).
        .id(homeUITheme.selected)
    }

    private var previewItems: [DeviceHomeUIPreviewItem] {
        filteredDevices.map { device in
            DeviceHomeUIPreviewItem(
                id: device.id,
                name: displayName(for: device),
                subtitle: manageSubtitle(for: device),
                isOnline: device.isOnline,
                isPowerOn: isPowerOn(for: device)
            )
        }
    }

    private func openDeviceById(_ id: String) {
        guard let device = wifiDevices.first(where: { $0.id == id }) else { return }
        openDevice(device)
    }

    private func togglePowerById(_ id: String) {
        guard let device = wifiDevices.first(where: { $0.id == id }) else { return }
        togglePower(for: device)
    }

    private var smartHomeOverview: some View {
        ZStack {
            HomeUI1AnimatedCanvas()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    DeviceSmartHomeHeader(
                        userName: greetingUserName,
                        greeting: timeGreeting,
                        avatarImage: userDataManager.profileImage
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

                    DeviceRoomFilterBar(
                        rooms: filterBarRooms,
                        selectedRoom: $selectedRoomFilter
                    )

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

                VStack(spacing: 12) {
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
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
                        onlineCount: roomDevices.filter(\.isOnline).count
                    )
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
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
        Button {
            featuredDeviceId = device.id
        } label: {
            Label("Feature on Home", systemImage: "star")
        }
        roomMenu(for: device)
    }

    private func featuredSubtitle(for device: WifiDevice) -> String {
        if let roomName = room(for: device), !roomName.isEmpty {
            return "Connected to \(roomName)"
        }
        return statusText(for: device)
    }

    private func manageSubtitle(for device: WifiDevice) -> String {
        let channels = device.chennalCount == 1 ? "1 channel" : "\(device.chennalCount) channels"
        let types = Set(device.channelTypes).sorted().joined(separator: "/")
        var parts = [types.isEmpty ? channels : "\(channels) · \(types)"]
        if let roomName = room(for: device), !roomName.isEmpty {
            parts.append(roomName)
        }
        parts.append(statusText(for: device))
        return parts.joined(separator: " · ")
    }

    private func isPowerOn(for device: WifiDevice) -> Bool {
        let key = deviceStorageKey(for: device)
        if let stored = devicePowerOn[key] { return stored }
        return device.isOnline
    }

    private func openDevice(_ device: WifiDevice) {
        if device.isOnline {
            DeviceAppGuidance.lightImpact()
            featuredDeviceId = device.id
            selectedDevice = device
        } else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
        }
    }

    private func togglePower(for device: WifiDevice) {
        guard device.isOnline else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
            return
        }
        let key = deviceStorageKey(for: device)
        let next = !isPowerOn(for: device)
        devicePowerOn[key] = next
        DeviceAppGuidance.lightImpact()
        sendPower(to: device, on: next)
    }

    private func applyMood(_ mood: DeviceLightMood, to device: WifiDevice) {
        guard device.isOnline else {
            DeviceAppGuidance.warningNotification()
            offlineAlertDevice = device
            return
        }
        selectedMood = mood
        devicePowerOn[deviceStorageKey(for: device)] = true
        DeviceAppGuidance.lightImpact()
        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendCommand(mood.command, for: device.chennalMac)
                DeviceAppGuidance.successNotification()
            } catch {
                groupActionMessage = DeviceAppGuidance.message(for: error)
                DeviceAppGuidance.warningNotification()
            }
        }
    }

    private func sendPower(to device: WifiDevice, on: Bool) {
        let command: LimiCommand = on
            ? .cct(channel: 1, brightness: 70, ww: 100, cw: 40)
            : .power(channel: 1, on: false)
        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendCommand(command, for: device.chennalMac)
                DeviceAppGuidance.successNotification()
            } catch {
                devicePowerOn[deviceStorageKey(for: device)] = !on
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
            ? "Each device shows its own path: Cloud (MQTT) or BLE. Cloud-online devices stay listed for remote control."
            : "Testing mode — commands always use \(transportPreference.preference.shortTitle)."
    }

    // MARK: - Bonjour + cloud presence (Case 3)

    private func processDiscoveredDevices(_ newDevices: [BLEDevice]) {
        let filtered = newDevices.filter { LimiDeviceNaming.isAllowedDeviceName($0.name) }
        let currentUUIDs = Set(filtered.map(\.uuid))

        for dev in filtered {
            let mapped = wifiDevice(from: dev)
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

        ensureKnownDeviceStub(
            hardwareId: key,
            displayName: customDeviceNames[key],
            remember: connected
        )
        refreshDisplayedDevices()
    }

    /// Case 3: rebuild cloud rows from registry + persisted presence (missed events).
    private func seedCloudDevicesFromPresence() {
        DeviceTransportRegistry.shared.restorePersistedPresenceIfNeeded()

        var ids = Set(DeviceTransportRegistry.shared.presenceSnapshot().map(\.deviceId))
        for id in CloudPresenceMemory.shared.knownDeviceIds() {
            ids.insert(normalizeHardwareId(id))
        }
        for id in ids where !id.isEmpty {
            let connected = DeviceTransportRegistry.shared.state(for: id).mqttConnected
                || (CloudPresenceMemory.shared.lastConnected(deviceId: id) ?? false)
            ensureKnownDeviceStub(
                hardwareId: id,
                displayName: customDeviceNames[id],
                remember: connected || knownWifiDevices.values.contains {
                    normalizeHardwareId($0.chennalMac) == id
                }
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

            let localOnline = knownWifiDevices[device.id]?.isOnline ?? false
            let cloudOnline = isCloudOnline(device.chennalMac)
            let bleOnline = isBLEOnline(device.chennalMac)
            var copy = device
            // Per-device: MQTT cloud, LAN Bonjour, or BLE — independently online.
            copy.isOnline = localOnline || cloudOnline || bleOnline

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

        wifiDevices = byHardware.values.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
    }

    private func isCloudOnline(_ deviceId: String) -> Bool {
        // Case 3 needs a live cloud socket; otherwise fall back to local only.
        guard socket.isConnected else { return false }
        let key = normalizeHardwareId(deviceId)
        guard !key.isEmpty else { return false }
        if DeviceTransportRegistry.shared.state(for: key).mqttConnected {
            return true
        }
        // Missed live event: last definite presence from this phone.
        return CloudPresenceMemory.shared.lastConnected(deviceId: key) == true
    }

    private func isLocalOnline(_ device: WifiDevice) -> Bool {
        // Bonjour bit is stored before cloud OR in refresh; look up raw known entry.
        if let raw = knownWifiDevices[device.id] {
            return raw.isOnline
        }
        return false
    }

    /// True when this hub is on the BLE door (cloud MQTT off + BLE configured).
    private func isBLEOnline(_ deviceId: String) -> Bool {
        let key = normalizeHardwareId(deviceId)
        guard !key.isEmpty else { return false }
        // Cloud MQTT wins — never label as BLE while mqtt presence is on.
        if isCloudOnline(key) { return false }
        if DeviceTransportRegistry.shared.state(for: key).mqttConnected { return false }
        guard bluetooth.isBluetoothOn else { return false }
        return ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: key)
    }

    private func statusText(for device: WifiDevice) -> String {
        let cloud = isCloudOnline(device.chennalMac)
        let local = isLocalOnline(device)
        let ble = isBLEOnline(device.chennalMac)

        // Per-device label: Cloud (MQTT) first, then Local LAN, then BLE.
        if cloud { return "Online · Cloud" }
        if local { return "Online · Local" }
        if ble { return "Online · BLE" }
        return "Offline"
    }

    /// Keep configured BLE hubs in the list even when Bonjour/cloud are quiet.
    private func seedConfiguredBLEDevices() {
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
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

    private func loadRememberedDevices() {
        let descriptor = FetchDescriptor<RememberedLimiDevice>()
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        for row in rows {
            let key = normalizeHardwareId(row.deviceID)
            guard !key.isEmpty else { continue }
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
    }

    private func rememberDevice(_ device: WifiDevice) {
        let key = normalizeHardwareId(device.chennalMac)
        guard !key.isEmpty else { return }
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
        } catch {
            print("❌ Failed to remember device: \(error.localizedDescription)")
        }
    }

    private func fetchLinkedDevicesFromCloud() {
        DeviceService().fetchLinkedDevices { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let devices):
                    for linked in devices {
                        let key = self.normalizeHardwareId(linked.deviceID)
                        guard !key.isEmpty else { continue }
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
                case .failure(let error):
                    print("⚠️ [DeviceApp] get_link_devices failed: \(error.localizedDescription)")
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
        } catch {
            print("❌ Failed to save local device name: \(error.localizedDescription)")
        }
    }

    private func loadSavedDeviceNames() {
        do {
            let storedPreferences = try modelContext.fetch(FetchDescriptor<DeviceNamePreference>())
            customDeviceNames = Dictionary(
                uniqueKeysWithValues: storedPreferences.map { ($0.deviceID, $0.customName) }
            )
        } catch {
            print("❌ Failed to load local device names: \(error.localizedDescription)")
        }
    }

    // MARK: - Room persistence (local, SwiftData)

    private func loadRoomAssignments() {
        do {
            let stored = try modelContext.fetch(FetchDescriptor<DeviceRoomAssignment>())
            roomAssignments = Dictionary(
                uniqueKeysWithValues: stored.map { ($0.deviceID, $0.roomName) }
            )
        } catch {
            print("❌ Failed to load room assignments: \(error.localizedDescription)")
        }
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
        } catch {
            print("❌ Failed to save room assignment: \(error.localizedDescription)")
        }
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
        if device.chennalCount <= 1 {
            DeviceControlView(
                deviceName: displayName,
                chennalMac: device.chennalMac,
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
                                chennalMac: device.chennalMac,
                                channel: channel,
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
                            chennalMac: device.chennalMac,
                            channel: channel,
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

#Preview {
    DeviceHomeView()
        .modelContainer(
            for: [DeviceNamePreference.self, DeviceRoomAssignment.self, RememberedLimiDevice.self],
            inMemory: true
        )
}
