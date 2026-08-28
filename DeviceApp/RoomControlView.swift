//
//  RoomControlView.swift
//  LIMI AI Device
//
//  Cumulative room control — master power, brightness, CCT/RGB dials that
//  send one group command for all online devices, plus a list to open individuals.
//
//  Home UI 1: neumorphic Soft UI. Other Home UIs keep the system List.
//

import SwiftUI

struct RoomControlView: View {
    @StateObject private var viewModel: RoomControlViewModel
    @ObservedObject private var socket = LightControllingSocket.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    /// Full device list from home (kept live so online status refreshes).
    let allDevices: [WifiDevice]
    let roomAssignments: [String: String]
    let displayNameProvider: (WifiDevice) -> String
    let statusTextProvider: (WifiDevice) -> String
    private let roomName: String

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }
    private var usesHomeUI2: Bool { homeUITheme.selected == .two }

    init(
        roomName: String,
        allDevices: [WifiDevice],
        roomAssignments: [String: String],
        displayNameProvider: @escaping (WifiDevice) -> String,
        statusTextProvider: @escaping (WifiDevice) -> String = { $0.isOnline ? "Online" : "Offline" }
    ) {
        self.roomName = roomName
        self.allDevices = allDevices
        self.roomAssignments = roomAssignments
        self.displayNameProvider = displayNameProvider
        self.statusTextProvider = statusTextProvider
        let initial = Self.devices(
            in: roomName,
            from: allDevices,
            assignments: roomAssignments
        )
        _viewModel = StateObject(
            wrappedValue: RoomControlViewModel(
                roomName: roomName,
                devices: initial,
                displayNameProvider: displayNameProvider
            )
        )
    }

    var body: some View {
        Group {
            if usesHomeUI1 {
                homeUI1Body
            } else if usesHomeUI2 {
                homeUI2Body
            } else {
                systemListBody
            }
        }
        .navigationTitle(viewModel.roomName)
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
        .homeUI2ControlNavigationChrome(enabled: usesHomeUI2)
        .onAppear { syncDevices() }
        .onChange(of: deviceSyncKey) { _, _ in
            syncDevices()
        }
    }

    // MARK: - Home UI 1

    private var homeUI1Body: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if socket.connectionStatus != .connected {
                        HomeUI1ControlConnectionBanner()
                    }

                    HomeUI1ControlSectionCard(
                        title: "Room Controls",
                        footer: roomControlsFooter
                    ) {
                        VStack(spacing: 12) {
                            HomeUI1NeumorphicToggleRow(
                                title: "Power",
                                systemImage: viewModel.isOn ? "lightbulb.fill" : "lightbulb",
                                isOn: Binding(
                                    get: { viewModel.isOn },
                                    set: { viewModel.setPower($0) }
                                ),
                                isEnabled: viewModel.canControl
                            ) { _ in }

                            HomeUI1NeumorphicSliderRow(
                                title: "Brightness",
                                systemImage: "sun.max.fill",
                                value: $viewModel.brightness,
                                valueLabel: "\(Int((viewModel.brightness * 100).rounded()))%",
                                tint: HomeUI1Color.accentGreen,
                                isEnabled: viewModel.isOn && controlsEnabled
                            ) {
                                viewModel.applyBrightness()
                            }

                            if viewModel.hasCCTChannels {
                                HomeUI1NeumorphicSliderRow(
                                    title: "Color Temperature",
                                    systemImage: "thermometer.medium",
                                    value: $viewModel.temperature,
                                    valueLabel: "",
                                    tint: temperaturePreview,
                                    isEnabled: viewModel.isOn && controlsEnabled
                                ) {
                                    viewModel.applyCCT()
                                }
                            }

                            if viewModel.hasRGBChannels {
                                HomeUI1NeumorphicSliderRow(
                                    title: "Color",
                                    systemImage: "paintpalette.fill",
                                    value: $viewModel.hue,
                                    valueLabel: "",
                                    tint: Color(hue: viewModel.hue, saturation: 1, brightness: 1),
                                    isEnabled: viewModel.isOn && controlsEnabled
                                ) {
                                    viewModel.applyRGB()
                                }
                            }

                            homeUI1StatusBlock
                        }
                    }

                    HomeUI1ControlSectionCard(
                        title: "Individual Devices",
                        footer: "Online devices open full dial control. Offline devices stay listed until they reconnect."
                    ) {
                        VStack(spacing: 10) {
                            ForEach(viewModel.devices) { device in
                                let row = HomeUI1ControlDeviceRow(
                                    name: viewModel.displayName(for: device),
                                    subtitle: deviceSubtitle(for: device),
                                    isOnline: device.isOnline,
                                    statusText: statusTextProvider(device)
                                )

                                if device.isOnline {
                                    NavigationLink {
                                        DeviceControlDestination(
                                            device: device,
                                            displayName: viewModel.displayName(for: device)
                                        )
                                    } label: {
                                        row
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    row
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var homeUI1StatusBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.onlineDevices.count) of \(viewModel.devices.count) devices online")
                .font(HomeUI1Type.caption(12))
                .foregroundStyle(HomeUI1Color.textSecondary)

            if viewModel.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HomeUI1Color.accentGreen)
                    Text("Sending…")
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
            }

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(
                        viewModel.statusIsError
                            ? HomeUI1Color.warning
                            : HomeUI1Color.textSecondary
                    )
            }

            if viewModel.canRetry {
                Button {
                    DeviceAppGuidance.lightImpact()
                    viewModel.retryLastCommand()
                } label: {
                    Text("Try Again")
                        .font(HomeUI1Type.body(14))
                        .foregroundStyle(HomeUI1Color.accentGreen)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.surface)
                }
                .buttonStyle(.plain)
            }

            if !viewModel.canControl {
                Text(DeviceAppGuidance.noOnlineInRoom)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(HomeUI1Motion.soft, value: viewModel.isBusy)
        .animation(HomeUI1Motion.soft, value: viewModel.statusMessage)
    }

    // MARK: - Home UI 2

    private var homeUI2Body: some View {
        ZStack {
            HomeUI2ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if socket.connectionStatus != .connected {
                        HomeUI2ControlConnectionBanner()
                    }

                    HomeUI2ControlSectionCard(
                        title: "Room Controls",
                        footer: roomControlsFooter
                    ) {
                        VStack(spacing: 12) {
                            HomeUI2ToggleRow(
                                title: "Power",
                                systemImage: viewModel.isOn ? "lightbulb.fill" : "lightbulb",
                                isOn: Binding(
                                    get: { viewModel.isOn },
                                    set: { viewModel.setPower($0) }
                                ),
                                isEnabled: viewModel.canControl
                            ) { _ in }

                            HomeUI2SliderRow(
                                title: "Brightness",
                                systemImage: "sun.max.fill",
                                value: $viewModel.brightness,
                                valueLabel: "\(Int((viewModel.brightness * 100).rounded()))%",
                                tint: HomeUI2Color.accent,
                                isEnabled: viewModel.isOn && controlsEnabled
                            ) {
                                viewModel.applyBrightness()
                            }

                            if viewModel.hasCCTChannels {
                                HomeUI2SliderRow(
                                    title: "Color Temperature",
                                    systemImage: "thermometer.medium",
                                    value: $viewModel.temperature,
                                    valueLabel: "",
                                    tint: temperaturePreview,
                                    isEnabled: viewModel.isOn && controlsEnabled
                                ) {
                                    viewModel.applyCCT()
                                }
                            }

                            if viewModel.hasRGBChannels {
                                HomeUI2SliderRow(
                                    title: "Color",
                                    systemImage: "paintpalette.fill",
                                    value: $viewModel.hue,
                                    valueLabel: "",
                                    tint: Color(hue: viewModel.hue, saturation: 1, brightness: 1),
                                    isEnabled: viewModel.isOn && controlsEnabled
                                ) {
                                    viewModel.applyRGB()
                                }
                            }

                            homeUI2StatusBlock
                        }
                    }

                    HomeUI2ControlSectionCard(
                        title: "Individual Devices",
                        footer: "Online devices open full dial control. Offline devices stay listed until they reconnect."
                    ) {
                        VStack(spacing: 10) {
                            ForEach(viewModel.devices) { device in
                                let row = HomeUI2ControlDeviceRow(
                                    name: viewModel.displayName(for: device),
                                    subtitle: deviceSubtitle(for: device),
                                    isOnline: device.isOnline,
                                    statusText: statusTextProvider(device)
                                )

                                if device.isOnline {
                                    NavigationLink {
                                        DeviceControlDestination(
                                            device: device,
                                            displayName: viewModel.displayName(for: device)
                                        )
                                    } label: {
                                        row
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    row
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private var homeUI2StatusBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.onlineDevices.count) of \(viewModel.devices.count) devices online")
                .font(HomeUI2Type.caption(12))
                .foregroundStyle(HomeUI2Color.textSecondary)

            if viewModel.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HomeUI2Color.accent)
                    Text("Sending…")
                        .font(HomeUI2Type.caption(12))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                }
            }

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(
                        viewModel.statusIsError
                            ? Color.orange
                            : HomeUI2Color.textSecondary
                    )
            }

            if viewModel.canRetry {
                Button {
                    DeviceAppGuidance.lightImpact()
                    viewModel.retryLastCommand()
                } label: {
                    Text("Try Again")
                        .font(HomeUI2Type.body(14))
                        .foregroundStyle(HomeUI2Color.textOnAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(HomeUI2Color.accent)
                        )
                }
                .buttonStyle(.plain)
            }

            if !viewModel.canControl {
                Text(DeviceAppGuidance.noOnlineInRoom)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(HomeUI2Motion.soft, value: viewModel.isBusy)
        .animation(HomeUI2Motion.soft, value: viewModel.statusMessage)
    }

    private var roomControlsFooter: String? {
        nil
    }

    private func deviceSubtitle(for device: WifiDevice) -> String {
        let channels = device.chennalCount == 1 ? "1 channel" : "\(device.chennalCount) channels"
        let types = Set(device.channelTypes).sorted().joined(separator: "/")
        return types.isEmpty ? channels : "\(channels) • \(types)"
    }

    // MARK: - System (non–Home UI 1)

    private var systemListBody: some View {
        List {
            if socket.connectionStatus != .connected {
                Section {
                    DeviceConnectionBanner()
                }
            }

            Section {
                powerRow
                brightnessRow
                if viewModel.hasCCTChannels {
                    temperatureRow
                }
                if viewModel.hasRGBChannels {
                    hueRow
                }
            } header: {
                Text("Room Controls")
            } footer: {
                footerText
            }

            Section {
                ForEach(viewModel.devices) { device in
                    if device.isOnline {
                        NavigationLink {
                            DeviceControlDestination(
                                device: device,
                                displayName: viewModel.displayName(for: device)
                            )
                        } label: {
                            DeviceListRow(
                                name: viewModel.displayName(for: device),
                                channelCount: device.chennalCount,
                                channelTypes: device.channelTypes,
                                isOnline: device.isOnline,
                                statusText: statusTextProvider(device)
                            )
                        }
                    } else {
                        DeviceListRow(
                            name: viewModel.displayName(for: device),
                            channelCount: device.chennalCount,
                            channelTypes: device.channelTypes,
                            isOnline: false,
                            statusText: statusTextProvider(device)
                        )
                        .opacity(0.45)
                    }
                }
            } header: {
                Text("Individual Devices")
            } footer: {
                Text("Online devices open full dial control. Offline devices stay listed until they reconnect.")
            }
        }
    }

    private var deviceSyncKey: String {
        allDevices
            .map { "\($0.id):\($0.isOnline):\(roomAssignments[Self.storageKey(for: $0)] ?? "")" }
            .sorted()
            .joined(separator: "|")
    }

    private func syncDevices() {
        viewModel.updateDevices(
            Self.devices(in: roomName, from: allDevices, assignments: roomAssignments)
        )
    }

    private static func storageKey(for device: WifiDevice) -> String {
        let trimmedMac = device.chennalMac.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMac.isEmpty ? device.uuid : trimmedMac
    }

    private static func devices(
        in room: String,
        from allDevices: [WifiDevice],
        assignments: [String: String]
    ) -> [WifiDevice] {
        allDevices.filter { assignments[storageKey(for: $0)] == room }
    }

    // MARK: - System controls

    private var controlsEnabled: Bool {
        viewModel.canControl && !viewModel.isBusy
    }

    private var powerRow: some View {
        Toggle(isOn: Binding(
            get: { viewModel.isOn },
            set: { viewModel.setPower($0) }
        )) {
            Label("Power", systemImage: viewModel.isOn ? "lightbulb.fill" : "lightbulb")
        }
        .tint(DeviceTheme.accent)
        .disabled(!viewModel.canControl)
    }

    private var brightnessRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Brightness", systemImage: "sun.max.fill")
                Spacer()
                Text("\(Int((viewModel.brightness * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $viewModel.brightness,
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        viewModel.applyBrightness()
                    }
                }
            )
            .tint(DeviceTheme.accent)
            .disabled(!viewModel.isOn || !controlsEnabled)
        }
        .padding(.vertical, 4)
    }

    private var temperatureRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Color Temperature", systemImage: "thermometer.medium")
                Spacer()
                Circle()
                    .fill(temperaturePreview)
                    .frame(width: 14, height: 14)
            }
            Slider(
                value: $viewModel.temperature,
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        viewModel.applyCCT()
                    }
                }
            )
            .tint(temperaturePreview)
            .disabled(!viewModel.isOn || !controlsEnabled)
        }
        .padding(.vertical, 4)
    }

    private var hueRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Color", systemImage: "paintpalette.fill")
                Spacer()
                Circle()
                    .fill(Color(hue: viewModel.hue, saturation: 1, brightness: 1))
                    .frame(width: 14, height: 14)
            }
            Slider(
                value: $viewModel.hue,
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        viewModel.applyRGB()
                    }
                }
            )
            .tint(Color(hue: viewModel.hue, saturation: 1, brightness: 1))
            .disabled(!viewModel.isOn || !controlsEnabled)
        }
        .padding(.vertical, 4)
    }

    private var temperaturePreview: Color {
        Color(
            red: 1.0 - viewModel.temperature * 0.35,
            green: 0.75 + viewModel.temperature * 0.15,
            blue: 0.45 + viewModel.temperature * 0.55
        )
    }

    private var footerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.onlineDevices.count) of \(viewModel.devices.count) devices online")

            if viewModel.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Sending…")
                }
                .transition(.opacity)
            }

            if let status = viewModel.statusMessage {
                Text(status)
                    .foregroundStyle(viewModel.statusIsError ? Color.orange : Color.secondary)
                    .transition(.opacity)
            }

            if viewModel.canRetry {
                Button("Try Again") {
                    DeviceAppGuidance.lightImpact()
                    viewModel.retryLastCommand()
                }
                .font(.subheadline.weight(.semibold))
            }

            if !viewModel.canControl {
                Text(DeviceAppGuidance.noOnlineInRoom)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.snappy(duration: 0.25), value: viewModel.isBusy)
        .animation(.snappy(duration: 0.25), value: viewModel.statusMessage)
    }
}

// MARK: - Room card (home list + rooms hub)

struct RoomGroupCard: View {
    enum Style {
        case system
        case homeUI1
    }

    let roomName: String
    let deviceCount: Int
    let onlineCount: Int
    var style: Style = .system

    var body: some View {
        switch style {
        case .homeUI1:
            homeUI1Body
        case .system:
            systemBody
        }
    }

    private var homeUI1Body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.split.bottomrightquarter.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .frame(width: 44, height: 44)
                .homeUI1CircleElevation(.two)

            VStack(alignment: .leading, spacing: 3) {
                Text(roomName)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                Text(subtitle)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .contentShape(Rectangle())
    }

    private var systemBody: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.split.bottomrightquarter.fill")
                .font(.title3)
                .foregroundStyle(DeviceTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(roomName)
                    .font(.body)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let devices = deviceCount == 1 ? "1 device" : "\(deviceCount) devices"
        return "\(devices) · \(onlineCount) online"
    }
}
