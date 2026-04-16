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
extension HomeView {
    private func startBLEScan() {
        bluetoothManager.startScanning { devices in
            let filtered = devices.filter { 
                (allowedNames.contains($0.name) || $0.name.lowercased().hasPrefix("limi1ch-")) 
                && !bleAcceptedIds.contains($0.id) 
                && !bleRejectedIds.contains($0.id) 
            }
            if let match = filtered.first {
                DispatchQueue.main.async {
                    if pendingBLEDevice?.id != match.id {
                        pendingBLEDevice = match
                        showBLEFoundCard = true
                    }
                }
            }
        }
    }
}

// MARK: - Main View
struct HomeView: View {
    @State private var isDownloading = false

    // MARK: - Properties
    @StateObject private var viewModel = HomeViewModel()

    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    private let allowedNames: Set<String> = ["1 CH-HUB", "Mini Controller","LIMI Device"]

    init() {
        _ = RoominatorFileManager.shared
    }
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @ObservedObject var sharedDevice = SharedDevice.shared
    @ObservedObject var modulesManager = ModulesManager.shared

    // 2-column grid layout
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    @State private var wifiDevices: [WifiDevice] = []
    @State private var knownWifiDevices: [String: WifiDevice] = [:] // uuid -> device (persists offline with status)
    @State private var selectedWifiDevice: WifiDevice? = nil
    @State private var showBLEFoundCard: Bool = false
    @State private var pendingBLEDevice: (name: String, id: String)? = nil
    @State private var bleAcceptedIds: Set<String> = []
    @State private var bleRejectedIds: Set<String> = []
    @State private var showDemoAddingWifi: Bool = false
    @State private var showProfileFromHome: Bool = false
    @State private var selectedDeviceName: String = ""
    @State private var selectedDeviceId: String = ""
    @State private var selectedWifiSSID: [String] = []
    @State private var orbIntensity: CGFloat = 4.0
    @State private var orbVolume: CGFloat = 0.2
    @State private var showVoiceView: Bool = false
    @State private var showModulerView: Bool = false
    @State private var isModulesButtonAnimating: Bool = false
    @State private var selectedModuleForAction: Module? = nil
    @State private var showModuleActionMenu: Bool = false
    @State private var selectedModule: Module? = nil
    @State private var isModuleEditMode: Bool = false
    @State private var showConnectedDevices: Bool = false
    @State private var showConfigurator: Bool = false
    @State private var showARView: Bool = false
    @State private var showRoomScan: Bool = false
    @StateObject private var roomCaptureController = RoomCaptureController()

    // 🔹 NEW: track which deviceIds we’ve already sent to the backend
    @State private var allocatedWifiDeviceIds: Set<String> = []

    // 🔹 Track which Banpur uploads we have already sent to avoid duplicates
    @State private var banpurUploadedDeviceIds: Set<String> = []

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
                                showModuleActionMenu = false
                                selectedModuleForAction = nil
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
                        WeatherWidgetView(isExpanded: $isWeatherExpanded)
                            .padding(.top, 60)

