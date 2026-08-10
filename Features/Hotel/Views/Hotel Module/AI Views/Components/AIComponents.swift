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
    static let brandEton = Color.appBrandSecondary
    static let brandEton12 = Color.appBrandSecondary.opacity(0.12)
    static let accentWarn = Color.appDanger
    static let strokeSoft = Color.appGlassFillMedium
    static let chipBg = Color.appGlassFill
    static let badgeBg = Color.appGlassFillMedium
    static let toggleOff = Color.appToggleOff

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

    static let h1Font = LimiTypography.title
    static let h2Font = LimiTypography.title2
    static let titleFont = LimiTypography.title3
    static let bodyFont = LimiTypography.body
    static let captionFont = LimiTypography.caption
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
            .font(LimiTypography.caption)
            .foregroundColor(AIDesignTokens.brandEton)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(AIDesignTokens.brandEton12)
            )
    }
}

struct TokenPill: View {
    let tokenCount: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(LimiTypography.caption)
                .foregroundColor(.brandHighlight)
            Text(tokenCount)
                .font(LimiTypography.caption)
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
                        ? LimiGradients.cta
                        : LinearGradient(colors: [Color.appGlassFillStrong, Color.appGlassFillStrong], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 52, height: 30)

                Circle()
                    .fill(Color.themeWhite)
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.appCanvasPrimary.opacity(0.2), radius: 2, x: 0, y: 1)
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
    var closeTitle: String = "Close"
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(closeTitle, action: onBack)
                .font(LimiTypography.headline)
                .foregroundColor(.brandHighlight)
                .accessibilityLabel("Close")

            Text(title)
                .font(LimiTypography.title)
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
                        .fill(AIDesignTokens.brandEton12)
                        .frame(width: 52, height: 52)

                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AIDesignTokens.brandEton)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            AITag(label: tag)
                        }
                    }
                    Text(title)
                        .font(LimiTypography.button)
                        .foregroundColor(.appTextPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.appSuccess : Color.appTextMuted)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus)
                        .font(LimiTypography.caption)
                        .foregroundColor(.appTextSecondary)
                }
            }

            HStack {
                TokenPill(tokenCount: tokenCount)
                Spacer()

                Button(action: onAction) {
                    Text(isConnected ? "Connected" : "Connect")
                        .font(LimiTypography.callout)
                        .foregroundColor(isConnected ? .appCanvasPrimary : .appTextPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    isConnected
                                    ? LimiGradients.cta
                                    : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.appGlassStrokeStrong.opacity(isConnected ? 0 : 1), lineWidth: 1)
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
                    .fill(Color.brandHighlight.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(LimiTypography.body)
                    .foregroundColor(.brandHighlight)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                Text(subtitle)
                    .font(LimiTypography.footnote)
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
                .font(LimiTypography.button)
                .foregroundColor(.appTextPrimary)
            Text(description)
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextSecondary)
                .lineSpacing(4)
            Button(action: onCTA) {
                HStack(spacing: 4) {
                    Text(ctaText)
                        .font(LimiTypography.callout)
                        .foregroundColor(.brandHighlight)
                    Image(systemName: "arrow.right")
                        .font(LimiTypography.caption)
                        .foregroundColor(.brandHighlight)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.brandHighlight.opacity(0.08), Color.brandAction.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.brandHighlight.opacity(0.12), lineWidth: 0.5)
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
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                Text(subtitle)
                    .font(LimiTypography.footnote)
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            AIToggle(isOn: $isEnabled)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, fillOpacity: 0.05)
    }
}
