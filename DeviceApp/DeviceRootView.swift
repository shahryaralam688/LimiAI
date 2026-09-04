//
//  DeviceRootView.swift
//  LIMI AI Device
//
//  Routes between sign-in and the devices home, driven by AuthManager.
//  Owns cloud socket lifecycle so leaving the Devices tab does not drop MQTT.
//
//  Cold-start safety: do NOT mount Home / Sign In under the splash.
//  Building DeviceMainTabView while opacity==0 caused white-flash crashes
//  after force-quit → relaunch.
//

import SwiftUI
import SwiftData

struct DeviceRootView: View {
    @ObservedObject private var auth = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showSplash = true
    @State private var didWarmHeavyServices = false

    var body: some View {
        ZStack {
            // Always paint Soft UI canvas first — avoids system white flash.
            HomeUI1Color.canvas.ignoresSafeArea()

            if showSplash {
                DeviceSplashView {
                    finishSplash()
                }
                .transition(.opacity)
                .zIndex(10)
            } else if auth.isAuthenticated {
                // Cloud→BLE offer uses home notification badge (not a blocking alert).
                DeviceMainTabView()
                    .transition(.opacity)
            } else {
                DeviceSignInView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.25), value: auth.isAuthenticated)
        .onAppear {
            SessionDeviceCacheCoordinator.shared.attachSwiftDataWipe { [modelContext] in
                SessionRememberedDeviceWipe.deleteAll(in: modelContext)
            }
        }
        .task {
            await warmHeavyServicesIfNeeded()
        }
        .task(id: showSplash) {
            // Failsafe: never leave user on a blank/white launch forever.
            guard showSplash else { return }
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            if showSplash {
                finishSplash()
            }
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            // Only connect after splash — avoids socket work during cold launch.
            guard !showSplash else { return }
            syncCloudConnection()
        }
        .onChange(of: scenePhase) { _, phase in
            guard !showSplash else { return }
            if phase == .active {
                syncCloudConnection()
            } else if phase == .background {
                DevicePresenceCoordinator.shared.cancelRefresh()
            }
        }
        .onChange(of: showSplash) { _, showing in
            if !showing {
                // Cache/session work after splash is gone — never blocks this screen.
                SessionDeviceCacheCoordinator.shared.start()
                syncCloudConnection()
            }
        }
    }

    private func finishSplash() {
        guard showSplash else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            showSplash = false
        }
    }

    private func syncCloudConnection() {
        if auth.isAuthenticated {
            LightControllingSocket.shared.connect()
        } else {
            LightControllingSocket.shared.disconnect()
        }
    }

    /// Defer BLE / transport / Bonjour stack until after first frame.
    /// Creating them inside `App.init` races with UIKit scene restore after terminate.
    @MainActor
    private func warmHeavyServicesIfNeeded() async {
        guard !didWarmHeavyServices else { return }
        didWarmHeavyServices = true

        // Let the splash paint one frame first.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        BluetoothManager.shared.configureForDeviceCompanionApp()
        _ = LimiTransport.shared
        _ = DeviceTransportRegistry.shared

        // App-global (tab-independent) presence lifecycle: clear stale MQTT on
        // disconnect and re-probe on reconnect regardless of the active tab.
        // Inject the virtual-device member ids so presence re-probes also cover
        // hubs that are only known through cloud virtual groups.
        SocketPresenceLifecycle.virtualDeviceIdProvider = {
            var keys = Set<String>()
            for member in VirtualDeviceStore.shared.enabledHardwareIds {
                let key = LimiDeviceNaming.normalizedHardwareId(member)
                if !key.isEmpty { keys.insert(key) }
            }
            for group in VirtualDeviceStore.shared.remoteGroups {
                for mac in group.mac_addresses {
                    let key = LimiDeviceNaming.normalizedHardwareIdFromMAC(mac)
                    if !key.isEmpty { keys.insert(key) }
                }
            }
            return keys
        }
        SocketPresenceLifecycle.shared.start()
    }
}

/// Root tabs with a floating bottom bar (reference smart-home layout, LIMI emerald).
/// Uses `safeAreaInset` so NavigationStack content cannot cover the bar.
struct DeviceMainTabView: View {
    @State private var selectedTab: DeviceRootTab = .home

    var body: some View {
        ZStack {
            HomeUI1AnimatedCanvas()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomChrome
                        .frame(maxWidth: .infinity)
                        .background(HomeUI1Color.canvas.ignoresSafeArea(edges: .bottom))
                }
        }
        .preferredColorScheme(.dark)
    }

    /// Floating bottom chrome only — no full-width white strip behind the bar.
    private var bottomChrome: some View {
        HomeUI1BottomBar(selectedTab: $selectedTab)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private var tabContent: some View {
        // Mount only the active tab after cold start — keeps terminate→relaunch light.
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

/// Dark sage floating bar — Home UI 2 reference style.
struct HomeUI2BottomBar: View {
    @Binding var selectedTab: DeviceRootTab

    var body: some View {
        HStack(spacing: 6) {
            tab(.home, systemImage: "house.fill", title: "Home")
            tab(.schedule, systemImage: "calendar", title: nil)
            tab(.rooms, systemImage: "square.grid.2x2.fill", title: nil)
            tab(.profile, systemImage: "gearshape", title: nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(HomeUI2Color.surface.opacity(0.92))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(HomeUI2Color.border, lineWidth: 1)
                }
                .shadow(color: HomeUI2Color.shadow, radius: 16, y: 6)
        }
        .accessibilityElement(children: .contain)
    }

    private func tab(_ tab: DeviceRootTab, systemImage: String, title: String?) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            DeviceAppGuidance.lightImpact()
            withAnimation(HomeUI2Motion.soft) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                if isSelected, let title {
                    Text(title)
                        .font(HomeUI2Type.body(13))
                }
            }
            .foregroundStyle(
                isSelected
                    ? HomeUI2Color.textOnAccent
                    : HomeUI2Color.textPrimary
            )
            .padding(.horizontal, isSelected ? 14 : 12)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(HomeUI2Color.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title ?? String(describing: tab))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
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

#Preview {
    DeviceRootView()
}
