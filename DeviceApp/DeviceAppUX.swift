//
//  DeviceAppUX.swift
//  LIMI AI Device
//
//  Shared user-facing copy, connection banner, and light system feedback.
//  Keep DeviceApp on standard iOS chrome — no custom DesignSystem.
//

import SwiftUI
import SwiftData
import UIKit

enum DeviceAppGuidance {
    static let offlineTitle = "Device Offline"
    static let offlineMessage =
        "This light is offline. Make sure it is powered on, connected to Wi‑Fi, and that Local Network access is allowed for LIMI AI Device."

    static let noOnlineInRoom =
        "No online devices in this room. Power on the lights or check Wi‑Fi."

    static let cloudOffline =
        "Cloud connection is offline. Check your internet, then try again."

    static let lookingForDevices =
        "Looking for LIMI devices on your network…"

    static let emptyDevices =
        "You haven't added any devices yet. Add your first LIMI device to get started."

    static let scanEmpty =
        "No devices found yet. Keep your LIMI device powered on and nearby, then wait a few seconds."

    static let roomTip =
        "Tap a room to control all devices together. Long-press a device → Room to group lights."

    static func message(for error: Error) -> String {
        if let transport = error as? LimiTransportError {
            switch transport {
            case .doorUnavailable(.mqtt):
                return cloudOffline
            case .doorUnavailable:
                return "Connection unavailable. Try again in a moment."
            case .deviceUnreachable:
                return "Devices are unreachable. Check power and Wi‑Fi."
            case .mqttActive:
                return "Cloud is busy. Try again in a moment."
            case .missingDeviceIP:
                return "Still finding the device on your network. Try again shortly."
            case .badCommand:
                return "The device rejected that command."
            case .operationNotSupported:
                return "This action isn’t supported on the current connection."
            }
        }
        return error.localizedDescription
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func successNotification() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warningNotification() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// Compact system-style connection row for lists / toolbars.
struct DeviceConnectionBanner: View {
    @ObservedObject private var socket = LightControllingSocket.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: socket.connectionStatus == .connecting)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if socket.connectionStatus == .connecting {
                ProgressView()
                    .controlSize(.small)
            } else if socket.connectionStatus == .disconnected {
                Button("Retry") {
                    DeviceAppGuidance.lightImpact()
                    LightControllingSocket.shared.connect()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
        .animation(.snappy(duration: 0.25), value: socket.connectionStatus)
    }

    private var title: String {
        switch socket.connectionStatus {
        case .connected: return "Cloud Connected"
        case .connecting: return "Connecting…"
        case .disconnected: return "Cloud Offline"
        }
    }

    private var subtitle: String {
        switch socket.connectionStatus {
        case .connected: return "Ready to control your lights."
        case .connecting: return "Reaching the LIMI cloud…"
        case .disconnected: return "Internet is required for cloud control."
        }
    }

    private var iconName: String {
        switch socket.connectionStatus {
        case .connected: return "checkmark.icloud.fill"
        case .connecting: return "icloud"
        case .disconnected: return "icloud.slash"
        }
    }

    private var tint: Color {
        switch socket.connectionStatus {
        case .connected: return DeviceTheme.accent
        case .connecting: return .secondary
        case .disconnected: return .orange
        }
    }
}

// MARK: - Tab hubs (Schedule / Rooms)

/// All schedules across devices — opened from the floating calendar tab.
struct DeviceSchedulesHubView: View {
    @Query(sort: \DeviceSchedule.hour) private var schedules: [DeviceSchedule]
    @Query(sort: \RememberedLimiDevice.displayName) private var remembered: [RememberedLimiDevice]
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }
    private var usesHomeUI2: Bool { homeUITheme.selected == .two }

    var body: some View {
        NavigationStack {
            Group {
                if usesHomeUI1 {
                    homeUI1Body
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else if usesHomeUI2 {
                    homeUI2Body
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    systemBody
                }
            }
            .animation(HomeUI1Motion.soft, value: usesHomeUI1)
            .animation(HomeUI2Motion.soft, value: usesHomeUI2)
            .animation(HomeUI1Motion.soft, value: schedules.count)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .homeUI1TabRootChrome(enabled: usesHomeUI1)
            .homeUI2TabRootChrome(enabled: usesHomeUI2)
        }
    }

    // MARK: - Home UI 1

    private var homeUI1Body: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Schedule",
                        subtitle: "Timers for your LIMI lights"
                    )
                    .padding(.top, 8)

                    if schedules.isEmpty && remembered.isEmpty {
                        HomeUI1EmptyStateCard(
                            title: "No Schedules",
                            message: "Open a device from Home, then add a schedule. Schedules appear here.",
                            showsProgress: false,
                            onAdd: nil
                        )
                    } else if schedules.isEmpty {
                        HomeUI1ControlSectionCard(
                            title: "Devices",
                            footer: "No schedules yet. Pick a device to create one."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(remembered, id: \.deviceID) { device in
                                    NavigationLink {
                                        DeviceSchedulesView(
                                            device: wifiDevice(from: device),
                                            displayName: device.displayName
                                        )
                                    } label: {
                                        homeUI1DeviceLinkRow(
                                            title: device.displayName,
                                            systemImage: "lightbulb.led.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        HomeUI1ControlSectionCard(title: "Active Schedules") {
                            VStack(spacing: 10) {
                                ForEach(schedules, id: \.scheduleID) { schedule in
                                    homeUI1ActiveScheduleRow(schedule)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .top)),
                                            removal: .opacity
                                        ))
                                }
                            }
                        }

                        HomeUI1ControlSectionCard(
                            title: "Add / Edit",
                            footer: "Open a device to manage its schedules."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(remembered, id: \.deviceID) { device in
                                    NavigationLink {
                                        DeviceSchedulesView(
                                            device: wifiDevice(from: device),
                                            displayName: device.displayName
                                        )
                                    } label: {
                                        homeUI1DeviceLinkRow(
                                            title: device.displayName,
                                            systemImage: "clock.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private func homeUI1ActiveScheduleRow(_ schedule: DeviceSchedule) -> some View {
        HStack(spacing: 14) {
            Image(systemName: schedule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    schedule.isEnabled
                        ? HomeUI1Color.accentGreen
                        : HomeUI1Color.textSecondary
                )
                .frame(width: 44, height: 44)
                .homeUI1CircleElevation(schedule.isEnabled ? .recessed : .one)

            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.deviceName)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                    .lineLimit(1)
                Text("\(schedule.timeText) · \(schedule.repeatText) · \(schedule.turnOn ? "On" : "Off")")
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .animation(HomeUI1Motion.soft, value: schedule.isEnabled)
    }

    private func homeUI1DeviceLinkRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .frame(width: 44, height: 44)
                .homeUI1CircleElevation(.two)

            Text(title)
                .font(HomeUI1Type.body(15))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }

    // MARK: - Home UI 2

    private var homeUI2Body: some View {
        ZStack {
            HomeUI2ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI2PageTitle(
                        title: "Schedule",
                        subtitle: "Timers for your LIMI lights"
                    )
                    .padding(.top, 8)

                    if schedules.isEmpty && remembered.isEmpty {
                        HomeUI2EmptyStateCard(
                            title: "No Schedules",
                            message: "Open a device from Home, then add a schedule. Schedules appear here.",
                            showsProgress: false,
                            onAdd: nil
                        )
                    } else if schedules.isEmpty {
                        HomeUI2ControlSectionCard(
                            title: "Devices",
                            footer: "No schedules yet. Pick a device to create one."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(remembered, id: \.deviceID) { device in
                                    NavigationLink {
                                        DeviceSchedulesView(
                                            device: wifiDevice(from: device),
                                            displayName: device.displayName
                                        )
                                    } label: {
                                        HomeUI2LinkRow(
                                            title: device.displayName,
                                            systemImage: "lightbulb.led.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        HomeUI2ControlSectionCard(title: "Active Schedules") {
                            VStack(spacing: 10) {
                                ForEach(schedules, id: \.scheduleID) { schedule in
                                    homeUI2ActiveScheduleRow(schedule)
                                }
                            }
                        }

                        HomeUI2ControlSectionCard(
                            title: "Add / Edit",
                            footer: "Open a device to manage its schedules."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(remembered, id: \.deviceID) { device in
                                    NavigationLink {
                                        DeviceSchedulesView(
                                            device: wifiDevice(from: device),
                                            displayName: device.displayName
                                        )
                                    } label: {
                                        HomeUI2LinkRow(
                                            title: device.displayName,
                                            systemImage: "clock.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private func homeUI2ActiveScheduleRow(_ schedule: DeviceSchedule) -> some View {
        HStack(spacing: 14) {
            Image(systemName: schedule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    schedule.isEnabled
                        ? HomeUI2Color.accent
                        : HomeUI2Color.textSecondary
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: HomeUI2Radius.sm, style: .continuous)
                        .fill(HomeUI2Color.surfaceRaised)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.deviceName)
                    .font(HomeUI2Type.body(15))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .lineLimit(1)
                Text("\(schedule.timeText) · \(schedule.repeatText) · \(schedule.turnOn ? "On" : "Off")")
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }

    // MARK: - System

    @ViewBuilder
    private var systemBody: some View {
        if schedules.isEmpty && remembered.isEmpty {
            ContentUnavailableView {
                Label("No Schedules", systemImage: "calendar")
            } description: {
                Text("Open a device from Home, then add a schedule. Schedules appear here.")
            }
        } else if schedules.isEmpty {
            List {
                Section {
                    ForEach(remembered, id: \.deviceID) { device in
                        NavigationLink {
                            DeviceSchedulesView(
                                device: wifiDevice(from: device),
                                displayName: device.displayName
                            )
                        } label: {
                            Label(device.displayName, systemImage: "lightbulb.led")
                        }
                    }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("No schedules yet. Pick a device to create one.")
                }
            }
        } else {
            List {
                Section("Active Schedules") {
                    ForEach(schedules, id: \.scheduleID) { schedule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(schedule.deviceName)
                                    .font(.body)
                                Text("\(schedule.timeText) · \(schedule.repeatText) · \(schedule.turnOn ? "On" : "Off")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: schedule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                                .foregroundStyle(schedule.isEnabled ? DeviceTheme.accent : .secondary)
                        }
                    }
                }

                Section("Add / Edit") {
                    ForEach(remembered, id: \.deviceID) { device in
                        NavigationLink {
                            DeviceSchedulesView(
                                device: wifiDevice(from: device),
                                displayName: device.displayName
                            )
                        } label: {
                            Label(device.displayName, systemImage: "clock")
                        }
                    }
                }
            }
        }
    }

    private func wifiDevice(from row: RememberedLimiDevice) -> WifiDevice {
        WifiDevice(
            id: row.deviceID,
            uuid: row.deviceID,
            chennalMac: row.deviceID,
            chennalCount: row.channelCount,
            channelTypes: row.channelTypes,
            deviceName: row.displayName,
            isOnline: false
        )
    }
}

/// Rooms assigned on this phone — opened from the floating grid tab.
/// Home UI 1: neumorphic Soft UI. Other themes keep the system List.
struct DeviceRoomsHubView: View {
    @Query private var assignments: [DeviceRoomAssignment]
    @Query(sort: \RememberedLimiDevice.displayName) private var remembered: [RememberedLimiDevice]
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }
    private var usesHomeUI2: Bool { homeUITheme.selected == .two }

    private var rooms: [String] {
        Array(Set(assignments.map(\.roomName))).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesHomeUI1 {
                    homeUI1Body
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else if usesHomeUI2 {
                    homeUI2Body
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    systemBody
                }
            }
            .animation(HomeUI1Motion.soft, value: usesHomeUI1)
            .animation(HomeUI2Motion.soft, value: usesHomeUI2)
            .animation(HomeUI1Motion.soft, value: rooms.count)
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .homeUI1TabRootChrome(enabled: usesHomeUI1)
            .homeUI2TabRootChrome(enabled: usesHomeUI2)
        }
    }

    // MARK: - Home UI 1

    private var homeUI1Body: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Rooms",
                        subtitle: "Group lights and control them together"
                    )
                    .padding(.top, 8)

                    if rooms.isEmpty {
                        HomeUI1EmptyStateCard(
                            title: "No Rooms",
                            message: "On Home, long-press a device and choose Room to group lights.",
                            showsProgress: false,
                            onAdd: nil
                        )
                    } else {
                        HomeUI1ControlSectionCard(
                            title: "Your Rooms",
                            footer: "Open a room to control all lights together."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(rooms, id: \.self) { roomName in
                                    let roomDevices = devices(in: roomName)
                                    NavigationLink {
                                        RoomControlView(
                                            roomName: roomName,
                                            allDevices: allWifiDevices,
                                            roomAssignments: assignmentMap,
                                            displayNameProvider: { $0.deviceName },
                                            statusTextProvider: { $0.isOnline ? "Online" : "Offline" }
                                        )
                                    } label: {
                                        homeUI1RoomRow(
                                            roomName: roomName,
                                            deviceCount: roomDevices.count,
                                            onlineCount: roomDevices.filter(\.isOnline).count
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private func homeUI1RoomRow(
        roomName: String,
        deviceCount: Int,
        onlineCount: Int
    ) -> some View {
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
                    .lineLimit(1)
                Text(roomSubtitle(deviceCount: deviceCount, onlineCount: onlineCount))
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }

    // MARK: - Home UI 2

    private var homeUI2Body: some View {
        ZStack {
            HomeUI2ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI2PageTitle(
                        title: "Rooms",
                        subtitle: "Group lights and control them together"
                    )
                    .padding(.top, 8)

                    if rooms.isEmpty {
                        HomeUI2EmptyStateCard(
                            title: "No Rooms",
                            message: "On Home, long-press a device and choose Room to group lights.",
                            showsProgress: false,
                            onAdd: nil
                        )
                    } else {
                        HomeUI2ControlSectionCard(
                            title: "Your Rooms",
                            footer: "Open a room to control all lights together."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(rooms, id: \.self) { roomName in
                                    let roomDevices = devices(in: roomName)
                                    NavigationLink {
                                        RoomControlView(
                                            roomName: roomName,
                                            allDevices: allWifiDevices,
                                            roomAssignments: assignmentMap,
                                            displayNameProvider: { $0.deviceName },
                                            statusTextProvider: { $0.isOnline ? "Online" : "Offline" }
                                        )
                                    } label: {
                                        HomeUI2LinkRow(
                                            title: roomName,
                                            subtitle: roomSubtitle(
                                                deviceCount: roomDevices.count,
                                                onlineCount: roomDevices.filter(\.isOnline).count
                                            ),
                                            systemImage: "square.split.bottomrightquarter.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private func roomSubtitle(deviceCount: Int, onlineCount: Int) -> String {
        let devices = deviceCount == 1 ? "1 device" : "\(deviceCount) devices"
        return "\(devices) · \(onlineCount) online"
    }

    // MARK: - System

    @ViewBuilder
    private var systemBody: some View {
        if rooms.isEmpty {
            ContentUnavailableView {
                Label("No Rooms", systemImage: "square.grid.2x2")
            } description: {
                Text("On Home, long-press a device and choose Room to group lights.")
            }
        } else {
            List {
                ForEach(rooms, id: \.self) { roomName in
                    let roomDevices = devices(in: roomName)
                    NavigationLink {
                        RoomControlView(
                            roomName: roomName,
                            allDevices: allWifiDevices,
                            roomAssignments: assignmentMap,
                            displayNameProvider: { $0.deviceName },
                            statusTextProvider: { $0.isOnline ? "Online" : "Offline" }
                        )
                    } label: {
                        RoomGroupCard(
                            roomName: roomName,
                            deviceCount: roomDevices.count,
                            onlineCount: 0
                        )
                    }
                }
            }
        }
    }

    private var assignmentMap: [String: String] {
        Dictionary(uniqueKeysWithValues: assignments.map { ($0.deviceID, $0.roomName) })
    }

    private var allWifiDevices: [WifiDevice] {
        remembered.map { row in
            WifiDevice(
                id: row.deviceID,
                uuid: row.deviceID,
                chennalMac: row.deviceID,
                chennalCount: row.channelCount,
                channelTypes: row.channelTypes,
                deviceName: row.displayName,
                isOnline: false
            )
        }
    }

    private func devices(in room: String) -> [WifiDevice] {
        let ids = Set(assignments.filter { $0.roomName == room }.map(\.deviceID))
        return allWifiDevices.filter { ids.contains($0.chennalMac) || ids.contains($0.id) }
    }
}
