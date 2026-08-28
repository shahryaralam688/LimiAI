//
//  LimiAppleDeviceSetupView.swift
//  Limi
//
//  Apple-style post-BLE setup — interactive 3D hero + Wi-Fi / password steps.
//

import SwiftUI

struct LimiAppleDeviceSetupView: View {
    enum Mode {
        case wifiList
        case password(String)
    }

    let deviceName: String
    var deviceId: String?
    let mode: Mode
    let networks: [String]
    @Binding var password: String
    let onSelectSSID: (String) -> Void
    let onConnect: () -> Void
    let onBack: () -> Void
    var modelName: String = LimiPairingAssets.defaultModelName

    @State private var heroAppeared = false
    @State private var isPasswordVisible = false
    @FocusState private var passwordFocused: Bool

    private var displayName: String {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "LIMI Device" : trimmed
    }

    private var subtitle: String {
        switch mode {
        case .wifiList:
            return "Choose a Wi-Fi network"
        case .password(let ssid):
            return "Join “\(ssid)”"
        }
    }

    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection
                setupCard
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                heroAppeared = true
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.brandHighlight.opacity(0.22),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 180
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(heroAppeared ? 1 : 0.85)
                    .opacity(heroAppeared ? 1 : 0)

                LimiPairingModelView(
                    bundledName: modelName,
                    isAnimating: true,
                    allowsInteraction: true,
                    visualScale: 3.4
                )
                .frame(height: 300)
                .scaleEffect(heroAppeared ? 1 : 0.9)
                .opacity(heroAppeared ? 1 : 0)
            }
            .padding(.top, 4)

            Text(displayName)
                .font(LimiTypography.title2)
                .foregroundColor(.appTextPrimary)

            Text(subtitle)
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextSecondary)

            Text("Drag to rotate")
                .font(LimiTypography.caption)
                .foregroundColor(.appTextMuted)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var setupCard: some View {
        VStack(spacing: 0) {
            switch mode {
            case .wifiList:
                wifiListContent
            case .password(let ssid):
                passwordContent(ssid: ssid)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appSurfaceCard.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.appGlassStrokeLight.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .offset(y: heroAppeared ? 0 : 40)
        .opacity(heroAppeared ? 1 : 0)
    }

    private var wifiListContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Networks nearby")
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)

            if networks.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading Wi-Fi networks from device…")
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextMuted)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(networks, id: \.self) { ssid in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelectSSID(ssid)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "wifi")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.brandHighlight)
                                        .frame(width: 28)

                                    Text(ssid)
                                        .font(LimiTypography.button)
                                        .foregroundColor(.appTextPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.appTextMuted)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.appSurfacePrimary)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func passwordContent(ssid: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Networks")
                    }
                    .font(LimiTypography.subheadline)
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            Text(ssid)
                .font(LimiTypography.title3)
                .foregroundColor(.appTextPrimary)

            HStack {
                Group {
                    if isPasswordVisible {
                        TextField("Wi-Fi password", text: $password)
                    } else {
                        SecureField("Wi-Fi password", text: $password)
                    }
                }
                .font(LimiTypography.body)
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($passwordFocused)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.appTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appSurfacePrimary)
            )

            Button {
                guard !password.isEmpty else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onConnect()
            } label: {
                Text("Connect")
                    .font(LimiTypography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                password.isEmpty
                                    ? Color.appGlassFillMedium
                                    : Color(red: 0, green: 0.48, blue: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(password.isEmpty)
        }
        .onAppear {
            isPasswordVisible = false
            passwordFocused = true
        }
    }
}
