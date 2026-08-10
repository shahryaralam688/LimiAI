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

    var body: some View {
        NavigationStack {
            Group {
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
            .navigationTitle("Schedule")
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
struct DeviceRoomsHubView: View {
    @Query private var assignments: [DeviceRoomAssignment]
    @Query(sort: \RememberedLimiDevice.displayName) private var remembered: [RememberedLimiDevice]

    private var rooms: [String] {
        Array(Set(assignments.map(\.roomName))).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
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
            .navigationTitle("Rooms")
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
