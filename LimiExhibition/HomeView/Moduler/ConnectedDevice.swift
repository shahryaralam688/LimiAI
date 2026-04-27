//
//  ConnectedDevice.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 21/11/2025.
//

import SwiftUI

// MARK: - WiFi Device Model (from HomeView)

struct ConnectedDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    let onBack: () -> Void = {}
    
    // MARK: - Bonjour Integration
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    private let allowedNames: Set<String> = ["1 CH-HUB", "Mini Controller","LIMI Device"]
    @State private var allocatedWifiDeviceIds: Set<String> = []
    @State private var banpurUploadedDeviceIds: Set<String> = []
    @State private var gridUploadedDeviceIds: Set<String> = []

    // MARK: - State Variables
    @State private var wifiDevices: [WifiDevice] = []
    @State private var knownWifiDevices: [String: WifiDevice] = [:]
    @State private var selectedWifiDevice: WifiDevice? = nil
    @State private var isShowingDevice: Bool = false
    @State private var showDemoAddingWifi: Bool = false
    @State private var selectedDeviceName: String = ""
    @State private var selectedDeviceId: String = ""
    @State private var selectedWifiSSID: [String] = []
    

    @State private var showHomeView: Bool = false
    @State private var showNoPendantAlert: Bool = false


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

    var body: some View {
        VStack(spacing: 0) {
            
            
            // MARK: - Header
            VStack {
                //
                ZStack {
                    Rectangle()
                        .fill(Color.appSurfaceSecondary)
                        .cornerRadius(32)
                        .frame(height: 124)
                    
                    HStack(alignment: .bottom, spacing: 16) {
                        // Back Button
                        LimiBackButton { dismiss() }
                        
                        // Title and Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Devices")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.themeWhite)
                            
                            Text("Control Your Device In Your space")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.appTextTertiary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .fill(Color.appSurfaceTertiary)
            )
            .padding(.horizontal, 0)
            
            
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
                                            isOnline: device.isOnline
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
                                            selectedWifiDevice = device
                                        }
                                    }
                                }
                                .padding()
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
        .ignoresSafeArea()
        .onAppear {
            UserDataManager.shared.refreshUserData()
            
            // Connect WebSocket for light controlling (token is attached in LightControllingSocket init)
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
            let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            
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
        
        .sheet(item: $selectedWifiDevice) { device in
            if device.chennalCount == 0 {
                Color.clear
                    .onAppear {
                        showNoPendantAlert = true
                    }
                    .alert("No pendant connected to this device", isPresented: $showNoPendantAlert) {
                        Button("OK") {
                            selectedWifiDevice = nil
                        }
                    }
            } else if device.chennalCount == 1 {
                // Single channel - show direct control view based on channel type
                let channelType = device.channelTypes.first ?? "CCT"
                let channelPosition = 1
                if channelType == "CCT" {
                    CCTLEDView(chennalMac: device.chennalMac, chennelPosition: channelPosition)
                } else {
                    WLEDView(chennalMac: device.chennalMac, chennelPosition: channelPosition)
                }
            } else if device.chennalCount > 1 {
                // Multi-channel - show advanced/configurator first, then channel selection
                MultiChannelAdvancedView(device: device)
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
        .fullScreenCover(isPresented: $showHomeView) {
            HomeView()
        }
        .fullScreenCover(isPresented: $isShowingDevice) {
            DemoScanDevicesView()
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
    // MARK: - Bonjour Device Update Logic
    private func updateWifiDevices(with newDevices: [BLEDevice]) {
        let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        
        // Filter only allowed device names or limi1ch- prefix
        let filtered = newDevices.filter { dev in
            let n = dev.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalizedAllowed.contains(n) || n.hasPrefix("limi1ch-")
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

        guard let token = AuthManager.shared.getToken(), !token.isEmpty else {
            print("⚠️ [ConnectedDevice] No token found. Cannot send device.")
            return
        }

        guard let url = URL(string: APIConstants.deviceUser) else {
            print("❌ [ConnectedDevice] Invalid URL: \(APIConstants.deviceUser)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        print("🔗 [ConnectedDevice] URL: \(url.absoluteString)")
        print("📋 [ConnectedDevice] Method: POST")
        print("🔑 [ConnectedDevice] Authorization: \(String(token.prefix(30)))...")
        print("📎 [ConnectedDevice] Content-Type: application/json")

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
                print("📤 [ConnectedDevice] Body:\n\(json)")
            }
            print("📏 [ConnectedDevice] Body size: \(data.count) bytes")
        } catch {
            print("❌ [ConnectedDevice] Failed to encode body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [ConnectedDevice] Network error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📬 [ConnectedDevice] HTTP Status: \(http.statusCode)")
                print("📬 [ConnectedDevice] Response Headers: \(http.allHeaderFields)")
            }

            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📩 [ConnectedDevice] Response Body: \(body)")
            } else {
                print("📩 [ConnectedDevice] Response Body: (empty)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }.resume()
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
        return normalizedAllowed.contains(normalized) || normalized.hasPrefix("limi1ch-")
    }

    let chennalMac: String
    let chennalCount : Int
    let channelTypes: [String]
    let deviceName: String
    let isOnline: Bool
    
    private var channelSummary: String {
        if channelTypes.isEmpty { return "Unknown" }
        if channelTypes.count == 1 {
            return channelTypes[0]
        }
        // Count CCT and RGB channels
        let cctCount = channelTypes.filter { $0 == "CCT" }.count
        let rgbCount = channelTypes.filter { $0 == "RGB" }.count
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
            }
            .padding(10)

            HStack {
                Text(deviceName)
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
