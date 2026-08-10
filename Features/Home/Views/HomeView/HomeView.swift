// MARK: - MVVM Architecture

import SwiftUI
import SwiftData
import RoomPlan

// MARK: - Model used by HomeView UI
struct WifiDevice: Identifiable {
    let id: String            // Stable identifier from Bonjour (uuid/service name)
    let uuid: String
    let chennalMac: String
    let chennalCount: Int
    let channelTypes: [String]  // Array of "CCT" or "RGB" for each channel
    let deviceName: String
    var isOnline: Bool
}

// MARK: - BLE scan helper (unchanged)
extension HomeViewContent {
    private func startBLEScan() {
        bluetoothManager.startScanning { devices in
            DispatchQueue.main.async {
                viewModel.handleDiscoveredBLEDevices(devices, allowedNames: allowedNames)
            }
        }
    }
}

// MARK: - Main View
struct HomeView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        HomeViewContent(appEnvironment: appEnvironment)
    }
}

private struct HomeViewContent: View {
    @State private var isDownloading = false

    // MARK: - Properties
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var bonjourBrowser = HomeBonjourAdapter()
    private let allowedNames: Set<String> = ["1 CH-HUB", "4 CH-HUB", "8 CH-HUB", "16 CH-HUB", "Mini Controller", "LIMI Device"]

