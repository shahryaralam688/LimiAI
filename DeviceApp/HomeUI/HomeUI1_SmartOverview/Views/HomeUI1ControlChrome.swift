//
//  HomeUI1ControlChrome.swift
//  LIMI AI Device — Home UI 1
//
//  Neumorphic chrome for individual + room (group) control screens.
//  Only used when DeviceHomeUIThemeStore.selected == .one.
//

import SwiftUI

/// Full-bleed Home UI 1 canvas behind control content.
struct HomeUI1ControlScreenBackground: View {
    var body: some View {
        HomeUI1AnimatedCanvas()
    }
}

struct HomeUI1ControlConnectionBanner: View {
    @ObservedObject private var socket = LightControllingSocket.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: socket.connectionStatus == .connecting)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HomeUI1Type.body(14))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                Text(subtitle)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }

            Spacer(minLength: 0)

            if socket.connectionStatus == .connecting {
                ProgressView()
                    .controlSize(.small)
                    .tint(HomeUI1Color.accentGreen)
            } else if socket.connectionStatus == .disconnected {
                Button("Retry") {
                    DeviceAppGuidance.lightImpact()
                    LightControllingSocket.shared.connect()
                }
                .font(HomeUI1Type.body(13))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.surface)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
        .animation(HomeUI1Motion.soft, value: socket.connectionStatus)
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
        case .connected: return "Commands use the live cloud path"
        case .connecting: return "Reaching the cloud…"
        case .disconnected: return "Reconnect to control devices"
        }
    }

    private var iconName: String {
        switch socket.connectionStatus {
        case .connected: return "cloud.fill"
        case .connecting: return "cloud"
        case .disconnected: return "cloud.slash"
        }
    }

    private var tint: Color {
        switch socket.connectionStatus {
        case .connected: return HomeUI1Color.accentGreen
        case .connecting: return HomeUI1Color.warning
        case .disconnected: return HomeUI1Color.accentRed
        }
    }
}

struct HomeUI1ControlSectionCard<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(HomeUI1Type.title(18))
                .foregroundStyle(HomeUI1Color.textPrimary)

            content()

            if let footer {
                Text(footer)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HomeUI1Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }
}

struct HomeUI1NeumorphicToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                .frame(width: 36, height: 36)
                .homeUI1CircleElevation(isOn ? .recessed : .one)

            Text(title)
                .font(HomeUI1Type.body(15))
                .foregroundStyle(HomeUI1Color.textPrimary)

            Spacer(minLength: 8)

            Button {
                guard isEnabled else { return }
                DeviceAppGuidance.lightImpact()
                let next = !isOn
                isOn = next
                onChange(next)
            } label: {
                Text(isOn ? "On" : "Off")
                    .font(HomeUI1Type.body(13))
                    .foregroundStyle(isOn ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .homeUI1Elevation(
                        isOn ? .recessed : .one,
                        cornerRadius: HomeUI1Radius.nav,
                        fill: HomeUI1Color.surface
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .animation(HomeUI1Motion.soft, value: isOn)
    }
}

struct HomeUI1NeumorphicSliderRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    var valueLabel: String
    var tint: Color = HomeUI1Color.accentGreen
    var isEnabled: Bool = true
    var onEditingEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeUI1Color.textSecondary)

                Text(title)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)

                Spacer(minLength: 8)

                Text(valueLabel)
                    .font(HomeUI1Type.caption(13))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .monospacedDigit()
            }

            Slider(
                value: $value,
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing { onEditingEnded() }
                }
            )
            .tint(tint)
            .disabled(!isEnabled)
        }
        .padding(14)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct HomeUI1ControlDeviceRow: View {
    let name: String
    let subtitle: String
    let isOnline: Bool
    var statusText: String = ""

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.led.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOnline ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                .frame(width: 44, height: 44)
                .homeUI1CircleElevation(isOnline ? .two : .recessed)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? HomeUI1Color.accentGreen : HomeUI1Color.shadowDark)
                    .frame(width: 8, height: 8)
                Text(statusText.isEmpty ? (isOnline ? "Online" : "Offline") : statusText)
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .opacity(isOnline ? 1 : 0.5)
    }
}

struct HomeUI1ControlChannelRow: View {
    let title: String
    let typeLabel: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .frame(width: 44, height: 44)
                .homeUI1CircleElevation(.two)

            Text(title)
                .font(HomeUI1Type.body(15))
                .foregroundStyle(HomeUI1Color.textPrimary)

            Spacer(minLength: 8)

            Text(typeLabel)
                .font(HomeUI1Type.caption(12))
                .foregroundStyle(HomeUI1Color.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }
}

extension View {
    /// Navigation chrome for Home UI 1 control screens only.
    func homeUI1ControlNavigationChrome(enabled: Bool) -> some View {
        Group {
            if enabled {
                self
                    .toolbarBackground(HomeUI1Color.canvas, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.light, for: .navigationBar)
            } else {
                self
            }
        }
    }
}
