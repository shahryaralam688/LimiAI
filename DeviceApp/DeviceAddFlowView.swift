//
//  DeviceAddFlowView.swift
//  LIMI AI Device
//
//  Native add-device flow. Reuses AddDeviceFlowViewModel — the exact
//  same scan → Wi-Fi list → password → provisioning pipeline as the
//  main app, rendered with standard iOS components.
//

import SwiftUI
import UIKit

struct DeviceAddFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AddDeviceFlowViewModel()

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { closeEntireFlow() }
                    }
                }
        }
        .interactiveDismissDisabled(isProvisioning)
        .onAppear { viewModel.onAppear() }
        .onDisappear {
            if scenePhase == .active {
                viewModel.finish()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                viewModel.pauseForBackground()
            case .active:
                viewModel.resumeFromBackground()
            @unknown default:
                break
            }
        }
        .onChange(of: viewModel.scanViewModel.lastDisconnectedBLEDeviceID) { _, id in
            viewModel.scanViewModel.handleDisconnectedDeviceID(id)
        }
    }

    private var isProvisioning: Bool {
        if case .provisioning = viewModel.step { return true }
        return false
    }

    private var navigationTitle: String {
        switch viewModel.step {
        case .success: return "All Set"
        default: return "Add Device"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .scan: scanStep
        case .wifiList: wifiListStep
        case .password(let ssid): passwordStep(ssid: ssid)
        case .provisioning(let phase): provisioningStep(phase: phase)
        case .success: successStep
        case .failure(let message): failureStep(message: message)
        }
    }

    // MARK: - Scan

    private var scanStep: some View {
        DeviceScanList(
            scanViewModel: viewModel.scanViewModel,
            onSelectDevice: { viewModel.selectDevice($0) }
        )
    }

    // MARK: - Wi-Fi list

    private var wifiListStep: some View {
        List {
            Section {
                ForEach(Array(viewModel.wifiNetworks.enumerated()), id: \.offset) { _, ssid in
                    Button {
                        viewModel.selectSSID(ssid)
                    } label: {
                        HStack {
                            Text(ssid)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "wifi")
                                .foregroundStyle(DeviceTheme.accent)
                        }
                    }
                }
            } header: {
                Text("Choose a Wi-Fi network for \(viewModel.selectedDeviceName)")
            } footer: {
                if viewModel.wifiNetworks.isEmpty {
                    Text("No Wi-Fi networks detected. Grant location permission or move closer to your router.")
                }
            }
        }
    }

    // MARK: - Password

    private func passwordStep(ssid: String) -> some View {
        DevicePasswordForm(
            ssid: ssid,
            password: $viewModel.passwordInput,
            onConnect: { viewModel.startProvisioning(ssid: ssid) }
        )
    }

    // MARK: - Provisioning

    private func provisioningStep(phase: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Connecting to Wi-Fi")
                .font(.headline)
            Text(phase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Success

    private var successStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DeviceTheme.accent)
            Text("Device Connected")
                .font(.title2.bold())
            Text("\(viewModel.selectedDeviceName) is now on your Wi-Fi network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                finishFlow(outcome: .showDevices)
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Failure

    private func failureStep(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Connect", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.retryPasswordEntry()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Close

    private func closeEntireFlow() {
        viewModel.finish()
        dismiss()
    }

    private func finishFlow(outcome: AddDeviceFlowOutcome) {
        viewModel.finish()
        dismiss()
    }
}

// MARK: - Scan list

private struct DeviceScanList: View {
    @ObservedObject var scanViewModel: DemoScanDevicesViewModel
    let onSelectDevice: (BLEDevice) -> Void
    @ObservedObject private var bluetoothManager = BluetoothManager.shared
    @State private var hasWaitedForScan = false

    private var visibleDevices: [BLEDevice] {
        scanViewModel.orderedDevices.filter { scanViewModel.shouldRender($0) }
    }

    var body: some View {
        Group {
            if !bluetoothManager.isBluetoothOn {
                ContentUnavailableView {
                    Label("Bluetooth Is Off", systemImage: "antenna.radiowaves.left.and.right.slash")
                } description: {
                    Text("Turn on Bluetooth to find nearby LIMI devices.")
                } actions: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if visibleDevices.isEmpty && hasWaitedForScan {
                ContentUnavailableView {
                    Label("No Devices Nearby", systemImage: "lightbulb.slash")
                } description: {
                    Text(DeviceAppGuidance.scanEmpty)
                }
            } else if visibleDevices.isEmpty {
                ContentUnavailableView {
                    Label("Scanning", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text("Looking for LIMI devices over Bluetooth…")
                } actions: {
                    ProgressView()
                        .padding(.top, 8)
                }
            } else {
                deviceList
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                hasWaitedForScan = true
            }
        }
        .overlay {
            if scanViewModel.isConnectingToBLE {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Connecting to device…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var deviceList: some View {
        List {
            Section {
                ForEach(visibleDevices) { device in
                    Button {
                        onSelectDevice(device)
                    } label: {
                        scanRow(device)
                    }
                    .opacity(scanViewModel.deviceOpacity(device))
                    .disabled(scanViewModel.isDeviceDisabled(device))
                }
            } header: {
                HStack {
                    Text("Available Devices")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            } footer: {
                Text("Make sure your LIMI device is powered on and nearby.")
            }
        }
    }

    private func scanRow(_ device: BLEDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.deviceType == .bluetooth ? "lamp.table" : "wifi")
                .foregroundStyle(DeviceTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .foregroundStyle(.primary)
                Text(statusText(device))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if scanViewModel.isDeviceConnected(device) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DeviceTheme.accent)
            }
        }
    }

    private func statusText(_ device: BLEDevice) -> String {
        if device.deviceType == .bluetooth { return "Bluetooth" }
        let status = device.reachability == .online ? "Online" : "Offline"
        if let ip = device.ipAddress, !ip.isEmpty {
            return "\(status) • \(ip)"
        }
        return status
    }
}

// MARK: - Password form

private struct DevicePasswordForm: View {
    let ssid: String
    @Binding var password: String
    let onConnect: () -> Void

    @State private var isPasswordVisible = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("Wi-Fi password", text: $password)
                        } else {
                            SecureField("Wi-Fi password", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($passwordFocused)

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }
            } header: {
                Text(ssid)
            } footer: {
                Text("Enter the password for your Wi-Fi network. The device will join this network.")
            }

            Section {
                Button("Connect Device") {
                    onConnect()
                }
                .disabled(password.isEmpty)
            }
        }
        .onAppear {
            isPasswordVisible = false
            passwordFocused = true
        }
    }
}

#Preview {
    DeviceAddFlowView()
}
