//
//  VoicePendantUI.swift
//  Limi
//
//  Shared, module-local UI building blocks for the Voice Pendant screens.
//  Keeps the individual screens DRY and visually consistent with the app's
//  design tokens.
//

import SwiftUI

// MARK: - Section Card

/// A titled card container used across the pendant screens.
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.themeWhite)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurfaceSecondaryAlt)
        .cornerRadius(16)
    }
}

// MARK: - Navigation Row

/// A tappable row that pushes a destination (used in the detail hub).
struct VPNavRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = .appBorderSoft

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.themeWhite)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.appTextTertiary)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appTextMuted)
        }
        .padding(14)
        .background(Color.appSurfaceSecondaryAlt)
        .cornerRadius(16)
        .contentShape(Rectangle())
    }
}

// MARK: - Status Pill

struct VPStatusPill: View {
    let status: VoicePendantStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .online: return .emerald
        case .pairing: return .orange
        case .offline: return .gray
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.themeWhite)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.themeWhite)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color.appTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appSurfacePrimary)
        .cornerRadius(14)
    }
}

// MARK: - Transient Toast Modifier

private struct VPToastModifier: ViewModifier {
    @Binding var message: String?
    var systemImage: String = "checkmark.circle.fill"

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.emerald)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.themeWhite)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appSurfaceSecondaryAlt)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.themeWhite.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 16)
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
    /// Shows a transient toast bound to an optional message string.
    func vpToast(_ message: Binding<String?>, systemImage: String = "checkmark.circle.fill") -> some View {
        modifier(VPToastModifier(message: message, systemImage: systemImage))
    }
}
