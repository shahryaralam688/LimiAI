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
    @ObservedObject private var virtualDeviceStore = VirtualDeviceStore.shared

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .deviceNeumorphicNavigationChrome()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { closeEntireFlow() }
                            .foregroundStyle(HomeUI1Color.accentGreen)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isProvisioning)
        .onAppear { viewModel.onAppear() }
        .onAppear {
            // Re-sync cloud virtual-group specs whenever a hub MAC is newly resolved,
            // so the identified member folds into its hub card.
            viewModel.scanViewModel.onIdentityResolved = {
                AddDeviceVirtualGroupingBridge.sync(into: viewModel.scanViewModel)
            }
            AddDeviceVirtualGroupingBridge.sync(into: viewModel.scanViewModel)
        }
        .onChange(of: virtualDeviceStore.enabledHardwareIds) { _, _ in
            AddDeviceVirtualGroupingBridge.sync(into: viewModel.scanViewModel)
        }
        .onChange(of: virtualDeviceStore.virtualDeviceID) { _, _ in
            AddDeviceVirtualGroupingBridge.sync(into: viewModel.scanViewModel)
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
        case .wifiList, .password, .provisioning: return ""
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
        LimiAppleDeviceSetupView(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .wifiList,
            networks: viewModel.wifiNetworks,
            password: $viewModel.passwordInput,
            onSelectSSID: { viewModel.selectSSID($0) },
            onConnect: {},
            onBack: {}
        )
    }

    // MARK: - Password

    private func passwordStep(ssid: String) -> some View {
        LimiAppleDeviceSetupView(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .password(ssid),
            networks: viewModel.wifiNetworks,
            password: $viewModel.passwordInput,
            onSelectSSID: { _ in },
            onConnect: { viewModel.startProvisioning(ssid: ssid) },
            onBack: { viewModel.returnToWifiList() }
        )
    }

    // MARK: - Provisioning

    private func provisioningStep(phase: String) -> some View {
        LimiPairingOverlay(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .provisioning(phase),
            modelName: LimiPairingAssets.bundledName(forDeviceId: viewModel.selectedDeviceId),
            placement: .centered,
            onPrimary: nil,
            onDismiss: nil
        )
    }

    // MARK: - Success

    private var successStep: some View {
        LimiPairingOverlay(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .connected(viewModel.successDetailMessage),
            modelName: LimiPairingAssets.bundledName(forDeviceId: viewModel.selectedDeviceId),
            placement: .centered,
            onPrimary: { finishFlow(outcome: .showDevices) },
            onDismiss: { finishFlow(outcome: .showDevices) }
        )
    }

    // MARK: - Failure

    private func failureStep(message: String) -> some View {
        DeviceNeumorphicScreen {
            VStack(spacing: 20) {
                Spacer()
                DeviceNeumorphicStatusCard(
                    title: "Couldn't Connect",
                    message: message,
                    systemImage: "wifi.exclamationmark"
                )
                DeviceNeumorphicButton(
                    title: "Try Again",
                    systemImage: "arrow.clockwise",
                    kind: .accent
                ) {
                    viewModel.retryPasswordEntry()
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .deviceNeumorphicNavigationChrome()
    }

    // MARK: - Close

    private func closeEntireFlow() {
        viewModel.finish(force: true)
        dismiss()
    }

    private func finishFlow(outcome: AddDeviceFlowOutcome) {
        viewModel.finish(force: true)
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
        DeviceNeumorphicScreen {
            Group {
                if !bluetoothManager.isBluetoothOn {
                    statusBody(
                        title: "Bluetooth Is Off",
                        message: "Turn on Bluetooth to find nearby LIMI devices.",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else if visibleDevices.isEmpty && !scanViewModel.identitiesSettled {
                    statusBody(
                        title: "Identifying Hubs",
                        message: "Checking nearby hubs over Bluetooth…",
                        systemImage: "dot.radiowaves.left.and.right",
                        showsProgress: true
                    )
                } else if visibleDevices.isEmpty && hasWaitedForScan {
                    statusBody(
                        title: "No Devices Nearby",
                        message: DeviceAppGuidance.scanEmpty,
                        systemImage: "lightbulb.slash"
                    )
                } else if visibleDevices.isEmpty {
                    statusBody(
                        title: "Scanning",
                        message: "Looking for LIMI devices over Bluetooth…",
                        systemImage: "dot.radiowaves.left.and.right",
                        showsProgress: true
                    )
                } else {
                    deviceList
                }
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
                LimiPairingOverlay(
                    deviceName: scanViewModel.selectedName ?? "LIMI Device",
                    deviceId: scanViewModel.selectedId,
                    mode: .connecting,
                    modelName: LimiPairingAssets.bundledName(forDeviceId: scanViewModel.selectedId),
                    onPrimary: nil,
                    onDismiss: nil
                )
            }
        }
    }

    @ViewBuilder
    private func statusBody(
        title: String,
        message: String,
        systemImage: String,
        showsProgress: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)
            DeviceNeumorphicStatusCard(
                title: title,
                message: message,
                systemImage: systemImage,
                showsProgress: showsProgress
            )
            if let actionTitle, let action {
                DeviceNeumorphicButton(
                    title: actionTitle,
                    systemImage: "gear",
                    kind: .accent,
                    action: action
                )
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var deviceList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Available Devices")
                        .font(HomeUI1Type.body(14))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                    Spacer()
                    if scanViewModel.isConnectingToBLE {
                        ProgressView()
                            .tint(HomeUI1Color.accentGreen)
                            .controlSize(.small)
                    }
                }
                .padding(.top, 8)

                if scanViewModel.isResolvingIdentities {
                    identifyingBar
                }

                ForEach(visibleDevices) { device in
                    let gating = memberResolveGating(device)
                    Button {
                        if !gating { onSelectDevice(device) }
                    } label: {
                        scanRow(device, gating: gating)
                    }
                    .buttonStyle(.plain)
                    .opacity(scanViewModel.deviceOpacity(device))
                    .disabled(scanViewModel.isDeviceDisabled(device) || gating)
                }

                Text("Make sure your LIMI device is powered on and nearby.")
                    .font(HomeUI1Type.caption(12))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // Thin "identifying hubs" bar shown while unconfigured hubs are resolved over BLE.
    private var identifyingBar: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(HomeUI1Color.accentGreen)
                .controlSize(.small)
            Text("Identifying nearby hubs over Bluetooth…")
                .font(HomeUI1Type.caption(12))
                .foregroundStyle(HomeUI1Color.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
    }

    /// Members found vs total for a virtual master row (nil for non-hubs).
    private func memberFoundTotal(_ device: BLEDevice) -> (found: Int, total: Int)? {
        guard let master = device.virtualMaster else { return nil }
        return (master.memberDevices.count, master.memberHardwareIds.count)
    }

    /// Hub card stays gated (non-tappable, shows loader) until all members are
    /// identified OR background resolution has settled.
    private func memberResolveGating(_ device: BLEDevice) -> Bool {
        guard scanViewModel.isResolvingIdentities,
              let counts = memberFoundTotal(device) else { return false }
        return counts.found < counts.total
    }

    private func scanRow(_ device: BLEDevice, gating: Bool = false) -> some View {
        let connected = scanViewModel.isDeviceConnected(device)
        return DeviceNeumorphicListRow(
            title: device.name,
            subtitle: gating ? gatingSubtitle(device) : statusText(device),
            systemImage: device.isVirtualMaster
                ? "link.circle.fill"
                : (device.deviceType == .bluetooth ? "lamp.table" : "wifi"),
            isAccent: connected && !gating,
            showsChevron: !connected && !gating,
            trailing: rowTrailing(device, connected: connected, gating: gating)
        )
    }

    private func rowTrailing(_ device: BLEDevice, connected: Bool, gating: Bool) -> AnyView? {
        if gating {
            return AnyView(
                ProgressView()
                    .tint(HomeUI1Color.accentGreen)
                    .controlSize(.small)
            )
        }
        if connected {
            return AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HomeUI1Color.accentGreen)
            )
        }
        return nil
    }

    private func gatingSubtitle(_ device: BLEDevice) -> String {
        guard let counts = memberFoundTotal(device) else { return "Identifying…" }
        return "Identifying… \(counts.found) of \(counts.total) found"
    }

    private func statusText(_ device: BLEDevice) -> String {
        if let master = device.virtualMaster {
            let count = master.memberHardwareIds.count
            let hubs = count == 1 ? "1 hub" : "\(count) hubs"
            let bleCandidates = master.memberDevices.filter { $0.deviceType == .bluetooth }
            let presence = VirtualMasterPresence.evaluate(
                memberHardwareIds: master.memberHardwareIds,
                isMQTTOnline: VirtualMasterPresence.defaultMQTTCheck,
                isBLEVisible: { hw in
                    VirtualMasterPresence.isBLEVisible(hardwareId: hw, scannedBLEDevices: bleCandidates)
                },
                isWiFiLANOnline: { hw in
                    if let member = master.memberDevices.first(where: { $0.resolvedHardwareId() == hw }) {
                        return member.deviceType == .wifi && member.reachability == .online
                    }
                    return VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw)
                }
            )
            let hub = VirtualDeviceGroupingSpec.hubDisplayName(pendantCount: master.memberHardwareIds.count)
            return "\(presence.scanSubtitleSuffix) · \(hub) · \(hubs)"
        }
        if device.deviceType == .bluetooth {
            let hw = device.resolvedHardwareId()
            if !hw.isEmpty, VirtualMasterPresence.isMemberCloudOnline(hardwareId: hw) {
                return "Connected · Cloud"
            }
            return "Bluetooth"
        }
        let status = device.reachability == .online ? "Online" : "Offline"
        if let ip = device.ipAddress, !ip.isEmpty {
            return "\(status) • \(ip)"
        }
        return status
    }
}

#Preview {
    DeviceAddFlowView()
}
