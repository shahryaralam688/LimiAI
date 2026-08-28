//
//  DeviceNeumorphicChrome.swift
//  LIMI AI Device — shared Soft UI chrome for splash, sign-in, sheets, lists.
//

import SwiftUI

/// Full-screen neumorphic canvas used by splash, sign-in, and sheet roots.
struct DeviceNeumorphicScreen<Content: View>: View {
    var showsCanvas: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if showsCanvas {
                HomeUI1AnimatedCanvas()
            } else {
                HomeUI1Color.canvas.ignoresSafeArea()
            }
            content()
        }
        .preferredColorScheme(.dark)
    }
}

/// Raised neumorphic button with optional SF Symbol (primary / secondary / accent).
struct DeviceNeumorphicButton: View {
    enum Kind {
        case primary
        case secondary
        case accent
        case destructive
        case ghost
    }

    let title: String
    var systemImage: String? = nil
    var kind: Kind = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            DeviceAppGuidance.lightImpact()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(HomeUI1Type.body(16))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .homeUI1Elevation(
                elevation,
                cornerRadius: HomeUI1Radius.md,
                fill: fill
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(HomeUI1Motion.soft, value: isLoading)
    }

    private var elevation: HomeUI1ElevationLevel {
        switch kind {
        case .ghost: return .flat
        case .primary, .accent: return .two
        case .secondary, .destructive: return .one
        }
    }

    private var fill: Color {
        switch kind {
        case .accent: return HomeUI1Color.accentGreen.opacity(0.22)
        case .destructive: return HomeUI1Color.accentRed.opacity(0.16)
        case .ghost: return .clear
        default: return HomeUI1Color.surface
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return HomeUI1Color.textPrimary
        case .secondary: return HomeUI1Color.textSecondary
        case .accent: return HomeUI1Color.accentGreen
        case .destructive: return HomeUI1Color.accentRed
        case .ghost: return HomeUI1Color.accentGreen
        }
    }
}

/// Inset neumorphic text field for email / OTP / password forms.
struct DeviceNeumorphicTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(HomeUI1Type.regular(16))
            .foregroundStyle(HomeUI1Color.textPrimary)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
    }
}

/// Soft UI empty / status card used on scan, connected, virtual screens.
struct DeviceNeumorphicStatusCard: View {
    let title: String
    let message: String
    var systemImage: String = "info.circle"
    var showsProgress: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .frame(width: 64, height: 64)
                .homeUI1CircleElevation(.one, fill: HomeUI1Color.surface)

            Text(title)
                .font(HomeUI1Type.title(20))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(HomeUI1Type.regular(14))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .multilineTextAlignment(.center)

            if showsProgress {
                ProgressView()
                    .tint(HomeUI1Color.accentGreen)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }
}

/// Soft UI list row used across connected / scan / virtual screens.
struct DeviceNeumorphicListRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String = "lightbulb.led.fill"
    var isAccent: Bool = false
    var showsChevron: Bool = true
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isAccent ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                .frame(width: 42, height: 42)
                .homeUI1CircleElevation(.one, fill: HomeUI1Color.surfaceRaised)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                trailing
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
            }
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }
}

extension View {
    /// Apply Soft UI navigation bar styling for sheets and push screens.
    func deviceNeumorphicNavigationChrome() -> some View {
        self
            .toolbarBackground(HomeUI1Color.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}

/// Soft UI status banner for Sign In / OTP feedback.
struct DeviceNeumorphicStatusBanner: View {
    let message: String
    var kind: DeviceSignInMessageKind = .error
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(HomeUI1Type.regular(13))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let retryTitle, let onRetry {
                    Button(retryTitle) {
                        DeviceAppGuidance.lightImpact()
                        onRetry()
                    }
                    .font(HomeUI1Type.body(13))
                    .foregroundStyle(HomeUI1Color.accentGreen)
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 4)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .homeUI1CircleElevation(.one, fill: HomeUI1Color.surfaceRaised)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(14)
        .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: HomeUI1Radius.md, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var accent: Color {
        switch kind {
        case .info: return HomeUI1Color.textSecondary
        case .success: return HomeUI1Color.accentGreen
        case .error: return HomeUI1Color.accentRed
        }
    }

    private var iconName: String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

/// Soft UI blocking loader with calm status copy.
struct DeviceNeumorphicLoadingOverlay: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 14) {
                ProgressView()
                    .tint(HomeUI1Color.accentGreen)
                    .scaleEffect(1.1)

                Text(title)
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: 280)
            .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
        }
        .transition(.opacity)
    }
}