    init(appEnvironment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: appEnvironment))
        _bluetoothManager = StateObject(wrappedValue: appEnvironment.bluetooth.makeHomeBluetoothAdapter())
        _ = RoominatorFileManager.shared
    }
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @StateObject private var bluetoothManager: HomeBluetoothAdapter
    @StateObject private var modulesManager = HomeModulesAdapter()
    private let contextManager: HomeContextManaging = DefaultHomeContextManager()
    private let userDataRefresher: HomeUserDataRefreshing = DefaultHomeUserDataRefresher()
    private let roleProvider: HomeRoleProviding = DefaultHomeRoleProvider()
    private let welcomeCoordinator: HomeWelcomeCoordinating = DefaultHomeWelcomeCoordinator()

    // 2-column grid layout
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    @State private var showProfileFromHome: Bool = false
    @State private var orbIntensity: CGFloat = 4.0
    @State private var orbVolume: CGFloat = 0.2
    @State private var isModulesButtonAnimating: Bool = false
    @State private var selectedModule: Module? = nil
    @State private var isModuleEditMode: Bool = false
    @StateObject private var roomCaptureController = RoomCaptureController()

    // Controls presentation of the "Add Your First Device" login flow
    @State private var isShowingLogin: Bool = false

    private var card: Card {
        Card(
            imageName: [],
            title: "Configurator",
            price: 0,
            description: "",
            objectName: "",
            size: "",
            color: ""
        )
    }

    @State private var isWeatherExpanded: Bool = false
    @AppStorage("globalUserLocation") private var storedUserLocation: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DeepSpaceBackground(showParticles: false)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isModuleEditMode {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isModuleEditMode = false
                                viewModel.dismissModuleActionMenu()
                            }
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isModuleEditMode = true
                        }
                    }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Weather — tap to expand/collapse
                        WeatherWidgetView(isExpanded: $isWeatherExpanded, contextManager: contextManager)
                            .padding(.top, 60)

                        if modulesManager.addedModules.isEmpty {
                            emptyStateView
                                .padding(.top, 20)
                        } else {
                            modulesGrid
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 120)
                    }
                }
                if isModuleEditMode && !modulesManager.addedModules.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            LimiPillButton(title: "Add More Modules") {
                                contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "modules"])
                                viewModel.presentModulesView()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                        }
                    }
                }

                    if let device = viewModel.pendingBLEDevice {
                        VStack {
                            Spacer()
                            VStack(spacing: 14) {
                                Text("Found New Device")
                                    .font(LimiTypography.title3)
                                    .foregroundColor(.appTextPrimary)

                                Text(device.name)
                                    .font(LimiTypography.callout)
                                    .foregroundColor(.brandHighlight)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule().fill(Color.brandHighlight.opacity(0.12))
                                    )

                                Text(device.id)
                                    .font(LimiTypography.caption2)
                                    .foregroundColor(.appTextMuted)

                                HStack(spacing: 12) {
                                    LimiPrimaryButton(title: "Connect", height: 46) {
                                        if let dev = viewModel.acceptPendingBLEDevice() {
                                            bluetoothManager.selectAndConnect(name: dev.name, uuidString: dev.id)
                                            bluetoothManager.readWifiList { list in
                                                DispatchQueue.main.async {
                                                    viewModel.presentWifiProvisioning(list: list)
                                                }
                                            }
                                        }
                                    }
                                    LimiSecondaryButton(title: "Not Now", height: 46) {
                                        viewModel.rejectPendingBLEDevice()
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding(20)
                            .glassCard(cornerRadius: 20, fillOpacity: 0.12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .zIndex(4)
                    }
                    
                    // MARK: - Module Action Menu Popup
                    if viewModel.showModuleActionMenu, let module = viewModel.selectedModuleForAction {
                        ZStack {
                            Color.appOverlayScrim
                                .ignoresSafeArea()
                                .onTapGesture {
                                    viewModel.dismissModuleActionMenu()
                                    isModuleEditMode = false
                                }

                            VStack(spacing: 0) {
                                VStack(spacing: 6) {
                                    Text(module.title)
                                        .font(LimiTypography.button)
                                        .foregroundColor(.appTextPrimary)
                                    Text("What would you like to do?")
                                        .font(LimiTypography.footnote)
                                        .foregroundColor(.appTextSecondary)
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 14)

                                Rectangle()
                                    .fill(Color.appGlassFillMedium)
                                    .frame(height: 1)

                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        modulesManager.toggleModuleStatus(for: module.id)
                                    }
                                    viewModel.dismissModuleActionMenu()
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "trash")
                                            .font(LimiTypography.body)
                                            .foregroundColor(.appDanger)
                                        Text("Uninstall")
                                            .font(LimiTypography.callout)
                                            .foregroundColor(.appDanger)
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                }

                                Rectangle()
                                    .fill(Color.appGlassFillMedium)
                                    .frame(height: 1)

                                Button(action: {
                                    viewModel.dismissModuleActionMenu()
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "xmark")
                                            .font(LimiTypography.body)
                                            .foregroundColor(.appTextSecondary)
                                        Text("Cancel")
                                            .font(LimiTypography.callout)
                                            .foregroundColor(.appTextSecondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                }
                            }
                            .glassCard(cornerRadius: 20, fillOpacity: 0.12)
                            .padding(.horizontal, 36)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showModuleActionMenu)
                        .zIndex(5)
                    }
                
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.setupInitialState()
                
            }
            .overlay(alignment: .bottom) {
                if !isModuleEditMode {
                    EnhancedBottomNavigationView(
                        showARScan: $viewModel.showARScan,
                        showCustomer: $viewModel.showCustomer,
                        showGrouping: $viewModel.showGrouping,
                        showWebView: viewModel.routeBinding(.webView),
                        selectedTab: $viewModel.selectedTab,
                        isLoaded: $viewModel.isLoaded,
                        isSidebarOpen: $viewModel.isSidebarOpen,
                        contextManager: contextManager
                    )
                    .ignoresSafeArea(.keyboard)
                }
            }

        }
        .frame(maxWidth: .infinity)
        .trackScreen("HomeView")
        .onChange(of: storedUserLocation) { _, _ in
            contextManager.updateContext(screen: "HomeView", metadata: [:])
        }
        .onReceive(NotificationCenter.default.publisher(for: .limiUserLocationDidChange)) { _ in
            contextManager.updateContext(screen: "HomeView", metadata: [:])
        }
        .onChange(of: viewModel.selectedTab) { _, new in
            contextManager.updateHomeTab(new)
        }
        .onAppear {
            let role = roleProvider.role()
                print("🔹 Current Role:", role)

            

            viewModel.setupInitialState()
            // Fetch user data when home view appears
            userDataRefresher.refreshUserData()

            // ✅ Bonjour ON (exact lifecycle)
            bonjourBrowser.startBrowsing()

            // BLE scan
            startBLEScan()

            welcomeCoordinator.runFirstHomeWelcomeIfNeeded(contextManager: contextManager)
        }
        // Sheet for Wi-Fi device detail based on channel count
