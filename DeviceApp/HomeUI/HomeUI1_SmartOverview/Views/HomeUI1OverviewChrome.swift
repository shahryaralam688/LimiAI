//
//  HomeUI1OverviewChrome.swift
//  LIMI AI Device — Home UI 1
//
//  Smart-home overview chrome — stronger neumorphic depth.
//

import SwiftUI

enum DeviceLightMood: String, CaseIterable, Identifiable {
    case morning, night, relax, focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .night: return "Night Mood"
        case .relax: return "Relax"
        case .focus: return "Focus"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .night: return "moon.fill"
        case .relax: return "cloud.moon.fill"
        case .focus: return "sparkles"
        }
    }

    var command: LimiCommand {
        switch self {
        case .morning:
            return .cct(channel: 1, brightness: 85, ww: 35, cw: 100)
        case .night:
            return .cct(channel: 1, brightness: 18, ww: 100, cw: 15)
        case .relax:
            return .cct(channel: 1, brightness: 45, ww: 90, cw: 35)
        case .focus:
            return .cct(channel: 1, brightness: 95, ww: 20, cw: 100)
        }
    }
}

struct DeviceSoftIconButton: View {
    let systemImage: String
    var size: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .frame(width: size, height: size)
                .homeUI1CircleElevation(.two)
        }
        .buttonStyle(.plain)
    }
}

struct DeviceSmartHomeHeader: View {
    let userName: String
    let greeting: String
    var avatarImage: UIImage?
    var onNotifications: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text("Hi, \(userName)")
                    .font(HomeUI1Type.title(20))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                Text(greeting)
                    .font(HomeUI1Type.regular(14))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }
            Spacer(minLength: 8)
            DeviceSoftIconButton(systemImage: "bell") {
                onNotifications?()
            }
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HomeUI1Color.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HomeUI1Color.canvas)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .homeUI1CircleElevation(.recessed)
    }
}

/// Title + one search control that **resizes** from circle → full field (same view).
struct DeviceSmartHomeTitleRow: View {
    @Binding var isSearching: Bool
    @Binding var searchText: String

    @FocusState private var isFieldFocused: Bool

    private let iconSize: CGFloat = 46
    private var morphAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        HStack(alignment: .center, spacing: isSearching ? 0 : 12) {
            Text("Your Smart Home Overview")
                .font(HomeUI1Type.display(28))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isSearching ? 0 : 1)
                .frame(maxWidth: isSearching ? 0 : .infinity, alignment: .leading)
                .clipped()
                .allowsHitTesting(!isSearching)

