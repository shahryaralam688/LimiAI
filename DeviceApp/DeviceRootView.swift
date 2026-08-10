//
//  DeviceRootView.swift
//  LIMI AI Device
//
//  Routes between sign-in and the devices home, driven by AuthManager.
//  Owns cloud socket lifecycle so leaving the Devices tab does not drop MQTT.
//

import SwiftUI

struct DeviceRootView: View {
    @ObservedObject private var auth = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isAuthenticated {
                DeviceMainTabView()
                    .cloudOfflineLocalSwitchAlert()
            } else {
                DeviceSignInView()
            }
        }
        .onAppear { syncCloudConnection() }
        .onChange(of: auth.isAuthenticated) { _, _ in
            syncCloudConnection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncCloudConnection()
            }
        }
    }

    private func syncCloudConnection() {
        if auth.isAuthenticated {
            LightControllingSocket.shared.connect()
        } else {
            LightControllingSocket.shared.disconnect()
        }
    }
}

/// Root tabs with a floating bottom bar (reference smart-home layout, LIMI emerald).
/// Uses `safeAreaInset` so NavigationStack content cannot cover the bar.
/// A small side button opens a slide-in drawer for quick navigation.
struct DeviceMainTabView: View {
    @State private var selectedTab: DeviceRootTab = .home
    @State private var isDrawerOpen = false
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    private var usesHomeUI1Chrome: Bool {
        homeUITheme.selected == .one
    }

    var body: some View {
        ZStack(alignment: .leading) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomChrome
                }

            // Small side control (middle-left) — opens the theme drawer.
            if !isDrawerOpen {
                Group {
                    if usesHomeUI1Chrome {
                        HomeUI1MenuButton {
                            DeviceAppGuidance.lightImpact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                isDrawerOpen = true
                            }
                        }
                    } else {
                        Button {
                            DeviceAppGuidance.lightImpact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                isDrawerOpen = true
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    Capsule()
                                        .fill(DeviceTheme.accent)
                                        .shadow(color: DeviceTheme.accent.opacity(0.45), radius: 8, y: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open theme menu")
                    }
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .zIndex(20)
            }

            DeviceSideDrawer(isOpen: $isDrawerOpen, selectedTab: $selectedTab)
                .zIndex(30)
        }
        .background {
            if usesHomeUI1Chrome {
                HomeUI1AnimatedCanvas()
            }
        }
    }

    /// Floating bottom chrome only — no full-width white strip behind the bar.
    @ViewBuilder
    private var bottomChrome: some View {
        Group {
            if usesHomeUI1Chrome {
                HomeUI1BottomBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            } else {
                DeviceFloatingBottomBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .animation(HomeUI1Motion.soft, value: homeUITheme.selected)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            DeviceHomeView()
        case .schedule:
            DeviceSchedulesHubView()
        case .rooms:
            DeviceRoomsHubView()
        case .profile:
            DeviceProfileView()
        }
    }
}

enum DeviceRootTab: Hashable {
    case home
    case schedule
    case rooms
    case profile
}

/// Dark floating capsule — Home / Schedule / Rooms / Profile.
struct DeviceFloatingBottomBar: View {
    @Binding var selectedTab: DeviceRootTab

    private let barHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            barButton(.home, systemImage: "house.fill")
            barButton(.schedule, systemImage: "calendar")
            barButton(.rooms, systemImage: "square.grid.2x2.fill")
            barButton(.profile, systemImage: "person.fill")
        }
        .padding(.horizontal, 8)
        .frame(height: barHeight)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        }
        .accessibilityElement(children: .contain)
    }

    private func barButton(_ tab: DeviceRootTab, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            DeviceAppGuidance.lightImpact()
            withAnimation(.snappy(duration: 0.25)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(DeviceTheme.accent)
                        .frame(width: 48, height: 48)
                        .shadow(color: DeviceTheme.accent.opacity(0.5), radius: 8, y: 2)
                        .offset(y: -6)
                }

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .offset(y: isSelected ? -6 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle(for: tab))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityTitle(for tab: DeviceRootTab) -> String {
        switch tab {
        case .home: return "Home"
        case .schedule: return "Schedule"
        case .rooms: return "Rooms"
        case .profile: return "Profile"
        }
    }
}

// MARK: - Side drawer (temporary Home UI theme picker)

struct DeviceSideDrawer: View {
    @Binding var isOpen: Bool
    @Binding var selectedTab: DeviceRootTab
    @ObservedObject private var themeStore = DeviceHomeUIThemeStore.shared
    @ObservedObject private var userDataManager = UserDataManager.shared

    private let drawerWidth: CGFloat = 280

    private var userName: String {
        let name = userDataManager.userData?.username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return "LIMI User"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeDrawer() }
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        drawerHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 20)

                        Divider().opacity(0.25)

                        Text("THEME PREVIEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        VStack(spacing: 6) {
                            ForEach(DeviceHomeUIVariant.allCases) { variant in
                                themeRow(variant)
                            }
                        }
                        .padding(.horizontal, 14)

                        Spacer()

                        hideSidebarButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        Text("Temporary — for client theme review only")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                    .frame(width: drawerWidth, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 8)

                    // Edge hide control — collapses the sidebar.
                    Button(action: closeDrawer) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 56)
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 12,
                                    topTrailingRadius: 12,
                                    style: .continuous
                                )
                                .fill(DeviceTheme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide sidebar")
                    .offset(x: 14)
                }
                .offset(x: isOpen ? 0 : -drawerWidth - 40)

                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(isOpen)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isOpen)
    }

    private var hideSidebarButton: some View {
        Button(action: closeDrawer) {
            HStack(spacing: 10) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 15, weight: .semibold))
                Text("Hide sidebar")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(DeviceTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DeviceTheme.accent.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide sidebar")
    }

    private var drawerHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let image = userDataManager.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DeviceTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DeviceTheme.accent.opacity(0.15))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("Pick a Home UI to review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button(action: closeDrawer) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide sidebar")
        }
    }

    private func themeRow(_ variant: DeviceHomeUIVariant) -> some View {
        let isSelected = themeStore.selected == variant
        return Button {
            DeviceAppGuidance.lightImpact()
            themeStore.selected = variant
            selectedTab = .home
            closeDrawer()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: variant.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : DeviceTheme.accent)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? DeviceTheme.accent : DeviceTheme.accent.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(variant.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DeviceTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? DeviceTheme.accent.opacity(0.10) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            isOpen = false
        }
    }
}

#Preview {
    DeviceRootView()
}
