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
    @Published private(set) var successDetailMessage: String = "Credentials confirmed"
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

        scanViewModel.$bleConnectError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                guard self.step == .scan else { return }
                self.scanViewModel.clearBLEConnectError()
                self.step = .failure(message: message)
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        if WiFiProvisioningActivityGate.isActive {
            scanViewModel.onAppear()
            return
        }
        if !hasStartedFlow {
            step = .scan
            passwordInput = ""
            scanViewModel.resetProvisioningSession()
            hasStartedFlow = true
        }
        scanViewModel.onAppear()
    }

    func pauseForBackground() {
        guard !WiFiProvisioningActivityGate.isActive else { return }
        scanViewModel.onDisappear()
    }

    func resumeFromBackground() {
        guard !hasFinished else { return }
        scanViewModel.onAppear()
    }

    func selectDevice(_ device: BLEDevice) {
        guard step == .scan else { return }

        DeviceConsole.banner("ADD FLOW — select device")
        DeviceConsole.log(
            .add,
            "selected type=\(device.deviceType) name=\(device.name) uuid=\(device.uuid) reach=\(String(describing: device.reachability)) deviceId=\(device.txtRecord?["deviceId"] ?? "-") master=\(device.isVirtualMaster)"
        )
        DeviceConsole.dumpConfiguredStore(reason: "at select")

        if let master = device.virtualMaster {
            selectVirtualMasterDevice(device, master: master)
            return
        }

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

    private func selectVirtualMasterDevice(_ device: BLEDevice, master: VirtualMasterScanMetadata) {
        scanViewModel.selectedName = device.name
        scanViewModel.selectedId = master.virtualDeviceID

        let allMembersOnline = master.memberHardwareIds.allSatisfy { hw in
            VirtualMasterPresence.isMemberCloudOnline(hardwareId: hw)
                || VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw)
        }
        if allMembersOnline {
            DeviceConsole.log(.add, "master select — all \(master.memberHardwareIds.count) members online")
            step = .success
            return
        }

        guard let bleMember = scanViewModel.preferredBLEMember(for: master) else {
            DeviceConsole.log(.add, "master select — no BLE member available for provisioning")
            step = .failure(message: "No nearby master hub found over Bluetooth. Move closer and try again.")
            return
        }

        scanViewModel.connectBLEDevice(
            name: bleMember.name,
            id: bleMember.uuid,
            virtualMaster: master
        )
    }

    func finish(force: Bool = false) {
        guard !hasFinished else { return }
        if WiFiProvisioningActivityGate.isActive && !force {
            DeviceConsole.log(.add, "finish() skipped — provisioning active")
            return
        }
        hasFinished = true
        hasStartedFlow = false
        AddDeviceFlowActivityGate.setActive(false)
        WiFiProvisioningCoordinator.shared.cancel()
        scanViewModel.onDisappear()
    }

    func selectSSID(_ ssid: String) {
        lastSelectedSSID = ssid
        passwordInput = ""
        DeviceConsole.log(.add, "SSID selected=\(ssid) for ble=\(selectedDeviceName) uuid=\(selectedDeviceId)")
        step = .password(ssid: ssid)
    }

    func startProvisioning(ssid: String) {
        guard !ssid.isEmpty else { return }
        DeviceConsole.banner("ADD FLOW — start provisioning")
        DeviceConsole.log(
            .add,
            "startProvisioning SSID=\(ssid) passwordLen=\(passwordInput.count) bleName=\(selectedDeviceName) bleUUID=\(selectedDeviceId) master=\(scanViewModel.selectedVirtualMaster != nil)"
        )
        DeviceConsole.dumpConfiguredStore(reason: "before startProvisioning")

        if let master = scanViewModel.selectedVirtualMaster {
            startMasterProvisioning(ssid: ssid, master: master)
            return
        }

        step = .provisioning(phase: "Sending Wi-Fi credentials…")

        WiFiProvisioningCoordinator.shared.provisionAndVerify(
            deviceName: selectedDeviceName,
            bleDeviceId: selectedDeviceId,
            ssid: ssid,
            password: passwordInput,
            onPhaseUpdate: { [weak self] phase in
                DeviceConsole.log(.add, "phase → \(phase)")
                self?.step = .provisioning(phase: phase)
            },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let outcome):
                    DeviceConsole.log(
                        .add,
                        "SUCCESS outcome deviceId=\(outcome.deviceId) name=\(outcome.deviceName) → remember bleUUID=\(self.selectedDeviceId)"
                    )
                    SelectedDevicesStorage.shared.addOrUpdate(
                        name: self.selectedDeviceName,
                        uuid: self.selectedDeviceId
                    )
                    LocallyRemovedDeviceStore.shared.clearRemoved(outcome.deviceId)
                    // Persist hardwareId ↔ BLE UUID so Cloud-miss can reconnect smoothly.
                    ConfiguredBLEDeviceStore.shared.remember(
                        hardwareId: outcome.deviceId,
                        blePeripheralUUID: self.selectedDeviceId,
                        displayName: outcome.deviceName.isEmpty
                            ? self.selectedDeviceName
                            : outcome.deviceName
                    )
                    // Free BLE radio for the next single hub (device #2) in the same test session.
                    BluetoothManager.shared.disconnectPeripheral(
                        uuidString: self.selectedDeviceId,
                        suppressReconnect: true
                    )
                    DeviceConsole.dumpConfiguredStore(reason: "after SUCCESS remember")
                    DeviceConsole.dumpBonjourOnline(reason: "after SUCCESS")
                    DeviceConsole.banner("ADD FLOW — done (success)")
                    self.successDetailMessage = "Credentials confirmed"
                    self.step = .success
                case .failure(let failure):
                    DeviceConsole.log(.add, "FAILURE \(failure.userMessage)")
                    DeviceConsole.log(
                        .add,
                        "BLE after fail live=\(BluetoothManager.shared.isLiveConnected(forPeripheralUUID: self.selectedDeviceId)) current=\(BluetoothManager.shared.connectedPeripheral?.identifier.uuidString ?? "nil")"
                    )
                    DeviceConsole.dumpConfiguredStore(reason: "after FAILURE")
                    DeviceConsole.dumpBonjourOnline(reason: "after FAILURE")
                    DeviceConsole.banner("ADD FLOW — done (failure)")
                    self.step = .failure(message: failure.userMessage)
                }
            }
        )
    }

    private func startMasterProvisioning(ssid: String, master: VirtualMasterScanMetadata) {
        let hubCount = master.memberHardwareIds.count
        step = .provisioning(phase: "Preparing Master Device (0 of \(hubCount))…")

        WiFiProvisioningCoordinator.shared.provisionMasterGroup(
            master: master,
            ssid: ssid,
            password: passwordInput,
            skipAlreadyOnline: true,
            networkJoinTimeout: WiFiProvisioningCoordinator.masterNetworkJoinTimeout,
            onPhaseUpdate: { [weak self] phase in
                DeviceConsole.log(.add, "master phase → \(phase)")
                self?.step = .provisioning(phase: phase)
            },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let outcomes):
                    DeviceConsole.log(.add, "MASTER SUCCESS hubs=\(outcomes.count)")
                    for outcome in outcomes {
                        SelectedDevicesStorage.shared.addOrUpdate(
                            name: outcome.deviceName,
                            uuid: outcome.blePeripheralUUID
                        )
                        LocallyRemovedDeviceStore.shared.clearRemoved(outcome.deviceId)
                        ConfiguredBLEDeviceStore.shared.remember(
                            hardwareId: outcome.deviceId,
                            blePeripheralUUID: outcome.blePeripheralUUID,
                            displayName: outcome.deviceName
                        )
                    }
                    DeviceConsole.dumpConfiguredStore(reason: "after MASTER SUCCESS")
                    self.scanViewModel.clearSelectedVirtualMaster()
                    self.successDetailMessage = "Credentials confirmed"
                    self.step = .success
                case .failure(let failure):
                    DeviceConsole.log(.add, "MASTER FAILURE \(failure.userMessage)")
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

    func returnToWifiList() {
        step = .wifiList
    }
}

