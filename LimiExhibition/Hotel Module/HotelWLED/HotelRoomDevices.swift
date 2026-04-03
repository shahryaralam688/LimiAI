//
//  HotelRoomDevices.swift
//  Limi
//
//  Created by Mac Mini on 02/10/2025.
//

import SwiftUI
import SwiftUI
import UIKit

// Helper shape to round specific corners

struct DeviceItem {
    let id = UUID()
    let icon: String
    let title: String
    let deviceCount: Int
    var isOn: Bool
}

struct HotelRoomDevices: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Top Tab Bar
            HStack(spacing: 0) {
                // BLE Devices Tab
                Button(action: {
                    selectedTab = 0
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .medium))
                        Text("BLE Devices")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(selectedTab == 0 ? .emerald : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.emerald.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.emerald : Color.clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Wi-Fi Devices Tab
                Button(action: {
                    selectedTab = 1
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.system(size: 16, weight: .medium))
                        Text("Wi-Fi Devices")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(selectedTab == 1 ? .emerald : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.emerald.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.emerald : Color.clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 56 )
            .background(Color(hex: "#393C43"))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1),
                alignment: .bottom
            )
            .clipShape(RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight]))
            
            // Content View
            Group {
                if selectedTab == 0 {
                    BLEDevicesView()
                } else {
                    WiFiDevicesView()
                }
            }
            .padding(.top, 26)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .ignoresSafeArea()
//        .padding(.top, 36)
        .background(Color.black.ignoresSafeArea())
    }
}


// MARK: - BLE Devices View
import SwiftUI

