import Combine
import SwiftUI

// MARK: - Routes

enum AddDeviceRoute: String, Identifiable, Equatable {
    case deviceScan
    case legacyInstallerFlow

    var id: String { rawValue }
}

enum AddDeviceFlowOutcome: Equatable {
    case showDevices
    case cancelled
}

enum AddDeviceCoordinator {
    @ViewBuilder
    static func destination(
        for route: AddDeviceRoute,
        onBack: (() -> Void)? = nil,
        onFinished: ((AddDeviceFlowOutcome) -> Void)? = nil
    ) -> some View {
        switch route {
        case .deviceScan:
            AddDeviceFlowView(onFinished: onFinished)
        case .legacyInstallerFlow:
            AddDeviceView()
        }
    }
}

// MARK: - View model

@MainActor
final class AddDeviceFlowViewModel: ObservableObject {

    enum Step: Equatable {
        case scan
        case wifiList
        case password(ssid: String)
        case provisioning(phase: String)
        case success
        case failure(message: String)
    }

    @Published private(set) var step: Step = .scan
    @Published var passwordInput: String = ""
    @Published private(set) var scanViewModel = DemoScanDevicesViewModel()

    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false
    private var hasStartedFlow = false
    private var lastSelectedSSID: String = ""

    var selectedDeviceName: String { scanViewModel.selectedName ?? "Device" }
    var selectedDeviceId: String { scanViewModel.selectedId ?? "" }
    var wifiNetworks: [String] { scanViewModel.ssidNameArray }

    init() {
        scanViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        scanViewModel.$wifiProvisioningRequested
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scanViewModel.acknowledgeWifiProvisioningNavigation()
                guard self.step == .scan else { return }
                self.step = .wifiList
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        if !hasStartedFlow {
            step = .scan
            passwordInput = ""
            scanViewModel.resetProvisioningSession()
            hasStartedFlow = true
        }
        scanViewModel.onAppear()
    }

    func pauseForBackground() {
        scanViewModel.onDisappear()
    }

    func resumeFromBackground() {
        guard !hasFinished else { return }
        scanViewModel.onAppear()
    }

    func selectDevice(_ device: BLEDevice) {
        guard step == .scan else { return }

        switch device.deviceType {
        case .bluetooth:
            scanViewModel.connectBLEDevice(name: device.name, id: device.uuid)
        case .wifi:
            guard device.reachability == .online else { return }
            scanViewModel.selectedName = device.name
            scanViewModel.selectedId = device.txtRecord?["deviceId"] ?? device.uuid
            step = .success
        }
    }

    func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        hasStartedFlow = false
        WiFiProvisioningCoordinator.shared.cancel()
        scanViewModel.onDisappear()
    }

    func selectSSID(_ ssid: String) {
        lastSelectedSSID = ssid
        passwordInput = ""
        step = .password(ssid: ssid)
    }

    func startProvisioning(ssid: String) {
        guard !ssid.isEmpty else { return }
        step = .provisioning(phase: "Sending Wi-Fi credentials…")

        WiFiProvisioningCoordinator.shared.provisionAndVerify(
            deviceName: selectedDeviceName,
            bleDeviceId: selectedDeviceId,
            ssid: ssid,
            password: passwordInput,
            onPhaseUpdate: { [weak self] phase in
                self?.step = .provisioning(phase: phase)
            },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let outcome):
                    SelectedDevicesStorage.shared.addOrUpdate(
                        name: self.selectedDeviceName,
                        uuid: self.selectedDeviceId
                    )
                    // Persist hardwareId ↔ BLE UUID so Cloud-miss can reconnect smoothly.
                    ConfiguredBLEDeviceStore.shared.remember(
                        hardwareId: outcome.deviceId,
                        blePeripheralUUID: self.selectedDeviceId,
                        displayName: outcome.deviceName.isEmpty
                            ? self.selectedDeviceName
                            : outcome.deviceName
                    )
                    self.step = .success
                case .failure(let failure):
                    self.step = .failure(message: failure.userMessage)
                }
            }
        )
    }

    func retryPasswordEntry() {
        if !lastSelectedSSID.isEmpty {
            step = .password(ssid: lastSelectedSSID)
        } else if !wifiNetworks.isEmpty {
            step = .wifiList
        } else {
            step = .scan
            scanViewModel.resetProvisioningSession()
        }
    }
}

// MARK: - Flow view

