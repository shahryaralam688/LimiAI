import SwiftUI

// MARK: - Design Tokens
struct AIDesignTokens {
    static let bgBase = Color.appCanvasPrimary
    static let bgSurface = Color.appCanvasMuted
    static let bgCard = Color.appSurfaceCard
    static let textPrimary = Color.appTextPrimary
    static let textSecondary = Color.appTextSecondary
    static let textMuted = Color.appTextMuted
    static let brandEmerald = Color.appBrandPrimary
    static let brandEmeraldPressed = Color.appBrandPrimary
    static let brandEmerald20 = Color.appBrandPrimary.opacity(0.20)
    static let accentWarn = Color.appDanger
    static let strokeSoft = Color.white.opacity(0.06)
    static let chipBg = Color.white.opacity(0.04)
    static let badgeBg = Color.white.opacity(0.06)
    static let toggleOff = Color.white.opacity(0.16)

    static let spacingXXS: CGFloat = 4
    static let spacingXS: CGFloat = 6
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacing3XL: CGFloat = 32

    static let radiusXSS: CGFloat = 4
    static let radiusXS: CGFloat = 8
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 20
    static let radiusXL: CGFloat = 24
    static let radiusPill: CGFloat = 999

    static let h1Font = Font.system(size: 28, weight: .bold, design: .rounded)
    static let h2Font = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleFont = Font.system(size: 18, weight: .semibold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 13, weight: .medium)
}

// MARK: - Atoms

struct AIButton: View {
    let title: String
    let style: ButtonVariant
    let action: () -> Void

    enum ButtonVariant {
        case primary
        case outline
    }

    var body: some View {
        if style == .primary {
            LimiPrimaryButton(title: title, action: action)
        } else {
            LimiSecondaryButton(title: title, action: action)
        }
    }
}

struct AITag: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.orbGlow4)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.orbGlow4.opacity(0.12))
            )
    }
}

struct TokenPill: View {
    let tokenCount: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(.orbGlow3)
            Text(tokenCount)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appTextSecondary)
        }
    }
}

struct AICustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        configuration.isOn
                        ? LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 52, height: 30)

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .padding(2)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

struct AIToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(AICustomToggleStyle())
    }
}

// MARK: - Molecules

struct AIAppBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            LimiBackButton(action: onBack)

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Spacer()
        }
        .padding(.horizontal, AIDesignTokens.spacingLG)
        .frame(height: 72)
    }
}

struct ModelCard: View {
    let iconName: String
    let title: String
    let tags: [String]
    let connectionStatus: String
    let tokenCount: String
    let isConnected: Bool
    let onAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.orbGlow1.opacity(0.1))
                        .frame(width: 52, height: 52)

                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.orbGlow4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            AITag(label: tag)
                        }
                    }
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.appSuccess : Color.appTextMuted)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
            }

            HStack {
                TokenPill(tokenCount: tokenCount)
                Spacer()

                Button(action: onAction) {
                    Text(isConnected ? "Connected" : "Connect")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isConnected ? .appCanvasPrimary : .appTextPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    isConnected
                                    ? LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isConnected ? 0 : 0.12), lineWidth: 1)
                        )
                }
                .animation(.easeInOut(duration: 0.2), value: isConnected)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, strokeOpacity: 0.06, fillOpacity: 0.06)
        .tapScale()
    }
}

struct ConnectionRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orbGlow2.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(.orbGlow3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()
            AIToggle(isOn: $isEnabled)
        }
        .padding(14)
        .glassCard(cornerRadius: 16, fillOpacity: 0.05)
    }
}

struct InfoBanner: View {
    let title: String
    let description: String
    let ctaText: String
    let onCTA: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Text(description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.appTextSecondary)
                .lineSpacing(4)
            Button(action: onCTA) {
                HStack(spacing: 4) {
                    Text(ctaText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orbGlow1.opacity(0.08), Color.orbGlow2.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orbGlow1.opacity(0.12), lineWidth: 0.5)
        )
    }
}

struct IntegrationOption: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            AIToggle(isOn: $isEnabled)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, fillOpacity: 0.05)
    }
}