//        .sheet(item: $selectedWifiDevice) { device in
//            if device.chennalCount == 1 {
//                CCTLEDView(chennalMac: device.chennalMac)
//            } else {
//                CCTLEDView(chennalMac: device.chennalMac)
//            }
//        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.voice)) {
            VoiceView()
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.moduler)) {
            ModulerView()
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.wifiProvisioning)) {
            WifiList(deviceName: viewModel.selectedDeviceName, deviceId:  viewModel.selectedDeviceId , wifiList: viewModel.selectedWifiSSID)
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.connectedDevices)) {
            ConnectedDevicesView()
        }
        .sheet(isPresented: viewModel.routeBinding(.configurator)) {
            LimiContentView()
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.arView)) {
            PortalWebView()
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.roomScan)) {
            RoomPlanContentView().environment(roomCaptureController)
        }
        .fullScreenCover(isPresented: viewModel.routeBinding(.voicePendantScan)) {
            VoicePendantScanView()
        }
        .sheet(isPresented: $showProfileFromHome) {
            ProfileView()
        }
        .onChange(of: viewModel.activeRoute) { _, route in
            if route == nil { clearHomeSheetFlowMarker() }
        }
        .onDisappear {
            // ✅ Bonjour OFF (exact lifecycle)
            bonjourBrowser.stopBrowsing()
            bluetoothManager.stopScanning()
        }

        // ✅ Respect Bonjour reachability + keep offline ghosts listed
        .onReceive(bonjourBrowser.$discoveredWiFiDevices) { newDevices in
            let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            viewModel.processBonjourWiFiDevices(newDevices, allowedNames: normalizedAllowed)
        }
        .onChange(of: bluetoothManager.isBluetoothOn) { _, on in
            if on {
                startBLEScan()
            } else {
                viewModel.handleBluetoothStateChanged(isOn: on)
            }
        }
        // hello world
    }
    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(LimiTypography.title2)
                .foregroundColor(.appTextMuted)

            Text("home.empty.title".localized)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Text("home.empty.subtitle".localized)
                .font(LimiTypography.subheadline)
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)

            LimiPrimaryButton(title: "home.empty.cta".localized, height: 48) {
                contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "modules"])
                viewModel.presentModulesView()
            }
            .padding(.horizontal, 40)
        }
        .padding(24)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: LimiCard.radiusLarge, strokeOpacity: 0.06, fillOpacity: 0.04)
        .padding(.horizontal, 16)
    }

    // MARK: - Modules Grid

    private var modulesGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            let addedModules = modulesManager.addedModules
            ForEach(addedModules) { module in
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(module.icon)
                                .renderingMode(.template)
                                .font(LimiTypography.button)
                                .foregroundColor(.brandHighlight)
                            Spacer()
                        }
                        Spacer()
                        Text(module.title)
                            .font(LimiTypography.callout)
                            .foregroundColor(.appTextPrimary)

                        HStack {
                            Text("settings.title".localized)
                                .font(LimiTypography.caption)
                                .foregroundColor(.appTextSecondary)
                            Spacer()
                            Button(action: {
                                viewModel.presentModuleActionMenu(for: module)
                            }) {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(LimiTypography.callout)
                                    .foregroundColor(.appTextMuted)
                            }
                        }
                    }
                    .frame(minHeight: LimiCard.moduleMinHeight)
                    .padding(14)
                    .limiHomeCard(cornerRadius: LimiCard.radius)
                    .scaleEffect(isModuleEditMode ? 0.97 : 1.0)
                    .rotationEffect(.degrees(isModuleEditMode ? -1.5 : 0))
                    .animation(
                        isModuleEditMode ? .easeInOut(duration: 0.15).repeatForever(autoreverses: true) : .default,
                        value: isModuleEditMode
                    )
                    .onTapGesture {
                        if !isModuleEditMode { handleModuleTap(module) }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isModuleEditMode = true
                        }
                    }

                    if isModuleEditMode {
                        Button(action: {
                            viewModel.presentModuleActionMenu(for: module)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.appDanger)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "xmark")
                                    .font(LimiTypography.caption2)
                                    .foregroundColor(.appTextPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .offset(x: -6, y: -6)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .scaledToFit()        // image ko aspect ratio ke saath fit karega
                    .frame(width: 160, height: 30)
                    .clipped()            // frame se bahir ka part cut ho jayega

                
            }

            Spacer()

//            Button(action: {
//                showProfileFromHome = true
//            }) {
//                ZStack {
//                    Color.appCanvasElevated.cornerRadius(20)
//                    Image("bottom_profile_view")
//                        .renderingMode(.template)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 22, height: 22)
//                        .foregroundColor(.appTextPrimary)
//
//                    Circle()
//                        .stroke(Color.themeWhite, lineWidth: 1.4)
//                        .frame(width: 44, height: 44)
//                }
//                .frame(width: 48, height: 48)
//            }
        }
        .frame(height: 44)
    }

    private var voiceOrb: some View {
        ZStack {
            Circle()
                .fill(Color.themeBlack)
                .frame(width: 260, height: 260)
                .shadow(color: Color.themeBlack.opacity(0.9), radius: 60, x: 0, y: 18)
                .overlay(
                    // INNER SHADOW (inset shadow equivalent)
                    Circle()
                        .stroke(Color.themeWhite.opacity(0.3), lineWidth: 3)
                        .blur(radius: 10)
                        .offset(x: -6, y: -1)
                        .mask(
                            Circle()
                                .fill(Color.themeBlack)
                        )
                )

            VStack(spacing: 12) {
                Text("Hey, Limi here!")
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)

                Text("Tap to chat")
                    .font(LimiTypography.body)
                    .foregroundColor(Color.appTextPrimary.opacity(0.65))
//                OrbView(intensity: $orbIntensity, currentVolume: $orbVolume)
//                    .frame(width: 160, height: 160)

                Image("Vector-2")
                    .scaledToFit()
                    .onTapGesture {
                        contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "voice_chat"])
                        viewModel.presentVoiceView()
                    }

            }
        }
        .frame(width: 260, height: 260)
        .contentShape(Circle())
    }
    // MARK: - Module Navigation Handler
    private func handleModuleTap(_ module: Module) {
        switch viewModel.presentDestination(for: module) {
        case .connectedDevices:
            contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "devices"])
        case .configurator:
            contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "configurator"])
        case .arView:
            contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "ar_portal"])
        case .roomScan:
            contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "room_scan"])
        case .voicePendantScan:
            contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": "voice_pendant_scan"])
        default:
            break
        }
    }

    private func clearHomeSheetFlowMarker() {
        contextManager.updateContext(screen: "HomeView", metadata: ["sheet_flow": ""])
    }

}

// MARK: - Device Card (unchanged except for using isOnline from WifiDevice)


// MARK: - Custom Shape for Rounded Corners
struct RoundedCornerShape: Shape {
    var cornerRadius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Enhanced Sidebar with Improved Animation
// (unchanged; left as-is)
// ... your EnhancedSidebarView code here ...

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