struct AddDeviceFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AddDeviceFlowViewModel()
    @State private var isPasswordVisible = false
    var onFinished: ((AddDeviceFlowOutcome) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()
                stepContent
            }
            .limiModalNavigationBar(title: navigationTitle, onClose: closeEntireFlow)
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear {
            // App switcher also triggers onDisappear — only tear down when the modal is dismissed.
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
        .trackScreen("AddDeviceFlowView", metadata: ["surface": "add_device_flow"])
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

    private var scanStep: some View {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Scanning for nearby Limi devices")
            AnimatedSearchButton(iconName: "magnifyingglass")
            AddDeviceScanDeviceList(
                scanViewModel: viewModel.scanViewModel,
                onSelectDevice: { viewModel.selectDevice($0) }
            )
        }
        .overlay { AddDeviceConnectingOverlay(scanViewModel: viewModel.scanViewModel) }
    }

    private var wifiListStep: some View {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Choose a Wi-Fi network for your device")

            HStack {
                Image(systemName: "wifi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.appTextPrimary)
            }
            .padding(.vertical, 12)

            List {
                ForEach(Array(viewModel.wifiNetworks.enumerated()), id: \.offset) { _, ssid in
                    HStack(spacing: 12) {
                        Text(ssid)
                            .font(LimiTypography.button)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Image(systemName: "wifi")
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectSSID(ssid) }
                    .listRowBackground(Color.clear)
                }
                if viewModel.wifiNetworks.isEmpty {
                    HStack {
                        Text("No Wi‑Fi detected. Grant location permission or connect to a network.")
                            .foregroundColor(.appTextMuted)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(
                Rectangle()
                    .fill(Color.appSurfacePrimary)
                    .cornerRadius(24)
            )
            .limiFloatingOrbClearance()
        }
    }

    private func passwordStep(ssid: String) -> some View {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Enter the password for your Wi-Fi network")

            VStack(spacing: 16) {
                HStack {
                    Text("Wifi Password")
                        .font(LimiTypography.title3)
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                HStack {
                    Text(ssid)
                        .font(LimiTypography.title2)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .padding(.bottom, 34)

                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("Enter your Wi-Fi password", text: $viewModel.passwordInput)
                        } else {
                            SecureField("Enter your Wi-Fi password", text: $viewModel.passwordInput)
                        }
                    }
                    .font(LimiTypography.headline)
                    .foregroundColor(Color.appTextSoft)
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
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.appSurfacePrimary)
                )
                .padding(.horizontal, 16)
            }
            .onAppear { isPasswordVisible = false }

            Spacer()

            LimiPrimaryButton(title: "Connect Device") {
                viewModel.startProvisioning(ssid: ssid)
            }
            .disabled(viewModel.passwordInput.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .limiFloatingOrbClearance()
        }
    }

    private func provisioningStep(phase: String) -> some View {
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

    private var successStep: some View {
        DemoConnectedWifiView(deviceName: viewModel.selectedDeviceName) {
            finishFlow(outcome: .showDevices)
        }
    }

    private func failureStep(message: String) -> some View {
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
                viewModel.retryPasswordEntry()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .limiFloatingOrbClearance()
        }
    }

    private func closeEntireFlow() {
        viewModel.finish()
        onFinished?(.cancelled)
        dismiss()
    }

    private func finishFlow(outcome: AddDeviceFlowOutcome) {
        viewModel.finish()
        onFinished?(outcome)
        dismiss()
    }
}

// MARK: - Scan list (observes nested view model directly)

private struct AddDeviceScanDeviceList: View {
    @ObservedObject var scanViewModel: DemoScanDevicesViewModel
    let onSelectDevice: (BLEDevice) -> Void

    var body: some View {
        VStack {
            HStack {
                Text("Available Devices")
                    .font(LimiTypography.title3)
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.horizontal, 16)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(scanViewModel.orderedDevices) { device in
                        if scanViewModel.shouldRender(device) {
                            DevicesButton(
                                deviceName: device.name,
                                searchDeviceUUID: device.uuid,
                                onConnect: { _, _ in onSelectDevice(device) },
                                isConnected: scanViewModel.isDeviceConnected(device),
                                deviceType: device.deviceType,
                                ipAddress: device.ipAddress,
                                reachability: device.reachability
                            )
                            .opacity(scanViewModel.deviceOpacity(device))
                            .disabled(scanViewModel.isDeviceDisabled(device))
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .limiFloatingOrbClearance()
            }

            Spacer()
        }
    }
}

private struct AddDeviceConnectingOverlay: View {
    @ObservedObject var scanViewModel: DemoScanDevicesViewModel

    var body: some View {
        if scanViewModel.isConnectingToBLE {
            ZStack {
                Color.appOverlayScrim.ignoresSafeArea()
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                        .scaleEffect(1.5)
                    Text("Connecting to device...")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                }
            }
        }
    }
}
