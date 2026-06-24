//
//  ConnectedDevice.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 21/11/2025.
//

import SwiftUI
import SwiftData

// MARK: - WiFi Device Model (from HomeView)

struct ConnectedDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onBack: () -> Void = {}
    
    // MARK: - Bonjour Integration
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    private let allowedNames: Set<String> = ["1 CH-HUB", "4 CH-HUB", "8 CH-HUB", "16 CH-HUB", "Mini Controller", "LIMI Device"]
    @State private var allocatedWifiDeviceIds: Set<String> = []
    @State private var banpurUploadedDeviceIds: Set<String> = []
    @State private var gridUploadedDeviceIds: Set<String> = []

    private func isAllowedDeviceName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return normalizedAllowed.contains(normalized)
            || normalized.hasPrefix("limi1ch-")
            || normalized.hasPrefix("limi device")
    }

    // MARK: - State Variables
    @State private var wifiDevices: [WifiDevice] = []
    @State private var knownWifiDevices: [String: WifiDevice] = [:]
    @State private var selectedWifiDevice: WifiDevice? = nil
    @State private var isShowingDevice: Bool = false
    @State private var showDemoAddingWifi: Bool = false
    @State private var showHomeView: Bool = false
    @State private var showNoPendantAlert: Bool = false
    @State private var renameTargetDevice: WifiDevice?
    @State private var renameInput: String = ""
    @State private var customDeviceNames: [String: String] = [:]

    /// Manual control-path override (MQTT / LAN WebSocket / BLE / Automatic). Persisted locally.
    @ObservedObject private var transportMediumPreference = TransportMediumPreferenceStore.shared

    // Grid layout
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private func deviceStorageKey(for device: WifiDevice) -> String {
        let trimmedMac = device.chennalMac.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMac.isEmpty ? device.uuid : trimmedMac
    }

    private func customName(for device: WifiDevice) -> String? {
        let key = deviceStorageKey(for: device)
        return customDeviceNames[key]
    }

    private func displayName(for device: WifiDevice) -> String {
        if let customName = customName(for: device),
           !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        return device.deviceName
    }

    private func beginRenaming(_ device: WifiDevice) {
        renameTargetDevice = device
        renameInput = customName(for: device) ?? device.deviceName
    }

    private func saveCustomDeviceName() {
        guard let device = renameTargetDevice else { return }

        let key = deviceStorageKey(for: device)
        let trimmedName = renameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<DeviceNamePreference>(
            predicate: #Predicate { $0.deviceID == key }
        )

        do {
            let storedPreference = try modelContext.fetch(descriptor).first

            if trimmedName.isEmpty || trimmedName == device.deviceName {
                if let storedPreference {
                    modelContext.delete(storedPreference)
                }
            } else if let storedPreference {
                storedPreference.customName = trimmedName
            } else {
                modelContext.insert(DeviceNamePreference(deviceID: key, customName: trimmedName))
            }

            try modelContext.save()
            loadSavedDeviceNames()
        } catch {
            print("❌ Failed to save local device name: \(error.localizedDescription)")
        }
    }

    private func loadSavedDeviceNames() {
        let descriptor = FetchDescriptor<DeviceNamePreference>()

        do {
            let storedPreferences = try modelContext.fetch(descriptor)
            customDeviceNames = Dictionary(
                uniqueKeysWithValues: storedPreferences.map { ($0.deviceID, $0.customName) }
            )
        } catch {
            print("❌ Failed to load local device names: \(error.localizedDescription)")
        }
    }

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Control your devices in your space")
            
            VStack(spacing: 0) {
                VStack{
                    HStack{
                        Text("Connected Space")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.themeWhite)
                            .multilineTextAlignment(.center)
                            .lineSpacing(18 * 0.2)
                            .tracking(-0.15 / 18)
                        Spacer()
                    }
                    .padding(.top)

                    controlMediumPickerRow

                    let role = AuthManager.shared.getRole()
                    if role == "Installer User created" {
                        Text("Please log in to view your Wi-Fi devices.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        if wifiDevices.isEmpty {
                            VStack {
                                VStack(spacing: 16) {
                                    Text("You haven’t added any devices yet")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.appTextSecondary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(16 * 0.4)
                                        .kerning(0)
                                    
                                    Text("Tap the button below to add devices")
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .foregroundColor(Color.appTextMuted)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(14 * 0.4)
                                        .kerning(0)
                                    
                                    LimiPrimaryButton(title: "Add Your First Device") {
                                        isShowingDevice = true
                                    }
                                }
                                .frame(height: 304)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.appSurfacePrimary, Color.appSurfacePrimary]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .foregroundColor(Color.appBorderSecondary)
                                )
                                .cornerRadius(8)
                                .opacity(1)
                            }
                        } else {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(wifiDevices) { device in
                                        WifiDeviceSpace(
                                            chennalMac: device.chennalMac,
                                            chennalCount: device.chennalCount,
                                            channelTypes: device.channelTypes,
                                            deviceName: device.deviceName,
                                            displayName: displayName(for: device),
                                            isOnline: device.isOnline,
                                            onRename: {
                                                beginRenaming(device)
                                            }
                                        )
                                        .onAppear {
                                            // Send each real device shown in the grid to backend once
                                            if !gridUploadedDeviceIds.contains(device.chennalMac) {
                                                gridUploadedDeviceIds.insert(device.chennalMac)
                                                sendDeviceToBackend(device: device)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            guard renameTargetDevice == nil else { return }
                                            selectedWifiDevice = device
                                        }
                                    }
                                }
                                .padding()
                                .limiFloatingOrbClearance()
                            }
                            HStack{
                                Spacer()
                                WifiFloatingButton()
                                    .padding(.bottom, 20)
                            }
                        }
                    }
                }.zIndex(1)
                    .padding(.horizontal, 16)
                Spacer()
            }
            
        }
        .background(Color.appCanvasPrimary)
        .onAppear {
            UserDataManager.shared.refreshUserData()
            loadSavedDeviceNames()
            
            // Connect WebSocket for light controlling (auth refreshed on connect + session changes)
            LightControllingSocket.shared.connect()
            
            // Debug: log all socket events so we can see exact event names and payloads
            LightControllingSocket.shared.listenForAllEvents()
            
            // Start Bonjour browsing
            bonjourBrowser.startBrowsing()
        }
        .onDisappear {
            // Stop Bonjour browsing
            bonjourBrowser.stopBrowsing()
            
            // Disconnect WebSocket when leaving devices screen
            LightControllingSocket.shared.disconnect()
        }
        // ✅ Respect Bonjour reachability + keep offline ghosts listed
        .onReceive(bonjourBrowser.$discoveredWiFiDevices) { newDevices in
            let filtered = newDevices.filter { dev in
                isAllowedDeviceName(dev.name)
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
        
        .sheet(item: $selectedWifiDevice) { device in
            if device.chennalCount > 1 {
                MultiChannelAdvancedView(device: device)
                    .id("multi-\(device.chennalMac)")
                    .deviceControlSheetStyle()
            } else {
                let channelLabel = device.channelTypes.first?.uppercased() == "RGB" ? "RGB Control" : "CCT Control"
                DeviceControlNavigationShell(
                    title: displayName(for: device),
                    subtitle: channelLabel,
                    onClose: { selectedWifiDevice = nil }
                ) {
                    connectedDeviceSheetInner(device: device)
                }
            }
        }
        .fullScreenCover(isPresented: $showHomeView) {
            HomeView()
        }
        .fullScreenCover(isPresented: $isShowingDevice) {
            AddDeviceCoordinator.destination(for: .deviceScan)
        }
        .alert(
            "Rename Device",
            isPresented: Binding(
                get: { renameTargetDevice != nil },
                set: { isPresented in
                    if !isPresented {
                        renameTargetDevice = nil
                    }
                }
            )
        ) {
            TextField("Device name", text: $renameInput)
            Button("Save") {
                saveCustomDeviceName()
                renameTargetDevice = nil
            }
            Button("Reset") {
                renameInput = ""
                saveCustomDeviceName()
                renameTargetDevice = nil
            }
            Button("Cancel", role: .cancel) {
                renameTargetDevice = nil
            }
        } message: {
            Text("This name will be saved only on this mobile.")
        }
        .limiModalNavigationBar(title: "Devices", onClose: {
            onBack()
            dismiss()
        })
        }
    }

    private var controlMediumPickerRow: some View {
        ControlPathPickerCard(store: transportMediumPreference)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func connectedDeviceSheetInner(device: WifiDevice) -> some View {
        if device.chennalCount == 1 {
            singleChannelControlView(for: device)
        } else {
            Color.clear
                .onAppear {
                    showNoPendantAlert = true
                }
                .alert("No pendant connected to this device", isPresented: $showNoPendantAlert) {
                    Button("OK") {
                        selectedWifiDevice = nil
                    }
                }
        }
    }

    @ViewBuilder
    private func singleChannelControlView(for device: WifiDevice) -> some View {
        let normalizedChannelType = device.channelTypes.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let channelType = normalizedChannelType == "RGB" ? "RGB" : "CCT"
        let channelPosition = 1
        if channelType == "CCT" {
            CCTLEDView(chennalMac: device.chennalMac, chennelPosition: channelPosition)
                .id("cct-\(device.chennalMac)-\(channelPosition)")
        } else {
            WLEDView(chennalMac: device.chennalMac, chennelPosition: channelPosition)
                .id("rgb-\(device.chennalMac)-\(channelPosition)")
        }
    }

    private func wifiDevice(from dev: BLEDevice) -> WifiDevice {
        var channelCount = 1
        var channelTypes: [String] = ["CCT"]  // Default to CCT if not specified
        var mac = dev.uuid
        if let txt = dev.txtRecord {
            if let s = txt["channelCount"], let c = Int(s) { channelCount = c }
            // Parse channelTypes from TXT (firmware sends as 'channelTypes')
            if let p = txt["channelTypes"] {
                let types = p
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                    .filter { $0 == "CCT" || $0 == "RGB" }
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
    // MARK: - Bonjour Device Update Logic
    private func updateWifiDevices(with newDevices: [BLEDevice]) {
        // Filter only allowed device names or expected prefixes
        let filtered = newDevices.filter { dev in
            isAllowedDeviceName(dev.name)
        }
        
        // Track current UUIDs
        let currentUUIDs = Set(filtered.map { $0.uuid })
        
        // Update/insert seen devices
        for dev in filtered {
            knownWifiDevices[dev.uuid] = wifiDevice(from: dev)
        }
        
        // Mark offline devices that are no longer seen
        for (uuid, device) in knownWifiDevices {
            if !currentUUIDs.contains(uuid), device.isOnline {
                var offlineCopy = device
                offlineCopy.isOnline = false
                knownWifiDevices[uuid] = offlineCopy
            }
        }
        
        // Update UI array
        let list = Array(knownWifiDevices.values)
            .sorted { $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending }
        self.wifiDevices = list
        
        print("✅ Updated \(list.count) connected devices")
    }
    

    func sendDeviceToBackend(device: WifiDevice) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 [ConnectedDevice] sendDeviceToBackend STARTED")

        let body: [String: Any] = [
            "deviceId": device.chennalMac,
            "metadata": [
                "uuid": device.uuid,
                "chennalMac": device.chennalMac,
                "chennalCount": device.chennalCount,
                "channelTypes": device.channelTypes,
                "deviceName": device.deviceName,
                "isOnline": device.isOnline
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            print("📤 [ConnectedDevice] Body:\n\(json)")
        }

        LimiDeviceAPI.postDeviceUser(body: body, logPrefix: "ConnectedDevice") { _, _, _ in
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }

}
struct WifiDeviceSpace: View {
    @State private var isOn = false
    @StateObject private var socket = LightControllingSocket.shared
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    private let allowedNames: Set<String> = ["1 CH-HUB", "4 CH-HUB","8 CH-HUB", "16 CH-HUB", "Mini Controller","LIMI Device"]
    
    private func isAllowedDeviceName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return normalizedAllowed.contains(normalized)
            || normalized.hasPrefix("limi1ch-")
            || normalized.hasPrefix("limi device")
    }

    let chennalMac: String
    let chennalCount : Int
    let channelTypes: [String]
    let deviceName: String
    let displayName: String
    let isOnline: Bool
    let onRename: () -> Void
    
    private var channelSummary: String {
        let normalizedTypes = channelTypes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { $0 == "CCT" || $0 == "RGB" }

        if normalizedTypes.isEmpty { return "CCT" }
        if normalizedTypes.count == 1 {
            return normalizedTypes[0]
        }
        // Count CCT and RGB channels
        let cctCount = normalizedTypes.filter { $0 == "CCT" }.count
        let rgbCount = normalizedTypes.filter { $0 == "RGB" }.count
        if cctCount > 0 && rgbCount > 0 {
            return "\(cctCount) CCT + \(rgbCount) RGB"
        } else if cctCount > 0 {
            return "\(cctCount) CCT"
        } else if rgbCount > 0 {
            return "\(rgbCount) RGB"
        }
        return "Mixed"
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.themeWhite)
                Spacer()
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.themeWhite)
                        .frame(width: 28, height: 28)
                        .background(Color.themeBlack.opacity(0.25))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(10)

            HStack {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(10)

            HStack {
                Text(channelSummary)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appTextPrimary)

                Spacer()
                Circle()
                    .fill(isOnline ? Color.emerald : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isOnline ? "Online" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(isOnline ? .green : .gray)

            }
            .padding(.horizontal, 10)
        }
        .frame(height: 165.5)
        .background(Color.appSurfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.themeBlack.opacity(0.1), radius: 5, x: 0, y: 2)
        .opacity(isOnline ? 1.0 : 0.7)
        .onAppear { logResolvedDevice() }
        .onReceive(bonjourBrowser.$discoveredWiFiDevices) { _ in
            logResolvedDevice()
        }
    }

    private func logResolvedDevice() {
        guard isAllowedDeviceName(deviceName) else { return }
        if let dev = bonjourBrowser.discoveredWiFiDevices.first(where: { $0.name == deviceName }) {
            print("Resolved Bonjour service: \(dev.name)")
            let ip = dev.ipAddress ?? "unknown"
            print("Service \(dev.name) resolved to IP: \(ip)")
            if let txt = dev.txtRecord, !txt.isEmpty {
                print("TXT Record for \(dev.name):")
                for key in txt.keys.sorted() {
                    if let value = txt[key] {
                        print("  \(key): \(value)")
                    }
                }
            }
        }
    }
}

#Preview {
    ConnectedDevicesView()
}