// MARK: - Flow view

struct AddDeviceFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AddDeviceFlowViewModel()
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

    private var scanStep: some View {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Scanning for nearby Limi devices")
            AnimatedSearchButton(iconName: "magnifyingglass")
            AddDeviceScanDeviceList(
                scanViewModel: viewModel.scanViewModel,
                onSelectDevice: { viewModel.selectDevice($0) }
            )
        }
        .overlay {
            if viewModel.scanViewModel.isConnectingToBLE {
                LimiPairingOverlay(
                    deviceName: viewModel.scanViewModel.selectedName ?? "LIMI Device",
                    deviceId: viewModel.scanViewModel.selectedId,
                    mode: .connecting,
                    modelName: LimiPairingAssets.bundledName(forDeviceId: viewModel.scanViewModel.selectedId),
                    onPrimary: nil,
                    onDismiss: nil
                )
            }
        }
    }

    private var wifiListStep: some View {
        LimiAppleDeviceSetupView(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .wifiList,
            networks: viewModel.wifiNetworks,
            password: $viewModel.passwordInput,
            onSelectSSID: { viewModel.selectSSID($0) },
            onConnect: {},
            onBack: {},
            modelName: LimiPairingAssets.bundledName(forDeviceId: viewModel.selectedDeviceId)
        )
        .limiFloatingOrbClearance()
    }

    private func passwordStep(ssid: String) -> some View {
        LimiAppleDeviceSetupView(
            deviceName: viewModel.selectedDeviceName,
            deviceId: viewModel.selectedDeviceId,
            mode: .password(ssid),
            networks: viewModel.wifiNetworks,
            password: $viewModel.passwordInput,
            onSelectSSID: { _ in },
            onConnect: { viewModel.startProvisioning(ssid: ssid) },
            onBack: { viewModel.returnToWifiList() },
            modelName: LimiPairingAssets.bundledName(forDeviceId: viewModel.selectedDeviceId)
        )
        .limiFloatingOrbClearance()
    }

    private func provisioningStep(phase: String) -> some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
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
        .limiFloatingOrbClearance()
    }

    private var successStep: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
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
        viewModel.finish(force: true)
        onFinished?(.cancelled)
        dismiss()
    }

    private func finishFlow(outcome: AddDeviceFlowOutcome) {
        viewModel.finish(force: true)
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
