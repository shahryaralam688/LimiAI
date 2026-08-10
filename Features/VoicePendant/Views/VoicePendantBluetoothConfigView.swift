//
//  VoicePendantBluetoothConfigView.swift
//  Limi
//
//  Separate Bluetooth setup flow for Voice Pendants — mirrors the Limi device
//  configuration: scan BLE devices → tap one → connect → pick Wi-Fi + password
//  → provision over BLE → success. Presented from the pendant listing screen.
//

import SwiftUI

struct VoicePendantBluetoothConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoicePendantBluetoothViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()
                content
            }
            .limiModalNavigationBar(title: navTitle, onClose: {
                viewModel.finish()
                dismiss()
            })
        }
        .onAppear { viewModel.startScan() }
        .onDisappear { viewModel.finish() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .trackScreen("VoicePendantBluetoothConfigView", metadata: ["surface": "pendant_bt_setup"])
    }

    private var navTitle: String {
        switch viewModel.step {
        case .scanning, .connecting: return "Add Pendant"
        case .wifiList, .password, .provisioning: return "Wi-Fi Setup"
        case .success: return "All Set"
        }
    }

    // MARK: - Step Router

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .scanning:
            scanStep
        case .connecting:
            connectingStep
        case .wifiList:
            wifiListStep
        case .password(let ssid):
            passwordStep(ssid: ssid)
        case .provisioning(let ssid):
            provisioningStep(ssid: ssid)
        case .success(let ssid):
            successStep(ssid: ssid)
        }
    }

    // MARK: - Step 1: Scan

    private var scanStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "dot.radiowaves.left.and.right",
                title: "Looking for pendants",
                subtitle: "Make sure your pendant is powered on and nearby."
            )

            if !viewModel.isBluetoothOn {
                infoBanner(icon: "exclamationmark.triangle.fill",
                           text: "Bluetooth is off. Turn it on to discover pendants.")
            }

            if viewModel.devices.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                        .scaleEffect(1.2)
                    Text("Scanning…")
                        .font(LimiTypography.callout)
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.devices, id: \.id) { device in
                            deviceRow(device)
                        }
                    }
                    .padding(16)
                    .limiFloatingOrbClearance()
                }
            }
        }
    }

    private func deviceRow(_ device: (name: String, id: String)) -> some View {
        Button {
            viewModel.select(device)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(LimiTypography.title2)
                    .foregroundColor(.brandAction)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name.isEmpty ? "Unknown device" : device.name)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextPrimary)
                    Text(device.id)
                        .font(LimiTypography.caption2)
                        .foregroundColor(Color.appTextMuted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(LimiTypography.footnote)
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(14)
            .limiPanel(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Connecting

    private var connectingStep: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                .scaleEffect(1.4)
            Text("Connecting to \(viewModel.selectedDevice?.name ?? "pendant")…")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
            Text("Pairing over Bluetooth")
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Step 3: Wi-Fi list

    private var wifiListStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "wifi",
                title: "Choose a network",
                subtitle: "Pick the Wi-Fi your pendant should join."
            )

            if viewModel.isLoadingWifi {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    Text("Reading networks from pendant…")
                        .font(LimiTypography.callout)
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.wifiNetworks.enumerated()), id: \.offset) { _, ssid in
                            wifiRow(ssid)
                        }
                        if viewModel.wifiNetworks.isEmpty {
                            Text("No networks found. Move closer to your router and refresh.")
                                .font(LimiTypography.subheadline)
                                .foregroundColor(Color.appTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.top, 40)
                        }
                        Button {
                            viewModel.loadWifiList()
                        } label: {
                            Label("Refresh networks", systemImage: "arrow.clockwise")
                                .font(LimiTypography.callout)
                                .foregroundColor(Color.appBorderSoft)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .limiFloatingOrbClearance()
                }
            }
        }
    }

    private func wifiRow(_ ssid: String) -> some View {
        Button {
            viewModel.selectNetwork(ssid)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wifi")
                    .font(LimiTypography.button)
                    .foregroundColor(.appTextPrimary)
                Text(ssid)
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(LimiTypography.caption)
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(14)
            .limiPanel(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Password

    private func passwordStep(ssid: String) -> some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "lock.shield.fill",
                title: ssid,
                subtitle: "Enter the Wi-Fi password to connect your pendant."
            )

            VStack(spacing: 16) {
                SecureField("Wi-Fi password", text: $viewModel.passwordInput)
                    .textFieldStyle(.plain)
                    .foregroundColor(.appTextPrimary)
                    .padding(14)
                    .limiPanel(cornerRadius: 14)

                LimiPrimaryButton(title: "Connect Pendant") {
                    viewModel.provision()
                }

                Button {
                    viewModel.backToWifiList()
                } label: {
                    Text("Choose a different network")
                        .font(LimiTypography.callout)
                        .foregroundColor(Color.appTextSecondary)
                }
            }
            .padding(16)

            Spacer()
        }
    }

    // MARK: - Step 5: Provisioning

    private func provisioningStep(ssid: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                .scaleEffect(1.4)
            Text("Sending Wi-Fi to pendant…")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
            Text("Joining “\(ssid)”. This can take up to 45 seconds.")
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Step 6: Success

    private func successStep(ssid: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.brandAction.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(LimiTypography.title2)
                    .foregroundColor(.emerald)
            }
            VStack(spacing: 8) {
                Text("Pendant configured")
                    .font(LimiTypography.title3)
                    .foregroundColor(.appTextPrimary)
                Text("\(viewModel.connectedDeviceName ?? viewModel.selectedDevice?.name ?? "Your pendant") is now joining “\(ssid)”. It will appear in your pendant list once it's online.")
                    .font(LimiTypography.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            LimiPrimaryButton(title: "Done") {
                viewModel.finish()
                dismiss()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .limiFloatingOrbClearance()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared bits

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(LimiTypography.title2)
                .foregroundColor(.brandAction)
                .frame(width: 64, height: 64)
                .background(Color.brandHighlight.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(LimiTypography.button)
                .foregroundColor(.appTextPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private func infoBanner(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.appWarning)
            Text(text)
                .font(LimiTypography.footnote)
                .foregroundColor(.appTextPrimary)
            Spacer()
        }
        .padding(12)
        .limiPanel(cornerRadius: 12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    VoicePendantBluetoothConfigView()
}
