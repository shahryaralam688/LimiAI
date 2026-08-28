//
//  HomeUI2Components.swift
//  LIMI AI Device — Home UI 2
//
//  Dark sage building blocks: header, home card, weather, scenes,
//  room chips, vertical-toggle device tiles.
//

import SwiftUI

// MARK: - Header

struct HomeUI2Header: View {
    let userName: String
    let greeting: String
    var avatarImage: UIImage?
    var onNotifications: (() -> Void)?
    var onConnectedDevices: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(HomeUI2Type.regular(13))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                Text(userName)
                    .font(HomeUI2Type.title(20))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if onConnectedDevices != nil {
                Button {
                    DeviceAppGuidance.lightImpact()
                    onConnectedDevices?()
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(HomeUI2Color.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(HomeUI2Color.surfaceRaised))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Connected Devices")
            }
            Button {
                DeviceAppGuidance.lightImpact()
                onNotifications?()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(HomeUI2Color.surfaceRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeUI2Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HomeUI2Color.surfaceRaised)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .overlay(Circle().stroke(HomeUI2Color.border, lineWidth: 1))
    }
}

// MARK: - Home + weather row

struct HomeUI2HomeSummaryCard: View {
    let homeTitle: String
    let userCountLabel: String
    var avatarImage: UIImage?
    var onMenu: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(homeTitle)
                    .font(HomeUI2Type.title(18))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    DeviceAppGuidance.lightImpact()
                    onMenu?()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HomeUI2Color.textPrimary.opacity(0.9))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home options")
            }

            Spacer(minLength: 18)

            HStack(spacing: 8) {
                overlappingAvatars
                Text(userCountLabel)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textPrimary.opacity(0.92))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: HomeUI2Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            HomeUI2Color.accent,
                            HomeUI2Color.accentDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    // Soft abstract wave / S shape
                    GeometryReader { geo in
                        Ellipse()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.85)
                            .rotationEffect(.degrees(-18))
                            .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.15)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: HomeUI2Radius.lg, style: .continuous))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: HomeUI2Radius.lg, style: .continuous))
    }

    private var overlappingAvatars: some View {
        HStack(spacing: -8) {
            ForEach(0..<3, id: \.self) { index in
                Group {
                    if index == 0, let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(HomeUI2Color.surfaceRaised.opacity(0.85))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(HomeUI2Color.textSecondary)
                            }
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(HomeUI2Color.accentDeep, lineWidth: 1.5))
                .zIndex(Double(3 - index))
            }
        }
    }
}

struct HomeUI2WeatherCard: View {
    let temperatureLabel: String
    let condition: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(HomeUI2Color.sun)
                .symbolRenderingMode(.hierarchical)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(temperatureLabel)
                    .font(HomeUI2Type.display(26))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                Text(condition)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .homeUI2Card(fill: HomeUI2Color.surface)
    }
}

// MARK: - Scenes

struct HomeUI2ScenesCard: View {
    let selectedMood: DeviceLightMood
    var onSelect: (DeviceLightMood) -> Void
    var onAdd: (() -> Void)?

    private let moods: [DeviceLightMood] = [.relax, .morning, .night, .focus]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Home Scenes")
                    .font(HomeUI2Type.title(18))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeUI2Color.textSecondary)
            }

            HStack(spacing: 0) {
                ForEach(moods) { mood in
                    sceneButton(
                        title: sceneTitle(mood),
                        systemImage: mood.systemImage,
                        isSelected: selectedMood == mood
                    ) {
                        onSelect(mood)
                    }
                    .frame(maxWidth: .infinity)
                }
                sceneButton(title: "Add", systemImage: "plus", isSelected: false) {
                    onAdd?()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .homeUI2Card(fill: HomeUI2Color.surface)
    }

    private func sceneTitle(_ mood: DeviceLightMood) -> String {
        switch mood {
        case .relax: return "Relax"
        case .morning: return "Nature"
        case .night: return "Dreamy"
        case .focus: return "Focus"
        }
    }

    private func sceneButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            DeviceAppGuidance.lightImpact()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? HomeUI2Color.accent : HomeUI2Color.canvas)
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected ? Color.clear : HomeUI2Color.border,
                                    lineWidth: 1.2
                                )
                        }
                        .frame(width: 54, height: 54)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? HomeUI2Color.textOnAccent
                                : HomeUI2Color.textPrimary
                        )
                }
                Text(title)
                    .font(HomeUI2Type.caption(11))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Room chips