            morphingSearchControl
                .frame(width: isSearching ? nil : iconSize)
                .frame(maxWidth: isSearching ? .infinity : iconSize)
                .frame(height: iconSize)
        }
        .frame(maxWidth: .infinity, minHeight: iconSize, alignment: .leading)
        .animation(morphAnimation, value: isSearching)
        .onChange(of: isSearching) { _, open in
            if open {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    isFieldFocused = true
                }
            } else {
                isFieldFocused = false
            }
        }
    }

    /// Same neumorphic pill — width grows from the circle; field + close fade in.
    private var morphingSearchControl: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .frame(width: isSearching ? 22 : iconSize, height: iconSize)
                .padding(.leading, isSearching ? 14 : 0)

            TextField("Search devices or rooms", text: $searchText)
                .font(HomeUI1Type.regular(16))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .submitLabel(.search)
                .opacity(isSearching ? 1 : 0)
                .frame(maxWidth: isSearching ? .infinity : 0)
                .clipped()
                .allowsHitTesting(isSearching)

            Button {
                DeviceAppGuidance.lightImpact()
                searchText = ""
                withAnimation(morphAnimation) { isSearching = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .homeUI1CircleElevation(.one)
            }
            .buttonStyle(.plain)
            .opacity(isSearching ? 1 : 0)
            .frame(width: isSearching ? 40 : 0)
            .padding(.trailing, isSearching ? 6 : 0)
            .clipped()
            .allowsHitTesting(isSearching)
            .accessibilityLabel("Close search")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .homeUI1Elevation(
            isSearching ? .recessed : .two,
            cornerRadius: iconSize / 2,
            fill: isSearching ? HomeUI1Color.canvas : HomeUI1Color.surface
        )
        // Collapsed: whole circle is the open tap. Expanded: TextField / X own the hits.
        .overlay {
            if !isSearching {
                Color.clear
                    .contentShape(Circle())
                    .onTapGesture {
                        DeviceAppGuidance.lightImpact()
                        withAnimation(morphAnimation) { isSearching = true }
                    }
                    .accessibilityLabel("Search")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }
}

struct DeviceRoomFilterBar: View {
    let rooms: [String]
    @Binding var selectedRoom: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                HomeUI1Chip(
                    title: "All",
                    isSelected: selectedRoom == nil
                ) { selectedRoom = nil }

                ForEach(rooms, id: \.self) { room in
                    HomeUI1Chip(
                        title: room,
                        isSelected: selectedRoom == room
                    ) { selectedRoom = room }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        // Outer bar stays raised; chips inside handle pressed / unpressed.
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .padding(.horizontal, 20)
    }
}

struct DeviceFeaturedCard: View {
    let name: String
    let subtitle: String
    let isOnline: Bool
    let isPowerOn: Bool
    let channelTypes: [String]
    let selectedMood: DeviceLightMood
    var onTogglePower: () -> Void
    var onSelectMood: (DeviceLightMood) -> Void
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(HomeUI1Type.title(20))
                        .foregroundStyle(HomeUI1Color.textPrimary)
                    Text(subtitle)
                        .font(HomeUI1Type.regular(13))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
                Spacer(minLength: 8)
                powerToggle
            }

            Button(action: onOpen) {
                featuredVisual
                    .frame(maxWidth: .infinity)
                    .frame(height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .homeUI1Elevation(.recessed, cornerRadius: 18, fill: HomeUI1Color.canvas)
            }
            .buttonStyle(.plain)

            moodBar
        }
        .padding(20)
        .homeUI1Elevation(.four, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }

    private var powerToggle: some View {
        Button {
            guard isOnline else { return }
            onTogglePower()
        } label: {
            ZStack(alignment: isPowerOn ? .trailing : .leading) {
                Capsule()
                    .fill(HomeUI1Color.canvas)
                    .frame(width: 74, height: 40)
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isPowerOn ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(HomeUI1Color.surface)
                            .shadow(color: HomeUI1Color.shadowDark.opacity(0.55), radius: 3, x: 2, y: 2)
                            .shadow(color: HomeUI1Color.shadowLight.opacity(1), radius: 3, x: -2, y: -2)
                    }
                    .padding(4)
            }
            .homeUI1CapsuleElevation(isPowerOn ? .recessed : .two, fill: HomeUI1Color.surface)
        }
        .buttonStyle(.plain)
        .opacity(isOnline ? 1 : 0.45)
        .accessibilityLabel(isPowerOn ? "Turn off" : "Turn on")
        .animation(HomeUI1Motion.soft, value: isPowerOn)
    }

    private var featuredVisual: some View {
        HomeUI1PendantHero(isOn: isPowerOn, isOnline: isOnline)
    }

    private var moodBar: some View {
        HStack(spacing: 4) {
            ForEach(DeviceLightMood.allCases) { mood in
                Button {
                    guard isOnline else { return }
                    onSelectMood(mood)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mood.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                selectedMood == mood
                                    ? HomeUI1Color.accentGreen
                                    : HomeUI1Color.textSecondary
                            )
                            .frame(width: 42, height: 42)
                            .homeUI1CircleElevation(
                                selectedMood == mood ? .recessed : .one,
                                fill: HomeUI1Color.surface
                            )
                        Text(mood.title)
                            .font(HomeUI1Type.caption(10))
                            .foregroundStyle(
                                selectedMood == mood
                                    ? HomeUI1Color.accentGreen
                                    : HomeUI1Color.textSecondary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
        .opacity(isOnline ? 1 : 0.45)
        .animation(HomeUI1Motion.soft, value: selectedMood)
    }
}

struct DeviceManageRowCard: View {
    let name: String
    let subtitle: String
    let isOnline: Bool
    let isPowerOn: Bool
    var statusBadge: String?
    var onTogglePower: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    HomeUI1PendantThumb(isOn: isPowerOn, isOnline: isOnline, size: 44)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .homeUI1Elevation(.two, cornerRadius: 14, fill: HomeUI1Color.surface)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(HomeUI1Type.body(16))
                            .foregroundStyle(HomeUI1Color.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(HomeUI1Type.caption(12))
                            .foregroundStyle(HomeUI1Color.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
            }
            .buttonStyle(.plain)

            if let statusBadge {
                Text(statusBadge)
                    .font(HomeUI1Type.body(12))
                    .foregroundStyle(HomeUI1Color.accentGreen)
            }

            compactPowerToggle
        }
        .padding(16)
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .opacity(isOnline ? 1 : 0.55)
    }

    private var compactPowerToggle: some View {
        Button {
            guard isOnline else { return }
            onTogglePower()
        } label: {
            ZStack(alignment: isPowerOn ? .trailing : .leading) {
                Capsule()
                    .fill(HomeUI1Color.canvas)
                    .frame(width: 58, height: 34)
                Circle()
                    .fill(HomeUI1Color.surface)
                    .frame(width: 26, height: 26)
                    .shadow(color: HomeUI1Color.shadowDark.opacity(0.5), radius: 2, x: 2, y: 2)
                    .shadow(color: HomeUI1Color.shadowLight.opacity(1), radius: 2, x: -2, y: -2)
                    .padding(4)
                    .overlay {
                        if isPowerOn {
                            Circle()
                                .stroke(HomeUI1Color.accentGreen.opacity(0.55), lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                        }
                    }
            }
            .homeUI1CapsuleElevation(isPowerOn ? .recessed : .two, fill: HomeUI1Color.surface)
        }
        .buttonStyle(.plain)
        .disabled(!isOnline)
        .animation(HomeUI1Motion.soft, value: isPowerOn)
    }
}

struct DeviceManageSectionHeader: View {
    var onAdd: () -> Void

    var body: some View {
        HStack {
            Text("Manage your device")
                .font(HomeUI1Type.title(20))
                .foregroundStyle(HomeUI1Color.textPrimary)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HomeUI1Color.accentGreen)
                    .frame(width: 44, height: 44)
                    .homeUI1CircleElevation(.two, fill: HomeUI1Color.surface)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Device")
        }
    }
}

/// Empty / loading card for Home UI 1 overview.
struct HomeUI1EmptyStateCard: View {
    let title: String
    let message: String
    var showsProgress: Bool
    var onAdd: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: showsProgress ? "wifi" : "lightbulb.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .frame(width: 72, height: 72)
                .homeUI1CircleElevation(.recessed)

            Text(title)
                .font(HomeUI1Type.title(18))
                .foregroundStyle(HomeUI1Color.textPrimary)

            Text(message)
                .font(HomeUI1Type.regular(14))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .multilineTextAlignment(.center)

            if showsProgress {
                ProgressView()
                    .tint(HomeUI1Color.accentGreen)
                    .padding(.top, 2)
            } else if let onAdd {
                Button(action: onAdd) {
                    Label("Add Device", systemImage: "plus")
                        .font(HomeUI1Type.body(15))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .homeUI1CapsuleElevation(.two)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md)
    }
}
