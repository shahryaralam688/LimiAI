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
    let chennalPosition: Int  // Channel position from TXT record
    let deviceName: String
    var isOnline: Bool
}

// MARK: - BLE scan helper (unchanged)
extension HomeView {
    private func startBLEScan() {
        bluetoothManager.startScanning { devices in
            let filtered = devices.filter { allowedNames.contains($0.name) && !bleAcceptedIds.contains($0.id) && !bleRejectedIds.contains($0.id) }
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

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Image("bg blur")
                            .scaledToFit()
                            .ignoresSafeArea()
                            .offset(y: -500)
                            .offset(x: -80)
                    )
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
                VStack{
//                    header
//                        .padding(.horizontal)
                    
                    WeatherWidgetView()

//
//                    if !modulesManager.getAddedModules().isEmpty {
//                        HStack{
//                            Text("Active Modules")
//                                .font(.system(size: 18, weight: .semibold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 16)
//                                .padding(.top, 24)
//                            Spacer()
//                        }
//                    }
                    
                    if modulesManager.getAddedModules().isEmpty {
                        VStack{
                            VStack(spacing: 16){
                                Text("home.empty.title".localized)
                                    .font(.custom("Poppins-Medium", size: 16))   // 500 weight = Medium
                                    .foregroundColor(Color(hex: "#C9C4BD"))      // matches #C9C4BD
                                    .multilineTextAlignment(.center)             // text-align: center
                                    .lineSpacing(16 * 0.4)                       // 140% line height
                                    .kerning(0)
                                
                                Text("home.empty.subtitle".localized)
                                    .font(.custom("Poppins-Regular", size: 14)) // weight 400 = Regular
                                    .foregroundColor(Color(hex: "#A19D98"))     // custom color
                                    .multilineTextAlignment(.center)            // text-align: center
                                    .lineSpacing(14 * 0.4)                      // line-height: 140% → +40% of font size
                                    .kerning(0)                                 // letter-spacing: 0px
                                
                                // Add devices Button
                                Button(action: {
                                    showModulerView = true
                                }) {
                                    HStack {
                                        
                                        Image(systemName: "plus")
                                            .font(.custom("Poppins-Medium", size: 14))
                                            .foregroundColor(Color.charlestonGreen)
                                            .lineSpacing(0) // line-height: 100% (no extra spacing)
                                            .kerning(0)     // letter-spacing: 0%
                                        Text("home.empty.cta".localized)
                                            .font(.custom("Poppins-Medium", size: 14))
                                            .foregroundColor(Color.charlestonGreen)
                                            .lineSpacing(0) // line-height: 100% (no extra spacing)
                                            .kerning(0)     // letter-spacing: 0%
                                        
                                    }
                                    .font(.system(size: 17, weight: .semibold))
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                    
                                }
                            }
                            .frame( height: 304)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#24262B"), Color(hex: "#24262B")]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                // Dashed border
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                                    )
                                    .foregroundColor(Color(hex: "#787572"))
                            )
                            .cornerRadius(8)
                            .opacity(1)
                        }
                        .padding(.top, 24)
                        .padding(.horizontal)
                        Spacer()
                        
                    } else {
                        // MARK: - Main Content
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                let addedModules = modulesManager.getAddedModules()
                                
                                if !addedModules.isEmpty {
                                    
                                    
                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(addedModules) { module in
                                            ZStack(alignment: .topLeading) {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    HStack {
                                                        Image(module.icon)
                                                            .font(.system(size: 20, weight: .semibold))
                                                            .foregroundColor(.emerald)
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                    Text(module.title)
                                                        .font(.custom("Poppins-Medium", size: 16))
                                                        .kerning(-0.15)
                                                        .lineSpacing(2) // 120% line-height ke close
                                                        .foregroundColor(.white)
                                                    
                                                    
                                                    
                                                    HStack {
                                                        Text("settings.title".localized)
                                                            .font(.custom("Poppins-Regular", size: 12))
                                                            .kerning(-0.15)
                                                            .lineSpacing(1.5) // ~120% line-height
                                                            .foregroundColor(.white)
                                                        
                                                        
                                                        Spacer()
                                                        Button(action: {
                                                            selectedModuleForAction = module
                                                            showModuleActionMenu = true
                                                        }) {
                                                            Image(systemName: "ellipsis")
                                                                .rotationEffect(.degrees(90))
                                                                .font(.system(size: 16, weight: .semibold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }
                                                    
                                                }
                                                .frame(minHeight: 120)
                                                .padding(12)
                                                .background(Color(hex: "#2A2D33"))
                                                .cornerRadius(12)
                                                .scaleEffect(isModuleEditMode ? 0.97 : 1.0)
                                                .rotationEffect(.degrees(isModuleEditMode ? -1.8 : 0))
                                                .animation(
                                                    isModuleEditMode ? .easeInOut(duration: 0.15).repeatForever(autoreverses: true) : .default,
                                                    value: isModuleEditMode
                                                )
                                                .onTapGesture {
                                                    if !isModuleEditMode {
                                                        handleModuleTap(module)
                                                    }
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
                                                                .fill(Color.white)
                                                                .frame(width: 22, height: 22)
                                                            Image(systemName: "xmark")
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundColor(.black)
                                                        }
                                                    }
                                                    .buttonStyle(.plain)
                                                    .offset(x: -6, y: -6)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.top, 24
                            )
                            .padding(.bottom, 40)
                        }
                    }
                    
                }
                if isModuleEditMode {
                VStack {
                    Spacer()
                    
                    let hasModules = !modulesManager.getAddedModules().isEmpty
                    if !modulesManager.getAddedModules().isEmpty {
                        
                        HStack{
                            Spacer()
                            Button(action: {
                                isModulesButtonAnimating = true
                                showModulerView = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isModulesButtonAnimating = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: hasModules ? "plus.circle" : "plus.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(hasModules ? "Add More Modules" : "Add Modules")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(hasModules ? Color(hex: "#1F1F1F") : .white)
                                .frame(width: 195)
                                .padding(.vertical, 14)
                                .background(
                                    hasModules ? AnyView(AnyView(Color.white)) : AnyView(Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white, lineWidth: hasModules ? 0 : 1.5)
                                )
                                .cornerRadius(24)
                            }
                            
                            .scaleEffect(isModulesButtonAnimating ? 0.95 : 1.0)
                            .shadow(color: hasModules ? Color.white.opacity(0.5) : Color.clear,
                                    radius: hasModules ? 16 : 0,
                                    x: 0,
                                    y: 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isModulesButtonAnimating)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                        }
                    }
                }
            }

                    if showBLEFoundCard, let device = pendingBLEDevice {
                        VStack {
                            VStack(spacing: 12) {
                                Text("Found New Device")
                                    .font(.custom("Poppins-SemiBold", size: 24))
                                    .foregroundColor(Color.alabaster)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(24 * 0.4)
                                    .tracking(-0.005 * 24)
                                
                                Text(device.name)
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundColor(Color.alabaster)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(hex:"#24262B").opacity(1))
                                    )
                                    .frame(width: .infinity, height: 24, alignment: .center)
                                    .opacity(1)
                                    .rotationEffect(.degrees(0))
                                
                                Text(device.id)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 16) {
                                    
                                    // ✅ Connect Button (Filled Green)
                                    Button(action: {
                                        if let dev = pendingBLEDevice {
                                            // Remember decision and dismiss card
                                            bleAcceptedIds.insert(dev.id)
                                            showBLEFoundCard = false
                                            pendingBLEDevice = nil
                                            
                                            // Persist selection and connect
                                            selectedDeviceName = dev.name
                                            selectedDeviceId = dev.id
                                            BluetoothManager.shared.selectAndConnect(name: dev.name, uuidString: dev.id)
                                            
                                            // Fetch Wi-Fi list (FB04) then present DemoAddingWifiView with first SSID
                                            BluetoothManager.shared.readWifiList { list in
                                                DispatchQueue.main.async {
                                                    self.selectedWifiSSID = list
                                                    self.showDemoAddingWifi = true
                                                }
                                            }
                                        }
                                    }) {
                                        Text("Connect")
                                            .font(.custom("Poppins-SemiBold", size: 16))
                                            .foregroundColor(Color.charlestonGreen)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.emerald)
                                            .cornerRadius(12)
                                    }
                                    
                                    // ❌ Not Now Button (Outlined)
                                    Button(action: {
                                        if let id = pendingBLEDevice?.id { bleRejectedIds.insert(id) }
                                        showBLEFoundCard = false
                                        pendingBLEDevice = nil
                                    }) {
                                        Text("Not Now")
                                            .font(.custom("Poppins-SemiBold", size: 16))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.emerald, lineWidth: 1.5)
                                            )
                                    }
                                }
                                .padding(.horizontal, 24)
                                
                            }
                            .padding(16)
                            .background(Color(hex: "#24262B"))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .zIndex(4)
                    }
                    
                    // MARK: - Module Action Menu Popup
                    if showModuleActionMenu, let module = selectedModuleForAction {
                        ZStack {
                            // Dark overlay background
                            Color.black.opacity(0.45)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    showModuleActionMenu = false
                                    isModuleEditMode = false
                                }
                            

                            // Popup menu
                            VStack(spacing: 0) {
                                VStack(spacing: 8) {
                                    Text(module.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .tracking(-0.3)

                                    Text("What would you like to do?")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(Color.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .tracking(-0.2)
                                }
                                .padding(.top, 18)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                                Divider()
                                    .background(Color.white.opacity(0.08))

                                // Delete Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        modulesManager.toggleModuleStatus(for: module.id)
                                    }
                                    showModuleActionMenu = false
                                    selectedModuleForAction = nil
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)

                                        Text("Unisntall")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 18)
                                }

                                Divider()
                                    .background(Color.white.opacity(0.08))

                                // Later Button
                                Button(action: {
                                    showModuleActionMenu = false
                                    selectedModuleForAction = nil
                                    isModuleEditMode = false
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)

                                        Text("Later")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 18)
                                }
                            }
                            .background(
                                Color(hex: "#24262B")
                                    .opacity(0.8)
                                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color(hex: "#5F5F5F"), lineWidth: 4) // ← 1-point border
                                    )
                            )
                            .cornerRadius(24)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 8)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showModuleActionMenu)
                        .zIndex(5)
                    }
                
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.setupInitialState()
                
            }
            .overlay(
                Group {
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
                    }
                },
                alignment: .bottom
            )

        }
        .frame(maxWidth: .infinity)
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
        .onDisappear {
            // ✅ Bonjour OFF (exact lifecycle)
            bonjourBrowser.stopBrowsing()
            bluetoothManager.stopScanning()
        }

        // ✅ Respect Bonjour reachability + keep offline ghosts listed
        .onReceive(bonjourBrowser.$discoveredWiFiDevices) { newDevices in
            let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

            // Only keep allowed device names
            let filtered = newDevices.filter { dev in
                let n = dev.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalizedAllowed.contains(n)
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
                            chennalPosition: w.chennalPosition,
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
//                    Color(hex: "#171717").cornerRadius(20)
//                    Image("bottom_profile_view")
//                        .renderingMode(.template)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 22, height: 22)
//                        .foregroundColor(Color(hex: "#FFFFFF"))
//
//                    Circle()
//                        .stroke(Color(hex: "#FFFFFF"), lineWidth: 1.4)
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
                .fill(Color.black)
                .frame(width: 260, height: 260)
                .shadow(color: Color.black.opacity(0.9), radius: 60, x: 0, y: 18)
                .overlay(
                    // INNER SHADOW (inset shadow equivalent)
                    Circle()
                        .stroke(Color(hex: "#fff").opacity(3), lineWidth: 3)
                        .blur(radius: 10)
                        .offset(x: -6, y: -1)
                        .mask(
                            Circle()
                                .fill(Color.black)
                        )
                )

            VStack(spacing: 12) {
                Text("Hey, Limi here!")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Tap to chat")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.65))
//                OrbView(intensity: $orbIntensity, currentVolume: $orbVolume)
//                    .frame(width: 160, height: 160)

                Image("Vector-2")
                    .scaledToFit()
                    .onTapGesture {
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
        var channelPosition = 1
        var mac = dev.uuid
        if let txt = dev.txtRecord {
            if let s = txt["channelCount"], let c = Int(s) { channelCount = c }
            if let p = txt["channelPosition"], let pos = Int(p) { channelPosition = pos }
            if let m = txt["deviceId"] { mac = m }
        }
        return WifiDevice(
            id: dev.uuid,
            uuid: dev.uuid,
            chennalMac: mac,
            chennalCount: channelCount,
            chennalPosition: channelPosition,
            deviceName: dev.name,
            isOnline: (dev.reachability == .online) // <- the important bit
        )
    }

    func sendDeviceToBackend(device: WifiDevice) {
        
        guard let token = AuthManager.shared.getToken(), !token.isEmpty else {
            print("⚠️ No token found. Cannot send device.")
            return
        }

        guard let url = URL(string: APIConstants.deviceUser) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            // Send the exact deviceId as advertised (Bonjour TXT), no case transformation
            "deviceId": device.chennalMac,
            "metadata":["uuid": device.uuid,
            "chennalMac": device.chennalMac,
            "chennalCount": device.chennalCount,
            "chennalPosition": device.chennalPosition,
            "deviceName": device.deviceName,
            "isOnline": device.isOnline]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = data
            if let json = String(data: data, encoding: .utf8) {
                print("📤 sendDeviceToBackend payload: \(json)")
            }
        } catch {
            print("❌ Failed to encode device body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request error:", error.localizedDescription)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("✅ HTTP Status:", httpResponse.statusCode)
            }

            if let data = data,
               let responseString = String(data: data, encoding: .utf8) {
                print("📩 Response:", responseString)
            }
        }.resume()
    }

    // MARK: - Module Navigation Handler
    private func handleModuleTap(_ module: Module) {
        switch module.id {
        case 1:
            showConnectedDevices = true
        case 2:
            showConfigurator = true
        case 3:
            showARView = true
        case 4:
            showRoomScan = true
        default:
            break
        }
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
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthManager.shared.getToken(), forHTTPHeaderField: "authorization")

        // Body
        let body: [String: String] = [
            "deviceId": deviceId
        ]

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            print("❌ [DeviceAllocation] Failed to encode body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [DeviceAllocation] Request error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("ℹ️ [DeviceAllocation] HTTP Status: \(http.statusCode)")
            }

            guard let data = data else {
                print("❌ [DeviceAllocation] Empty response data")
                return
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
                if let raw = String(data: data, encoding: .utf8) {
                    print("   Raw response: \(raw)")
                }
            }
        }.resume()
    }
}



// MARK: - Preview