struct HomeUI2RoomChips: View {
    let rooms: [String]
    @Binding var selectedRoom: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "All Device", isSelected: selectedRoom == nil) {
                    selectedRoom = nil
                }
                ForEach(rooms, id: \.self) { room in
                    chip(title: room, isSelected: selectedRoom == room) {
                        selectedRoom = room
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            DeviceAppGuidance.lightImpact()
            withAnimation(HomeUI2Motion.soft) { action() }
        } label: {
            Text(title)
                .font(HomeUI2Type.body(13))
                .foregroundStyle(
                    isSelected
                        ? HomeUI2Color.textOnAccent
                        : HomeUI2Color.textPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? HomeUI2Color.accent : Color.clear)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    isSelected ? Color.clear : HomeUI2Color.border,
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device tile (vertical toggle)

struct HomeUI2DeviceTile: View {
    let item: DeviceHomeUIPreviewItem
    var onOpen: () -> Void
    var onToggle: () -> Void

    private var isLit: Bool { item.isOnline && item.isPowerOn }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(
                            isLit
                                ? HomeUI2Color.textOnAccent.opacity(0.9)
                                : HomeUI2Color.textPrimary
                        )
                        .frame(width: 36, height: 36)
                    Spacer(minLength: 8)
                    HomeUI2VerticalPowerToggle(
                        isOn: item.isPowerOn && item.isOnline,
                        isEnabled: item.isOnline,
                        onToggle: onToggle
                    )
                }

                Spacer(minLength: 28)

                Text(item.name)
                    .font(HomeUI2Type.body(15))
                    .foregroundStyle(
                        isLit ? HomeUI2Color.textOnAccent : HomeUI2Color.textPrimary
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(item.isOnline ? item.subtitle : "Offline")
                    .font(HomeUI2Type.caption(11))
                    .foregroundStyle(
                        isLit
                            ? HomeUI2Color.textOnAccent.opacity(0.75)
                            : HomeUI2Color.textSecondary
                    )
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background { tileBackground }
            .clipShape(RoundedRectangle(cornerRadius: HomeUI2Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(item.isOnline ? 1 : 0.72)
        .accessibilityLabel("\(item.name), \(item.isOnline ? (item.isPowerOn ? "on" : "off") : "offline")")
    }

    private var iconName: String {
        let lower = item.name.lowercased()
        if lower.contains("ac") || lower.contains("air") || lower.contains("cool") {
            return "wind"
        }
        if lower.contains("lock") || lower.contains("door") {
            return "lock.fill"
        }
        if lower.contains("cam") || lower.contains("security") {
            return "video.fill"
        }
        return item.isOnline ? "lightbulb.fill" : "poweroff"
    }

    @ViewBuilder
    private var tileBackground: some View {
        if isLit {
            LinearGradient(
                colors: [
                    HomeUI2Color.accentSoft,
                    HomeUI2Color.accent,
                    HomeUI2Color.accentDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 90, height: 90)
                    .blur(radius: 28)
                    .offset(x: 18, y: 22)
            }
        } else {
            HomeUI2Color.surface
        }
    }
}

struct HomeUI2VerticalPowerToggle: View {
    let isOn: Bool
    var isEnabled: Bool = true
    var onToggle: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            DeviceAppGuidance.lightImpact()
            onToggle()
        } label: {
            ZStack(alignment: isOn ? .top : .bottom) {
                Capsule(style: .continuous)
                    .fill(isOn ? Color.black.opacity(0.35) : HomeUI2Color.canvas.opacity(0.85))
                    .frame(width: 34, height: 58)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(HomeUI2Color.border.opacity(0.5), lineWidth: 1)
                    }
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isOn ? HomeUI2Color.accentDeep : HomeUI2Color.textSecondary)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .padding(4)
            }
            .animation(HomeUI2Motion.soft, value: isOn)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(isOn ? "Turn off" : "Turn on")
    }
}
