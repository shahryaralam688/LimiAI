import SwiftUI

// MARK: - Design Tokens
struct AIDesignTokens {
    // Colors
    static let bgBase = Color.themeBlack
    static let bgSurface = Color.appCanvasMuted
    static let bgCard = Color.appSurfaceTertiary
    static let textPrimary = Color.themeWhite
    static let textSecondary = Color.appBorderField
    static let textMuted = Color.appTextSubtle
    static let brandEmerald = Color.appBrandPrimary
    static let brandEmeraldPressed = Color.appBrandPrimary
    static let brandEmerald20 = Color.appBrandPrimary.opacity(0.20)
    static let accentWarn = Color.appDanger
    static let strokeSoft = Color.themeWhite.opacity(0.08)
    static let chipBg = Color.themeWhite.opacity(0.06)
    static let badgeBg = Color.themeWhite.opacity(0.10)
    static let toggleOff = Color.themeWhite.opacity(0.24)
    
    // Spacing
    static let spacingXXS: CGFloat = 4
    static let spacingXS: CGFloat = 6
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacing3XL: CGFloat = 32
    
    // Radii
    static let radiusXSS: CGFloat = 4
    static let radiusXS: CGFloat = 8
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 20
    static let radiusXL: CGFloat = 24
    static let radiusPill: CGFloat = 999
    
    // Typography
    static let h1Font = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let h2Font = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleFont = Font.system(size: 18, weight: .semibold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 13, weight: .medium)
}

// MARK: - Atoms

struct AIButton: View {
    let title: String
    let style: ButtonStyle
//    let height: CGFloat?
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case outline
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AIDesignTokens.titleFont)
                .foregroundColor(Color.themeBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style == .primary ? Color.themeWhite : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: AIDesignTokens.radiusXSS)
                                .stroke(style == .outline ? Color.themeWhite : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AITag: View {
    let label: String
    
    var body: some View {
        Text(label)
            .font(AIDesignTokens.captionFont)
            .foregroundColor(AIDesignTokens.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AIDesignTokens.radiusXSS)
                    .fill(AIDesignTokens.bgBase)
            )
    }
}

struct TokenPill: View {
    let tokenCount: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16))
                .foregroundColor(AIDesignTokens.brandEmerald)
            Text(tokenCount)
                .font(AIDesignTokens.captionFont)
                .foregroundColor(AIDesignTokens.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
//        .background(
//            RoundedRectangle(cornerRadius: AIDesignTokens.radiusPill)
//                .fill(AIDesignTokens.chipBg)
//        )
    }
}

// Custom toggle style with separate thumb color
struct AICustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Track
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color.themeWhite :  Color.appTextDisabled  )
                    .frame(width: 52, height: 30)

                // Thumb / ball
                Circle()
                    .fill(configuration.isOn ? Color.emerald : Color.appBorderTertiary)
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.themeBlack.opacity(0.3), radius: 2, x: 0, y: 1)
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
        HStack {
            Button(action: onBack) {
                Image("Solid arrow right sm")
                    .foregroundColor(.alabaster)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Color.appInputFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text(title)
                .font(AIDesignTokens.h1Font)
                .foregroundColor(AIDesignTokens.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, AIDesignTokens.spacingLG)
        .frame(height: 92)
        .background(Color.clear)
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
    
    

    
    var body: some View {
        VStack(spacing: AIDesignTokens.spacingLG) {
            // Tags row

            // Main content row
            HStack(spacing: AIDesignTokens.spacingLG) {
                // Icon
                VStack() {
                Image( iconName)
//                    .font(.system(size: 36))
                    .foregroundColor(AIDesignTokens.textPrimary)
//                    .frame(width: 72, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: AIDesignTokens.radiusLG)
                            .fill(AIDesignTokens.bgSurface)
                    )
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: AIDesignTokens.spacingSM) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            AITag(label: tag)
                        }
                        Spacer()
                    }
                    
                    Text(title)
                        .font(AIDesignTokens.h2Font)
                        .foregroundColor(AIDesignTokens.textPrimary)
                    
                    HStack(spacing: 10) {
                        Text(connectionStatus)
                            .font(AIDesignTokens.bodyFont)
                            .foregroundColor(AIDesignTokens.textSecondary)
                        
                        TokenPill(tokenCount: tokenCount)
                    }
                    // ✅ Connect / Connected button
                    Button {
                        onAction()  // triggers parent toggle
                        print("Connect button tapped")
                    } label: {
                        Text(isConnected ? "Connect" : "Disconnect")
                            .font(.headline)
                            .foregroundColor(isConnected ? .themeBlack : .themeWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                // ✅ Fill emerald when connected, transparent when not
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isConnected ? Color.themeWhite : Color.clear)
                            )
                            .overlay(
                                // ✅ Always keep emerald border
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.themeWhite, lineWidth: 1)
                            )
                    }
                    .animation(.easeInOut(duration: 0.2), value: isConnected)



                }
                
                Spacer()
            }

        }
        .padding(AIDesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: AIDesignTokens.radiusLG)
                .fill(AIDesignTokens.bgCard)
                .shadow(color: Color.themeBlack.opacity(0.5), radius: 12, x: 0, y: 6)
        )
    }
}

struct ConnectionRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: AIDesignTokens.spacingLG) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(AIDesignTokens.textPrimary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AIDesignTokens.h2Font)
                    .foregroundColor(AIDesignTokens.textPrimary)
                
                Text(subtitle)
                    .font(AIDesignTokens.bodyFont)
                    .foregroundColor(AIDesignTokens.textSecondary)
            }
            
            Spacer()
            
            AIToggle(isOn: $isEnabled)
        }
        .padding(AIDesignTokens.spacingLG)
        .background(
            RoundedRectangle(cornerRadius: AIDesignTokens.radiusLG)
                .fill(AIDesignTokens.bgCard)
        )
    }
}

struct InfoBanner: View {
    let title: String
    let description: String
    let ctaText: String
    let onCTA: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AIDesignTokens.spacingMD) {
            Text(title)
                .font(AIDesignTokens.h2Font)
                .foregroundColor(.themeBlack)
            
            Text(description)
                .font(AIDesignTokens.bodyFont)
                .foregroundColor(.themeBlack)
            
            Button(action: onCTA) {
                Text(ctaText)
                    .font(AIDesignTokens.titleFont)
                    .foregroundColor(.themeBlack)
                    .underline()
            }
        }
        .padding(AIDesignTokens.spacingXXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.themeWhite)
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
                    .font(AIDesignTokens.h2Font)
                    .foregroundColor(AIDesignTokens.textPrimary)
                
                Text(subtitle)
                    .font(AIDesignTokens.bodyFont)
                    .foregroundColor(AIDesignTokens.textSecondary)
            }
            
            Spacer()
            
            AIToggle(isOn: $isEnabled)
        }
        .padding(AIDesignTokens.spacingXL)
        .background(
            RoundedRectangle(cornerRadius: AIDesignTokens.radiusLG)
                .fill(AIDesignTokens.bgCard)
        )
    }
}