                        if modulesManager.getAddedModules().isEmpty {
                            emptyStateView
                                .padding(.top, 20)
                        } else {
                            modulesGrid
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 120)
                    }
                }
                if isModuleEditMode && !modulesManager.getAddedModules().isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            LimiPillButton(title: "Add More Modules") {
                                ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "modules"])
                                showModulerView = true
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                        }
                    }
                }

                    if showBLEFoundCard, let device = pendingBLEDevice {
                        VStack {
                            Spacer()
                            VStack(spacing: 14) {
                                Text("Found New Device")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.appTextPrimary)

                                Text(device.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orbGlow4)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule().fill(Color.orbGlow4.opacity(0.12))
                                    )

                                Text(device.id)
                                    .font(.system(size: 11))
                                    .foregroundColor(.appTextMuted)

                                HStack(spacing: 12) {
                                    LimiPrimaryButton(title: "Connect", height: 46) {
                                        if let dev = pendingBLEDevice {
                                            bleAcceptedIds.insert(dev.id)
                                            showBLEFoundCard = false
                                            pendingBLEDevice = nil
                                            selectedDeviceName = dev.name
                                            selectedDeviceId = dev.id
                                            BluetoothManager.shared.selectAndConnect(name: dev.name, uuidString: dev.id)
                                            BluetoothManager.shared.readWifiList { list in
                                                DispatchQueue.main.async {
                                                    self.selectedWifiSSID = list
                                                    self.showDemoAddingWifi = true
                                                }
                                            }
                                        }
                                    }
                                    LimiSecondaryButton(title: "Not Now", height: 46) {
                                        if let id = pendingBLEDevice?.id { bleRejectedIds.insert(id) }
                                        showBLEFoundCard = false
                                        pendingBLEDevice = nil
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
                    if showModuleActionMenu, let module = selectedModuleForAction {
                        ZStack {
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    showModuleActionMenu = false
                                    isModuleEditMode = false
                                }

                            VStack(spacing: 0) {
                                VStack(spacing: 6) {
                                    Text(module.title)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.appTextPrimary)
                                    Text("What would you like to do?")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appTextSecondary)
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 14)

                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)

                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        modulesManager.toggleModuleStatus(for: module.id)
                                    }
                                    showModuleActionMenu = false
                                    selectedModuleForAction = nil
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundColor(.appDanger)
                                        Text("Uninstall")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.appDanger)
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                }

                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)

                                Button(action: {
                                    showModuleActionMenu = false
                                    selectedModuleForAction = nil
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16))
                                            .foregroundColor(.appTextSecondary)
                                        Text("Cancel")
                                            .font(.system(size: 15, weight: .medium))
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
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showModuleActionMenu)
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
                        showWebView: $viewModel.showWebView,
                        selectedTab: $viewModel.selectedTab,
                        isLoaded: $viewModel.isLoaded,
                        isSidebarOpen: $viewModel.isSidebarOpen
                    )
                    .ignoresSafeArea(.keyboard)
                }
            }

        }
        .frame(maxWidth: .infinity)
        .trackScreen("HomeView")
        .onChange(of: storedUserLocation) { _, _ in
            ContextManager.shared.updateContext(screen: "HomeView", metadata: [:])
        }
        .onReceive(NotificationCenter.default.publisher(for: .limiUserLocationDidChange)) { _ in
            ContextManager.shared.updateContext(screen: "HomeView", metadata: [:])
        }
        .onChange(of: viewModel.selectedTab) { _, new in
            ContextManager.shared.updateHomeTab(new)
        }
        .onAppear {
            let role = AuthManager.shared.getRole()
                print("🔹 Current Role:", role)

            

            viewModel.setupInitialState()
            // Fetch user data when home view appears
            UserDataManager.shared.refreshUserData()

            // ✅ Bonjour ON (exact lifecycle)
            bonjourBrowser.startBrowsing()

            // BLE scan
            startBLEScan()

        }
        // Sheet for Wi-Fi device detail based on channel count
