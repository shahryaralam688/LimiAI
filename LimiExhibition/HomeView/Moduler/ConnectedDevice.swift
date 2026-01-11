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
    @Environment(\.presentationMode) var presentationMode

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
                        .fill(Color(hex: "#2A2C33"))
                        .cornerRadius(32)
                        .frame(height: 124)
                    
                    HStack(alignment: .bottom, spacing: 16) {
                        // Back Button
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image("Solid arrow right sm")
                                .foregroundColor(.alabaster)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Title and Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Devices")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Control Your Device In Your space")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "#B6BAC2"))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                }
                //
//                HStack {
//                    Button(action: {
//                        showHomeView = true
//                    }) {
//                        Image("Solid arrow right sm")
//                            .foregroundColor(.alabaster)
//                            .font(.system(size: 18, weight: .medium))
//                            .frame(width: 44, height: 44)
//                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                    
//                    Text("Devices")
//                        .font(.system(size: 28, weight: .semibold))
//                        .foregroundColor(.white)
//                    
//                    Spacer()
//                }
//                .padding(.top, 55)
//                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .fill(Color(hex: "#393C43"))
            )
            .padding(.horizontal, 0)
            
            
            VStack(spacing: 0) {
                VStack{
                    HStack{
                        Text("Connected Space")
                            .font(.custom("Poppins-Medium", size: 18))
                            .foregroundColor(.white)
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
                                        .font(.custom("Poppins-Medium", size: 16))
                                        .foregroundColor(Color(hex: "#C9C4BD"))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(16 * 0.4)
                                        .kerning(0)
                                    
                                    Text("Tap the button below to add devices")
                                        .font(.custom("Poppins-Regular", size: 14))
                                        .foregroundColor(Color(hex: "#A19D98"))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(14 * 0.4)
                                        .kerning(0)
                                    
                                    Button(action: {
                                        isShowingDevice = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus")
                                                .font(.custom("Poppins-Medium", size: 14))
                                                .foregroundColor(Color.black)
                                            Text("Add Your First Device")
                                                .font(.custom("Poppins-Medium", size: 14))
                                                .foregroundColor(Color.black)
                                        }
                                        .font(.system(size: 17, weight: .semibold))
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 20)
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .cornerRadius(12)
                                    }
                                }
                                .frame(height: 304)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "#24262B"), Color(hex: "#24262B")]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .foregroundColor(Color(hex: "#787572"))
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
        .background(Color.black)
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
            if !(device.chennalCount == 0) {
                if device.chennalCount == 1 {
                    CCTLEDView(chennalMac: device.chennalMac)
                } else {
                    WLEDView(chennalMac: device.chennalMac)
                }
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
        var mac = dev.uuid
        if let txt = dev.txtRecord {
            if let s = txt["channelCount"], let c = Int(s) { channelCount = c }
            if let m = txt["deviceId"] { mac = m }
        }
        return WifiDevice(
            id: dev.uuid,
            uuid: dev.uuid,
            chennalMac: mac,
            chennalCount: channelCount,
            deviceName: dev.name,
            isOnline: (dev.reachability == .online) // <- the important bit
        )
    }
    // MARK: - Bonjour Device Update Logic
    private func updateWifiDevices(with newDevices: [BLEDevice]) {
        let normalizedAllowed = Set(allowedNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        
        // Filter only allowed device names
        let filtered = newDevices.filter { dev in
            let n = dev.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalizedAllowed.contains(n)
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

}
#Preview {
    ConnectedDevicesView()
}
