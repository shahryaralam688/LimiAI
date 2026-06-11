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
                    .foregroundColor(selectedTab == 0 ? .emerald : .themeWhite.opacity(0.6))
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
                    .foregroundColor(selectedTab == 1 ? .emerald : .themeWhite.opacity(0.6))
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
            .background(Color.appSurfaceTertiary)
            .overlay(
                Rectangle()
                    .fill(Color.themeWhite.opacity(0.1))
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
        .background(Color.appCanvasPrimary.ignoresSafeArea())
    }
}


// MARK: - BLE Devices View
import SwiftUI

struct BLEDevicesView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @ObservedObject private var sharedDevice = SharedDevice.shared
    @StateObject private var viewModel = HotelRoomDevicesViewModel()

    // MiniController requires brightness and warm/cold bindings
    @State private var miniBrightness: Double = 50
    @State private var miniWarmCold: Double = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Title
                HStack {
                    Text("BLE Devices")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.appTextPrimary)

                    Spacer()

                    Button("WLED") {
                        viewModel.presentWLEDDiscovery()
                    }
                    .foregroundColor(.themeWhite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appSurfaceTertiary)
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
                            .foregroundColor(.themeWhite.opacity(0.6))
                        Text(bluetoothManager.isBluetoothOn
                             ? "No devices connected through Bluetooth"
                             : "Bluetooth is Off")
                            .font(.headline)
                            .foregroundColor(.themeWhite.opacity(0.85))
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
                            ForEach(viewModel.connectedDeviceItems.indices, id: \.self) { index in
                                let item = viewModel.connectedDeviceItems[index]
                                DeviceCard(
                                    device: item,
                                    onToggle: { _ in /* hook to BLE command if needed */ },
                                    onTap: {
                                        viewModel.handleDeviceCardTap(
                                            item,
                                            bluetoothManager: bluetoothManager,
                                            sharedDevice: sharedDevice
                                        )
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
            .background(Color.appCanvasPrimary)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $viewModel.showWLEDView) {
        //    WLEDView()
        }
        .sheet(isPresented: $viewModel.showWLEDDiscovery) {
            WLEDDiscoveryView()
        }
        .sheet(isPresented: $viewModel.showPWMView) {
            if let hub = viewModel.selectedHub {
                LimiModalNavigationShell(title: "PWM Control", onClose: { viewModel.showPWMView = false }) {
                    PWM2LEDView(hub: hub)
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $viewModel.showDataRGB) {
            if let hub = viewModel.selectedHub {
                LimiModalNavigationShell(title: "RGB Control", onClose: { viewModel.showDataRGB = false }) {
                    DataRGBView(hub: hub)
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $viewModel.showMiniController) {
            if let hub = viewModel.selectedHub {
                LimiModalNavigationShell(title: "Mini Controller", onClose: { viewModel.showMiniController = false }) {
                    MiniControllerView(hub: hub, brightness: $miniBrightness, warmCold: $miniWarmCold)
                }
            } else {
                EmptyView()
            }
        }

        // 🔎 Your auto-scan/auto-connect block (unchanged logic)
        .onChange(of: bluetoothManager.isBluetoothOn) { _, isOn in
            viewModel.handleBluetoothStateChanged(isOn: isOn, bluetoothManager: bluetoothManager)
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
        NavigationStack {
            VStack(spacing: 12) {
                // Title
                HStack {
                    Text("Wi-Fi Devices")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                    Button("WLED"){
                        showWLEDViewScan = true
                    }
                    .foregroundColor(.themeWhite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appSurfaceTertiary)
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
            .background(Color.appCanvasPrimary)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showWLEDView) {
//            WLEDView()
        }
        .sheet(isPresented: $showWLEDViewScan) {
            WLEDDiscoveryView()
                .limiModalSheetStyle()
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
                            .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                }
                
                // Title and device count
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.title)
                        .font(.custom("Lexend", size: 17))
                        .fontWeight(.semibold)
                        .kerning(0)
                        .foregroundColor(.appTextPrimary)
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
                        .foregroundColor(.appTextPrimary)
                    
                    Spacer()
                    
                    // Custom Toggle Switch
                    Button(action: {
                        isOn.toggle()
                        onToggle(isOn)
                    }) {
                        ZStack {
                            // Background
                            Rectangle()
                                .fill(isOn ? Color.emerald : Color.appCanvasHotel)
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
                    .fill(Color.appSurfaceTertiary)
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