//        .sheet(item: $selectedWifiDevice) { device in
//            if device.chennalCount == 1 {
//                CCTLEDView(chennalMac: device.chennalMac)
//            } else {
//                CCTLEDView(chennalMac: device.chennalMac)
//            }
//        }
        .fullScreenCover(isPresented: $showVoiceView) {
            VoiceView()
        }
        .fullScreenCover(isPresented: $showModulerView) {
            ModulerView()
        }
        .fullScreenCover(isPresented: $showDemoAddingWifi) {
            WifiList(deviceName: selectedDeviceName, deviceId:  selectedDeviceId , wifiList: selectedWifiSSID)
        }
        .fullScreenCover(isPresented: $showConnectedDevices) {
            ConnectedDevicesView()
        }
        .sheet(isPresented: $showConfigurator) {
            LimiContentView()
        }
        .fullScreenCover(isPresented: $showARView) {
            PortalWebView()
        }
        .fullScreenCover(isPresented: $showRoomScan) {
            RoomPlanContentView().environment(roomCaptureController)
        }
        .sheet(isPresented: $showProfileFromHome) {
            ProfileView()
        }
        .onChange(of: showConfigurator) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onChange(of: showConnectedDevices) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onChange(of: showARView) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onChange(of: showRoomScan) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onChange(of: showModulerView) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onChange(of: showVoiceView) { _, open in if !open { clearHomeSheetFlowMarker() } }
        .onDisappear {
            // ✅ Bonjour OFF (exact lifecycle)
            bonjourBrowser.stopBrowsing()
            bluetoothManager.stopScanning()
        }

        // ✅ Respect Bonjour reachability + keep offline ghosts listed
        .onReceive(bonjourBrowser.$discoveredWiFiDevices) { newDevices in
            let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

            // Only keep allowed device names or devices with limi1ch- prefix
            let filtered = newDevices.filter { dev in
                let n = dev.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalizedAllowed.contains(n) || n.hasPrefix("limi1ch-")
            }

            // UUIDs seen in this tick
            let currentUUIDs = Set(filtered.map { $0.uuid })

            // Update/insert seen devices using actual reachability from Bonjour
            for dev in filtered {
                knownWifiDevices[dev.uuid] = wifiDevice(from: dev)

                // 🔹 API CALL: when a Bonjour Wi-Fi device is online and has deviceId in TXT record
                if dev.reachability == .online,
                   let txt = dev.txtRecord,
                   let deviceId = txt["deviceId"],
                   !allocatedWifiDeviceIds.contains(deviceId) {

                    allocatedWifiDeviceIds.insert(deviceId)
                    print("🌐 [Bonjour] New online device discovered, allocating: \(deviceId)")
                    DeviceAllocationService.shared.allocateDevice(deviceId: deviceId)
                }

                // 🔹 Upload to backend only when discovered in Banpur (by address match)
                if dev.reachability == .online,
                   let txt = dev.txtRecord,
                   let deviceId = txt["deviceId"],
                   !banpurUploadedDeviceIds.contains(deviceId) {

                    let currentAddress = LocationHelper.getCurrentAddress()?.lowercased() ?? ""
                    if currentAddress.contains("banpur") {
                        // Build a WifiDevice where id equals the TXT deviceId expected by backend
                        let w = wifiDevice(from: dev)
                        let upload = WifiDevice(
                            id: deviceId,
                            uuid: w.uuid,
                            chennalMac: w.chennalMac,
                            chennalCount: w.chennalCount,
                            channelTypes: w.channelTypes,
                            deviceName: w.deviceName,
                            isOnline: w.isOnline
                        )
                        print("⬆️ [Banpur] Uploading device to backend: \(upload)")
                        sendDeviceToBackend(device: upload)
                        banpurUploadedDeviceIds.insert(deviceId)
                    }
                }
            }

            // Devices not seen this tick remain, but flip to offline
            for (uuid, device) in knownWifiDevices {
                if !currentUUIDs.contains(uuid), device.isOnline {
                    var offlineCopy = device
                    offlineCopy.isOnline = false
                    knownWifiDevices[uuid] = offlineCopy
                }
            }

            // Project to array for UI
            let list = Array(knownWifiDevices.values)
                .sorted { $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending }
            self.wifiDevices = list

            let onlineCount = filtered.filter { dev in
                dev.reachability == .online
            }.count
//            print("Updated wifiDevices array with \(list.count) devices (source: \(newDevices.count), currently online: \(onlineCount))")
        }
        .onChange(of: bluetoothManager.isBluetoothOn) { _, on in
            if on {
                startBLEScan()
            } else {
                showBLEFoundCard = false
                pendingBLEDevice = nil
            }
        }
        // hello world
    }
    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.appTextMuted)

            Text("home.empty.title".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Text("home.empty.subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)

            LimiPrimaryButton(title: "home.empty.cta".localized, height: 48) {
                ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "modules"])
                showModulerView = true
            }
            .padding(.horizontal, 40)
        }
        .padding(24)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 20, strokeOpacity: 0.06, fillOpacity: 0.04)
        .padding(.horizontal, 16)
    }

    // MARK: - Modules Grid

    private var modulesGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            let addedModules = modulesManager.getAddedModules()
            ForEach(addedModules) { module in
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(module.icon)
                                .renderingMode(.template)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.orbGlow4)
                            Spacer()
                        }
                        Spacer()
                        Text(module.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.appTextPrimary)

                        HStack {
                            Text("settings.title".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                            Spacer()
                            Button(action: {
                                selectedModuleForAction = module
                                showModuleActionMenu = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appTextMuted)
                            }
                        }
                    }
                    .frame(minHeight: 110)
                    .padding(14)
                    .glassCard(cornerRadius: 16, fillOpacity: 0.05)
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
                            selectedModuleForAction = module
                            showModuleActionMenu = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.appDanger)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
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
//                        .foregroundColor(Color.themeWhite)
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
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.themeWhite)

                Text("Tap to chat")
                    .font(.system(size: 15))
                    .foregroundColor(Color.themeWhite.opacity(0.65))
