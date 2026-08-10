//
//  DemoAddingWifiView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 26/10/2025.
//

import SwiftUI

struct DemoAddingWifiView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    let deviceName: String
    let deviceId: String
    let wifiSSID: String

    private enum Step: Equatable {
        case enterPassword
        case provisioning(phase: String)
        case success
        case failure(message: String)
    }

    @State private var wifiPassword: String = ""
    @State private var isPasswordVisible = false
    @State private var step: Step = .enterPassword
    @State private var showConnectedDevicesAfterSuccess = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enterPassword:
                    passwordEntryContent
                case .provisioning(let phase):
                    provisioningContent(phase: phase)
                case .success:
                    DemoConnectedWifiView(
                        deviceName: deviceName,
                        onContinue: { showConnectedDevicesAfterSuccess = true }
                    )
                case .failure(let message):
                    failureContent(message: message)
                }
            }
            .background(Color.appCanvasPrimary)
            .limiModalNavigationBar(title: "Add Device", onClose: {
                WiFiProvisioningCoordinator.shared.cancel()
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            })
        }
        .fullScreenCover(isPresented: $showConnectedDevicesAfterSuccess) {
            ConnectedDevicesView()
        }
        .onDisappear {
            if case .success = step { return }
            WiFiProvisioningCoordinator.shared.cancel()
        }
    }

    private var passwordEntryContent: some View {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Enter the password for your Wi-Fi network")

            VStack(spacing: 16) {
                HStack {
                    Text("Wifi Password")
                        .font(LimiTypography.title3)
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(0)
                        .kerning(0)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                HStack {
                    Text(wifiSSID)
                        .font(LimiTypography.title2)
                        .foregroundColor(.appTextPrimary)
                        .kerning(-0.048)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 34)

                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("", text: $wifiPassword)
                        } else {
                            SecureField("", text: $wifiPassword)
                        }
                    }
                    .font(LimiTypography.headline)
                    .foregroundColor(Color.appTextSoft)
                    .kerning(-0.048)
                    .lineSpacing(0)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.leading, 16)

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.appTextPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }
                .background(
                    Rectangle()
                        .fill(Color.appSurfacePrimary)
                        .cornerRadius(20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                )
                .padding(.horizontal, 16)

                VStack {
                    Text("Connect Your Device to Wi-Fi")
                        .font(LimiTypography.title3)
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(20 * 0.4)
                        .kerning(0)

                    Text("Enter your Wi-Fi password to link your device securely. This allows Limi to stay connected, sync with your other devices, and respond instantly — all within your private network.")
                        .font(LimiTypography.subheadline)
                        .foregroundColor(Color.appTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal)
                }
                .background(
                    Rectangle()
                        .fill(Color.appSurfacePrimary)
                        .cornerRadius(20)
                        .frame(height: 148)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                .padding(.horizontal, 16)
                .padding(.top, 27)
            }

            Spacer()

            LimiPrimaryButton(title: "Connect Device") {
                startProvisioning()
            }
            .disabled(wifiPassword.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .limiFloatingOrbClearance()
        }
    }

    private func provisioningContent(phase: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                .scaleEffect(1.5)
            Text("Connecting to Wi-Fi")
                .font(LimiTypography.title3)
                .foregroundColor(.appTextPrimary)
            Text(phase)
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .limiFloatingOrbClearance()
    }

    private func failureContent(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: LimiIconSize.hero))
                .foregroundColor(.appTextMuted)
            Text("Couldn't Connect")
                .font(LimiTypography.title2)
                .foregroundColor(.appTextPrimary)
            Text(message)
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            LimiPrimaryButton(title: "Try Again") {
                step = .enterPassword
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .limiFloatingOrbClearance()
        }
    }

    private func startProvisioning() {
        guard !wifiSSID.isEmpty else { return }
        step = .provisioning(phase: "Sending Wi-Fi credentials…")

        WiFiProvisioningCoordinator.shared.provisionAndVerify(
            deviceName: deviceName,
            bleDeviceId: deviceId,
            ssid: wifiSSID,
            password: wifiPassword,
            onPhaseUpdate: { phase in
                step = .provisioning(phase: phase)
            },
            completion: { result in
                switch result {
                case .success(let outcome):
                    SelectedDevicesStorage.shared.addOrUpdate(name: deviceName, uuid: deviceId)
                    ConfiguredBLEDeviceStore.shared.remember(
                        hardwareId: outcome.deviceId,
                        blePeripheralUUID: deviceId,
                        displayName: outcome.deviceName.isEmpty ? deviceName : outcome.deviceName
                    )
                    step = .success
                case .failure(let failure):
                    step = .failure(message: failure.userMessage)
                }
            }
        )
    }
}

#Preview {
    DemoAddingWifiView(deviceName: "abc", deviceId: "xyz", wifiSSID: "abc")
}
