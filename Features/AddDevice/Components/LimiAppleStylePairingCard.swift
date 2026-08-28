//
//  LimiAppleStylePairingCard.swift
//  Limi
//
//  AirPods-style pairing card — bottom sheet, 3D product hero, Connect / status states.
//

import SwiftUI

enum LimiPairingCardMode: Equatable {
    case discover
    case connecting
    case provisioning(String)
    case connected(String?)
}

enum LimiPairingCardPlacement {
    case bottomSheet
    case centered
}

struct LimiAppleStylePairingCard: View {
    let deviceName: String
    var deviceId: String?
    var mode: LimiPairingCardMode
    var modelName: String = LimiPairingAssets.defaultModelName
    var placement: LimiPairingCardPlacement = .bottomSheet
    var onPrimary: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var appeared = false

    private var titleText: String {
        switch mode {
        case .discover:
            return "Connect to \(displayName)"
        case .connecting, .provisioning:
            return displayName
        case .connected:
            return displayName
        }
    }

    private var subtitleText: String? {
        switch mode {
        case .discover:
            return "Hold your phone near the device"
        case .connecting:
            return "Connecting…"
        case .provisioning(let phase):
            return phase
        case .connected(let detail):
            return detail ?? "Connected · Ready to control"
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .discover: return "Connect"
        case .connecting: return "Connecting…"
        case .provisioning: return "Setting up…"
        case .connected: return "Done"
        }
    }

    private var showsPrimaryButton: Bool {
        switch mode {
        case .discover, .connected: return true
        case .connecting, .provisioning: return false
        }
    }

    private var showsNotNow: Bool {
        mode == .discover
    }

    private var isPrimaryEnabled: Bool {
        switch mode {
        case .discover, .connected: return true
        case .connecting, .provisioning: return false
        }
    }

    private var displayName: String {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "LIMI Device" : trimmed
    }

    private var animatesModel: Bool {
        switch mode {
        case .connecting, .provisioning: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            switch placement {
            case .bottomSheet:
                bottomSheetBody
            case .centered:
                centeredBody
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    private var bottomSheetBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            cardContent
                .offset(y: appeared ? 0 : 320)
        }
    }

    private var centeredBody: some View {
        cardContent
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            headerRow

            LimiPairingModelView(
                bundledName: modelName,
                isAnimating: animatesModel,
                visualScale: 2.6
            )
                .frame(height: 200)
                .padding(.top, 4)

            if let subtitleText {
                Text(subtitleText)
                    .font(LimiTypography.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }

            if case .connected = mode {
                connectedStatusRow
                    .padding(.top, 12)
            }

            if showsPrimaryButton {
                appleConnectButton
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            if mode == .connecting || mode.isProvisioning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                    .padding(.top, 16)
            }

            if showsNotNow {
                Button("Not Now") {
                    onDismiss?()
                }
                .font(LimiTypography.subheadline)
                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                .padding(.top, 12)
                .padding(.bottom, 8)
            } else if showsPrimaryButton {
                Spacer().frame(height: 20)
            } else {
                Spacer().frame(height: 24)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, placement == .bottomSheet ? 28 : 20)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.appGlassStrokeLight.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, placement == .bottomSheet ? 10 : 28)
        .padding(.bottom, placement == .bottomSheet ? 8 : 0)
    }

    private var headerRow: some View {
        ZStack {
            Text(titleText)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            HStack {
                Spacer()
                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.appGlassFillMedium, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var connectedStatusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
            Text("Connected")
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.appGlassFillMedium, in: Capsule())
    }

    private var appleConnectButton: some View {
        Button {
            guard isPrimaryEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPrimary?()
        } label: {
            Text(primaryButtonTitle)
                .font(LimiTypography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule(style: .continuous)
                        .fill(isPrimaryEnabled ? Color(red: 0, green: 0.48, blue: 1) : Color.appGlassFillMedium)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isPrimaryEnabled)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.appSurfaceCard.opacity(0.98))
    }
}

struct LimiPairingOverlay: View {
    let deviceName: String
    var deviceId: String?
    var mode: LimiPairingCardMode
    var modelName: String = LimiPairingAssets.defaultModelName
    var placement: LimiPairingCardPlacement = .bottomSheet
    var onPrimary: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.appOverlayScrim
                .ignoresSafeArea()
                .onTapGesture {
                    if mode == .discover {
                        onDismiss?()
                    }
                }

            LimiAppleStylePairingCard(
                deviceName: deviceName,
                deviceId: deviceId,
                mode: mode,
                modelName: modelName,
                placement: placement,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        }
    }
}

private extension LimiPairingCardMode {
    var isProvisioning: Bool {
        if case .provisioning = self { return true }
        return false
    }
}
