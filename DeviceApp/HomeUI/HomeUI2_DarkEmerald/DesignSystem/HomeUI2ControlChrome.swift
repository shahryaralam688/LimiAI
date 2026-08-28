//
//  HomeUI2ControlChrome.swift
//  LIMI AI Device — Home UI 2 (Dark sage)
//
//  Shared chrome for Schedule, Rooms, Profile, and pushed control screens.
//

import SwiftUI

struct HomeUI2ControlScreenBackground: View {
    var body: some View {
        HomeUI2Color.canvas.ignoresSafeArea()
    }
}

struct HomeUI2PageTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HomeUI2Type.display(28))
                .foregroundStyle(HomeUI2Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(HomeUI2Type.regular(14))
                    .foregroundStyle(HomeUI2Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct HomeUI2ControlSectionCard<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(HomeUI2Type.title(18))
                .foregroundStyle(HomeUI2Color.textPrimary)

            content()

            if let footer {
                Text(footer)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HomeUI2Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeUI2Card(cornerRadius: HomeUI2Radius.md, fill: HomeUI2Color.surface)
    }
}

struct HomeUI2EmptyStateCard: View {
    let title: String
    let message: String
    var showsProgress: Bool
    var onAdd: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: showsProgress ? "wifi" : "calendar")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(HomeUI2Color.accent)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(HomeUI2Color.surfaceRaised)
                )

            Text(title)
                .font(HomeUI2Type.title(18))
                .foregroundStyle(HomeUI2Color.textPrimary)

            Text(message)
                .font(HomeUI2Type.regular(14))
                .foregroundStyle(HomeUI2Color.textSecondary)
                .multilineTextAlignment(.center)

            if showsProgress {
                ProgressView()
                    .tint(HomeUI2Color.accent)
                    .padding(.top, 2)
            } else if let onAdd {
                Button(action: onAdd) {
                    Label("Add Device", systemImage: "plus")
                        .font(HomeUI2Type.body(15))
                        .foregroundStyle(HomeUI2Color.textOnAccent)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(HomeUI2Color.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .homeUI2Card(cornerRadius: HomeUI2Radius.md, fill: HomeUI2Color.surface)
    }
}

struct HomeUI2LinkRow: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomeUI2Color.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: HomeUI2Radius.sm, style: .continuous)
                        .fill(HomeUI2Color.surfaceRaised)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HomeUI2Type.body(15))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(HomeUI2Type.caption(12))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI2Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }
}

struct HomeUI2ControlConnectionBanner: View {
    @ObservedObject private var socket = LightControllingSocket.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: socket.connectionStatus == .connecting)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HomeUI2Type.body(14))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                Text(subtitle)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
            }

            Spacer(minLength: 0)

            if socket.connectionStatus == .connecting {
                ProgressView()
                    .controlSize(.small)
                    .tint(HomeUI2Color.accent)
            } else if socket.connectionStatus == .disconnected {
                Button("Retry") {
                    DeviceAppGuidance.lightImpact()
                    LightControllingSocket.shared.connect()
                }
                .font(HomeUI2Type.body(13))
                .foregroundStyle(HomeUI2Color.textOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(HomeUI2Color.accent)
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
        .animation(HomeUI2Motion.soft, value: socket.connectionStatus)
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
        case .disconnected: return "icloud.slash"
        }
    }

    private var tint: Color {
        switch socket.connectionStatus {
        case .connected: return HomeUI2Color.accent
        case .connecting: return HomeUI2Color.sun
        case .disconnected: return Color.orange
        }
    }
}

struct HomeUI2ActionRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeUI2Color.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomeUI2Color.surfaceRaised)
                )

            Text(title)
                .font(HomeUI2Type.body(15))
                .foregroundStyle(HomeUI2Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI2Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }
}

struct HomeUI2ActionRow: View {
    let title: String
    let systemImage: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            DeviceAppGuidance.lightImpact()
            action()
        } label: {
            HomeUI2ActionRowLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct HomeUI2StatusBadge: View {
    let on: Bool
    let onText: String
    let offText: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(on ? HomeUI2Color.accent : HomeUI2Color.textSecondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(on ? onText : offText)
                .font(HomeUI2Type.caption(12))
                .foregroundStyle(HomeUI2Color.textSecondary)
        }
    }
}

struct HomeUI2InsetRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }
}

struct HomeUI2ToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? HomeUI2Color.accent : HomeUI2Color.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomeUI2Color.surfaceRaised)
                )

            Text(title)
                .font(HomeUI2Type.body(15))
                .foregroundStyle(HomeUI2Color.textPrimary)

            Spacer(minLength: 8)

            Button {
                guard isEnabled else { return }
                DeviceAppGuidance.lightImpact()
                let next = !isOn
                isOn = next
                onChange(next)
            } label: {
                Text(isOn ? "On" : "Off")
                    .font(HomeUI2Type.body(13))
                    .foregroundStyle(isOn ? HomeUI2Color.textOnAccent : HomeUI2Color.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isOn ? HomeUI2Color.accent : HomeUI2Color.surfaceRaised)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .animation(HomeUI2Motion.soft, value: isOn)
    }
}

struct HomeUI2SliderRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    var valueLabel: String
    var tint: Color = HomeUI2Color.accent
    var isEnabled: Bool = true
    var onEditingEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeUI2Color.textSecondary)

                Text(title)
                    .font(HomeUI2Type.body(15))
                    .foregroundStyle(HomeUI2Color.textPrimary)

                Spacer(minLength: 8)

                if !valueLabel.isEmpty {
                    Text(valueLabel)
                        .font(HomeUI2Type.caption(13))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                        .monospacedDigit()
                }
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
            .opacity(isEnabled ? 1 : 0.45)
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }
}

struct HomeUI2ControlDeviceRow: View {
    let name: String
    let subtitle: String
    let isOnline: Bool
    let statusText: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isOnline ? "lightbulb.led.fill" : "lightbulb.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOnline ? HomeUI2Color.accent : HomeUI2Color.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: HomeUI2Radius.sm, style: .continuous)
                        .fill(HomeUI2Color.surfaceRaised)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(HomeUI2Type.body(15))
                    .foregroundStyle(HomeUI2Color.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(HomeUI2Type.caption(12))
                    .foregroundStyle(HomeUI2Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(statusText)
                .font(HomeUI2Type.caption(11))
                .foregroundStyle(isOnline ? HomeUI2Color.accent : HomeUI2Color.textSecondary)
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
    }
}

extension View {
    func homeUI2ControlNavigationChrome(enabled: Bool) -> some View {
        Group {
            if enabled {
                self
                    .toolbarBackground(HomeUI2Color.canvas, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            } else {
                self
            }
        }
    }

    func homeUI2TabRootChrome(enabled: Bool) -> some View {
        Group {
            if enabled {
                self.toolbar(.hidden, for: .navigationBar)
            } else {
                self
            }
        }
    }
}