//                OrbView(intensity: $orbIntensity, currentVolume: $orbVolume)
//                    .frame(width: 160, height: 160)

                Image("Vector-2")
                    .scaledToFit()
                    .onTapGesture {
                        ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "voice_chat"])
                        showVoiceView = true
                    }

            }
        }
        .frame(width: 260, height: 260)
        .contentShape(Circle())
    }
    // MARK: - Mapper: BLEDevice -> WifiDevice respecting Bonjour reachability
    private func wifiDevice(from dev: BLEDevice) -> WifiDevice {
        var channelCount = 1
        var channelTypes: [String] = ["CCT"]  // Default to CCT if not specified
        var mac = dev.uuid
        if let txt = dev.txtRecord {
            if let s = txt["channelCount"], let c = Int(s) { channelCount = c }
            // Parse channelTypes from TXT (firmware sends as 'channelTypes')
            if let p = txt["channelTypes"] {
                let types = p.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).uppercased() }
                if !types.isEmpty {
                    channelTypes = types
                }
            }
            if let m = txt["deviceId"] { mac = m }
        }
        return WifiDevice(
            id: dev.uuid,
            uuid: dev.uuid,
            chennalMac: mac,
            chennalCount: channelCount,
            channelTypes: channelTypes,
            deviceName: dev.name,
            isOnline: (dev.reachability == .online) // <- the important bit
        )
    }

    func sendDeviceToBackend(device: WifiDevice) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 [sendDeviceToBackend] STARTED")

        guard let token = AuthManager.shared.getToken(), !token.isEmpty else {
            print("⚠️ [sendDeviceToBackend] No token found. Cannot send device.")
            return
        }

        guard let url = URL(string: APIConstants.deviceUser) else {
            print("❌ [sendDeviceToBackend] Invalid URL: \(APIConstants.deviceUser)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        print("🔗 [sendDeviceToBackend] URL: \(url.absoluteString)")
        print("📋 [sendDeviceToBackend] Method: POST")
        print("🔑 [sendDeviceToBackend] Authorization: \(String(token.prefix(30)))...")
        print("📎 [sendDeviceToBackend] Content-Type: application/json")

        let body: [String: Any] = [
            "deviceId": device.chennalMac,
            "metadata":["uuid": device.uuid,
            "chennalMac": device.chennalMac,
            "chennalCount": device.chennalCount,
            "channelTypes": device.channelTypes,
            "deviceName": device.deviceName,
            "isOnline": device.isOnline]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = data
            if let json = String(data: data, encoding: .utf8) {
                print("📤 [sendDeviceToBackend] Body:\n\(json)")
            }
            print("📏 [sendDeviceToBackend] Body size: \(data.count) bytes")
        } catch {
            print("❌ [sendDeviceToBackend] Failed to encode body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [sendDeviceToBackend] Network error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📬 [sendDeviceToBackend] HTTP Status: \(http.statusCode)")
                print("📬 [sendDeviceToBackend] Response Headers: \(http.allHeaderFields)")
            }

            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📩 [sendDeviceToBackend] Response Body: \(body)")
            } else {
                print("📩 [sendDeviceToBackend] Response Body: (empty)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }.resume()
    }

    // MARK: - Module Navigation Handler
    private func handleModuleTap(_ module: Module) {
        switch module.id {
        case 1:
            ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "devices"])
            showConnectedDevices = true
        case 2:
            ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "configurator"])
            showConfigurator = true
        case 3:
            ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "ar_portal"])
            showARView = true
        case 4:
            ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": "room_scan"])
            showRoomScan = true
        default:
            break
        }
    }

    private func clearHomeSheetFlowMarker() {
        ContextManager.shared.updateContext(screen: "HomeView", metadata: ["sheet_flow": ""])
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

// MARK: - Device Allocation API Models + Service

struct DeviceAllocationData: Decodable {
    let allocationId: String?
    let message: String?
    let success: Bool?
}

struct DeviceAllocationResponse: Decodable {
    let success: Bool
    let message: String
    let data: DeviceAllocationData?
}

final class DeviceAllocationService {
    static let shared = DeviceAllocationService()
    private init() {}

    private let endpoint = URL(string: APIConstants.deviceUser)!

    func allocateDevice(deviceId: String) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 [DeviceAllocation] STARTED for deviceId: \(deviceId)")

        guard let token = AuthManager.shared.getToken(), !token.isEmpty else {
            print("❌ [DeviceAllocation] No valid token. Cannot allocate device.")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        print("🔗 [DeviceAllocation] URL: \(endpoint.absoluteString)")
        print("📋 [DeviceAllocation] Method: POST")
        print("🔑 [DeviceAllocation] Authorization: \(String(token.prefix(30)))...")
        print("📎 [DeviceAllocation] Content-Type: application/json")

        let body: [String: String] = [
            "deviceId": deviceId
        ]

        do {
            let encoded = try JSONEncoder().encode(body)
            request.httpBody = encoded
            if let json = String(data: encoded, encoding: .utf8) {
                print("📤 [DeviceAllocation] Body: \(json)")
            }
            print("📏 [DeviceAllocation] Body size: \(encoded.count) bytes")
        } catch {
            print("❌ [DeviceAllocation] Failed to encode body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [DeviceAllocation] Network error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📬 [DeviceAllocation] HTTP Status: \(http.statusCode)")
                print("📬 [DeviceAllocation] Response Headers: \(http.allHeaderFields)")
            }

            guard let data = data else {
                print("❌ [DeviceAllocation] Empty response data")
                return
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("📩 [DeviceAllocation] Response Body: \(raw)")
            }

            do {
                let decoded = try JSONDecoder().decode(DeviceAllocationResponse.self, from: data)
                print("✅ [DeviceAllocation] success: \(decoded.success), message: \(decoded.message)")
                if let dataObj = decoded.data {
                    print("   ↳ allocationId: \(dataObj.allocationId ?? "nil")")
                    print("   ↳ inner message: \(dataObj.message ?? "nil")")
                    print("   ↳ inner success: \(dataObj.success.map { String($0) } ?? "nil")")
                }
            } catch {
                print("❌ [DeviceAllocation] Failed to decode JSON: \(error)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }.resume()
    }
}



// MARK: - Preview