struct BLEDevicesView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @ObservedObject private var sharedDevice = SharedDevice.shared

    @State private var didStartBLE = false
    @State private var showWLEDView = false
    @State private var showWLEDViewScan = false
    @State private var showPWMView = false
    @State private var showDataRGB = false
    @State private var showMiniController = false
    @State private var selectedHub: Hub? = nil
    // MiniController requires brightness and warm/cold bindings
    @State private var miniBrightness: Double = 50
    @State private var miniWarmCold: Double = 50

    // Map live connected devices to your card model
    private var connectedDeviceItems: [DeviceItem] {
        bluetoothManager.connectedDevices
            .compactMap { (uuid, entry) in
                let title = entry.peripheral.name ?? "Unnamed Device"
                return DeviceItem(
                    icon: "antenna.radiowaves.left.and.right",
                    title: title,
                    deviceCount: 1,
                    isOn: false
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    // Handle device card tap
    private func handleDeviceCardTap(for item: DeviceItem) {
        // Find the matching connected device
        let matchingDevice = bluetoothManager.connectedDevices.first { (uuid, deviceEntry) in
            let deviceName = deviceEntry.peripheral.name ?? "Unnamed Device"
            return deviceName == item.title
        }
        
        guard let match = matchingDevice else {
            print("❌ No matching connected device found for: \(item.title)")
            return
        }
        
        // Mark as current device for rest of app
        SharedDevice.shared.connectedDevice = DeviceInfo(
            name: item.title,
            id: match.key.uuidString
        )
        
        // Handle routing based on device byte data
        handleDeviceSelection(for: match.key)
    }
    
    // Handle device selection based on raw byte data
    private func handleDeviceSelection(for deviceUUID: UUID) {
        guard let deviceEntry = bluetoothManager.connectedDevices[deviceUUID] else {
            print("❌ Device not found in connected devices")
            return
        }
        // Build Hub model for downstream views
        selectedHub = Hub(peripheral: deviceEntry.peripheral)
        
        // Check if we have received raw byte data from SharedDevice
        let rawBytes = SharedDevice.shared.lastReceivedBytes
        
        if !rawBytes.isEmpty, let firstByte = rawBytes.first {
            print("📥 Device byte data: [\(firstByte)]")
            
            switch firstByte {
            case 1:
                print("🔀 Routing to PWM2LEDView")
                showPWMView = true
            case 2:
                print("🔀 Routing to DataRGB")
                showDataRGB = true
            case 3:
                print("🔀 Routing to MiniController")
                showMiniController = true
            default:
                print("🔀 Unknown byte value [\(firstByte)], defaulting to WLEDView")
                showWLEDView = true
            }
        } else {
            print("⚠️ No raw byte data available, defaulting to WLEDView")
            showWLEDView = true
        }
    }

    // Auto-route when FF02 bytes arrive (open correct view immediately)
    private func autoRouteOnBytes(_ bytes: [UInt8]) {
        guard let first = bytes.first else { return }
        // Resolve current hub from SharedDevice preferred device or fall back to any connected
        if let current = SharedDevice.shared.connectedDevice, let uuid = UUID(uuidString: current.id), let entry = bluetoothManager.connectedDevices[uuid] {
            selectedHub = Hub(peripheral: entry.peripheral)
        } else if let any = bluetoothManager.connectedDevices.first {
            selectedHub = Hub(peripheral: any.value.peripheral)
        }
        // Dismiss all first to avoid multiple sheets
        showWLEDView = false
        showPWMView = false
        showDataRGB = false
        showMiniController = false
        // Route
        switch first {
        case 1:
            print("🔀 Auto-route to PWM2LEDView (byte 1)")
            showPWMView = true
        case 2:
            print("🔀 Auto-route to DataRGB (byte 2)")
            showDataRGB = true
        case 3:
            print("🔀 Auto-route to MiniController (byte 3)")
            showMiniController = true
        default:
            print("ℹ️ Byte \(first) not mapped — no auto route")
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Title
                HStack {
                    Text("BLE Devices")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.alabaster)

                    Spacer()

                    Button("WLED") {
                        showWLEDViewScan = true
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#393C43"))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Content
                if bluetoothManager.connectedDevices.isEmpty {
                    // Empty state
                    VStack(spacing: 10) {
                        Image(systemName: "bolt.horizontal.circle")
                            .font(.system(size: 52))
                            .foregroundColor(.white.opacity(0.6))
                        Text(bluetoothManager.isBluetoothOn
                             ? "No devices connected through Bluetooth"
                             : "Bluetooth is Off")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Connected devices grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15)
                        ], spacing: 20) {
                            ForEach(connectedDeviceItems.indices, id: \.self) { index in
                                let item = connectedDeviceItems[index]
                                DeviceCard(
                                    device: item,
                                    onToggle: { _ in /* hook to BLE command if needed */ },
                                    onTap: {
                                        self.handleDeviceCardTap(for: item)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)

                        Spacer(minLength: 100)
                    }
                    .padding(6)
                }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showWLEDView) {
        //    WLEDView()
        }
        .sheet(isPresented: $showWLEDViewScan) { WLEDDiscoveryView() }
        .sheet(isPresented: $showPWMView) {
            if let hub = selectedHub {
                PWM2LEDView(hub: hub)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showDataRGB) {
            if let hub = selectedHub {
                DataRGBView(hub: hub)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showMiniController) {
            if let hub = selectedHub {
                MiniControllerView(hub: hub, brightness: $miniBrightness, warmCold: $miniWarmCold)
            } else {
                EmptyView()
            }
        }

        // 🔎 Your auto-scan/auto-connect block (unchanged logic)
        .onChange(of: bluetoothManager.isBluetoothOn) { _, isOn in
            if isOn && !didStartBLE {
                didStartBLE = true
                bluetoothManager.startScanning { devices in
                    if let found = devices.first(where: { $0.name == "1 CH-HUB" }) {
                        print("🔍 Found newHub, attempting to connect...")
                        bluetoothManager.connectToDevice(deviceId: found.id)

                        // Give it a moment, then send a message if connected
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if bluetoothManager.isConnected {
                                bluetoothManager.BLESend(message: "Connected device")
                            }
                        }
                        bluetoothManager.stopScanning()
                    }
                }
            }
        }

        // 🖨️ Console confirmation when a connection appears
        .onChange(of: bluetoothManager.connectedDevices.count) { _, _ in
            // When count increases, print each connected device once
            for (uuid, entry) in bluetoothManager.connectedDevices {
                let name = entry.peripheral.name ?? "Unnamed Device"
                print("🎉 Successfully connected: \(name) (\(uuid.uuidString))")
            }
        }
        // Auto open corresponding view when FF02 bytes update (DISABLED per requested flow)
        // We only save bytes and open on DeviceCard tap now.
        // .onReceive(sharedDevice.$lastReceivedBytes) { bytes in
        //     guard !bytes.isEmpty else { return }
        //     print("📥 FF02 observed in BLEDevicesView: \(bytes)")
        //     autoRouteOnBytes(bytes)
        // }
        // Keep view active until disconnect: when connectedDevice becomes nil, dismiss all
//        .onReceive(sharedDevice.$connectedDevice) { device in
//            if device == nil {
//                print("🔌 Device disconnected — dismissing active controller view")
//                showWLEDView = false
//                showPWMView = false
//                showDataRGB = false
//                showMiniController = false
//                selectedHub = nil
//            }
//        }
    }
}


// MARK: - Wi-Fi Devices View
struct WiFiDevicesView: View {
    @State private var devices = [
        DeviceItem(icon: "lightbulb", title: "Smart Lamp", deviceCount: 3, isOn: true),
        DeviceItem(icon: "tv", title: "Smart TV", deviceCount: 1, isOn: false),
        DeviceItem(icon: "speaker.wave.2", title: "Smart Speaker", deviceCount: 2, isOn: true)
    ]
    @State private var showWLEDView = false
    @State private var showWLEDViewScan = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Title
                HStack {
                    Text("Wi-Fi Devices")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.alabaster)
                    Spacer()
                    Button("WLED"){
                        showWLEDViewScan = true
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#393C43"))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Device Cards Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15)
                        ], spacing: 20) {
                            ForEach(devices.indices, id: \.self) { index in
                                DeviceCard(
                                    device: devices[index],
                                    onToggle: { isOn in
                                        devices[index].isOn = isOn
                                    },
                                    onTap: {
                                        showWLEDView = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showWLEDView) {
//            WLEDView()
        }
        .sheet(isPresented: $showWLEDViewScan) {
            WLEDDiscoveryView()
        }
    }
}

struct DeviceCard: View {
    let device: DeviceItem
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    @State private var isOn: Bool
    
    init(device: DeviceItem, onToggle: @escaping (Bool) -> Void, onTap: @escaping () -> Void = {}) {
        self.device = device
        self.onToggle = onToggle
        self.onTap = onTap
        self._isOn = State(initialValue: device.isOn)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.charlestonGreen)
                            .frame(width: 45, height: 45)
                        
                        Image(systemName: device.icon)
                            .font(.title2)
                            .foregroundColor(.alabaster)
                    }
                    Spacer()
                }
                
                // Title and device count
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.title)
                        .font(.custom("Lexend", size: 17))
                        .fontWeight(.semibold)
                        .kerning(0)
                        .foregroundColor(.alabaster)
                        .lineLimit(nil)            // limit to 2 lines max
                        .frame(maxHeight: 44, alignment: .top) // fixed height for consistency

                    Text("\(device.deviceCount) devices")
                        .font(.custom("Lexend", size: 13))  // font-family + font-size
                        .fontWeight(.regular)               // font-weight: 400 (Regular)
                        .lineSpacing(0)                     // adjust line spacing
                        .kerning(0)
                        .foregroundColor(.alabaster.opacity(0.61234))
                }
                
                Spacer()
                
                // Status and Toggle
                HStack {
                    Text(isOn ? "On" : "Off")
                        .font(.custom("Inter", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.alabaster)
                    
                    Spacer()
                    
                    // Custom Toggle Switch
                    Button(action: {
                        isOn.toggle()
                        onToggle(isOn)
                    }) {
                        ZStack {
                            // Background
                            Rectangle()
                                .fill(isOn ? Color.emerald : Color(hex: "292929"))
                                .frame(width: 50, height: 26)
                                .cornerRadius(100)
                            
                            // Inner dot
                            Circle()
                                .fill(Color.alabaster)
                                .frame(width: 20, height: 20)
                                .offset(x: isOn ? 12 : -12, y: 0)
                                .animation(.easeInOut(duration: 0.2), value: isOn)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onTapGesture {
                        // Prevent the card tap when toggle is pressed
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#393C43"))
            )
            .frame(width:163.5, height: 207)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Color extension for hex colors

#Preview {
    HotelRoomDevices()
}

// struct HotelRoomDevices_Previews: PreviewProvider {
//     static var previews: some View {
//         HotelRoomDevices()
//     }
// }
