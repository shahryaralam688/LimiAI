//
//  VoicePendantUI.swift
//  Limi
//
//  Shared UI building blocks for Voice Pendant — uses global Limi design tokens.
//

import SwiftUI

// MARK: - Section Card

struct VPSectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(LimiTypography.headline)
                            .foregroundColor(.appTextPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appTextMuted)
                    }
                }
            }
            content()
        }
        .padding(LimiSpacing.innerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .limiPanel(cornerRadius: LimiRadius.medium)
    }
}

// MARK: - Navigation Row

struct VPNavRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = .brandHighlight

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(LimiTypography.headline)
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: LimiRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary)
                Text(subtitle)
                    .font(LimiTypography.caption)
                    .foregroundColor(.appTextMuted)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(LimiTypography.footnote)
                .foregroundColor(.appTextMuted)
        }
        .padding(LimiSpacing.innerPadding)
        .limiPanel(cornerRadius: LimiRadius.medium)
        .contentShape(Rectangle())
    }
}

// MARK: - Screen chrome

struct VPScreenChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        LimiScreen(showParticles: false) {
            content()
        }
    }
}

// MARK: - Divider

struct VPDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appGlassFillMedium)
            .frame(height: 1)
    }
}

// MARK: - Icon badge

struct VPIconBadge: View {
    let systemName: String
    var tint: Color = .brandHighlight

    var body: some View {
        Image(systemName: systemName)
            .font(LimiTypography.headline)
            .foregroundColor(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: LimiRadius.small))
    }
}

// MARK: - List row button

struct VPListRowButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var accent: Color = .brandHighlight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VPIconBadge(systemName: icon, tint: accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(LimiTypography.caption)
                            .foregroundColor(.appTextMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(LimiTypography.caption)
                    .foregroundColor(.appTextMuted)
            }
            .padding(LimiSpacing.innerPadding)
            .limiPanel(cornerRadius: LimiRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Pill (device connection)

struct VPStatusPill: View {
    let status: VoicePendantStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(status.displayName)
                .font(LimiTypography.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .online: return .brandAction
        case .pairing: return .appWarning
        case .offline: return .appTextMuted
        }
    }
}

// MARK: - Metric Chip

struct VPMetricChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
            Text(value)
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
            Text(label)
                .font(LimiTypography.caption2)
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .limiPanel(cornerRadius: LimiRadius.small)
    }
}

// MARK: - Transient Toast

private struct VPToastModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String = "checkmark.circle.fill"

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(LimiTypography.headline)
                        .foregroundColor(.brandAction)
                    Text(message)
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }
                .padding(LimiSpacing.innerPadding)
                .limiPanel(cornerRadius: LimiRadius.medium)
                .padding(.horizontal, LimiSpacing.screenHorizontal)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation(.easeOut) { self.message = nil }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: message)
    }
}

extension View {
    func vpToast(_ message: Binding<String?>, systemImage: String = "checkmark.circle.fill") -> some View {
        modifier(VPToastModifier(message: message, systemImage: systemImage))
    }
}
