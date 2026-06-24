import SwiftUI

struct DemoScanDevicesView: View {
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DemoScanDevicesViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LimiModuleSubtitle(text: "Scanning for nearby Limi devices")
                AnimatedSearchButton(iconName: "magnifyingglass")
                deviceList
            }
            .background(Color.appCanvasPrimary)
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
            .onChange(of: viewModel.lastDisconnectedBLEDeviceID) { _, id in
                viewModel.handleDisconnectedDeviceID(id)
            }
            .fullScreenCover(isPresented: $viewModel.showAddWifi) {
                WifiList(
                    deviceName: viewModel.selectedName ?? "",
                    deviceId: viewModel.selectedId ?? "",
                    wifiList: viewModel.ssidNameArray
                )
            }
            .overlay { connectingOverlay }
            .fullScreenCover(isPresented: $viewModel.showLiginSkip) {
                ConnectedDevicesView()
            }
            .limiModalNavigationBar(title: "Add Device", onClose: {
                if let onBack { onBack() } else { dismiss() }
            })
        }
        .trackScreen("DemoScanDevicesView", metadata: ["surface": "ble_wifi_device_scan"])
    }

    private var deviceList: some View {
        VStack {
            HStack {
                Text("Available Devices")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.horizontal, 16)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(viewModel.orderedDevices) { device in
                        if viewModel.shouldRender(device) {
                            DevicesButton(
                                deviceName: device.name,
                                searchDeviceUUID: device.uuid,
                                onConnect: { name, id in
                                    if device.deviceType == .bluetooth {
                                        viewModel.connectBLEDevice(name: name, id: id)
                                    } else {
                                        viewModel.connectWiFiDevice(device)
                                    }
                                },
                                isConnected: viewModel.isDeviceConnected(device),
                                deviceType: device.deviceType,
                                ipAddress: device.ipAddress,
                                reachability: device.reachability
                            )
                            .opacity(viewModel.deviceOpacity(device))
                            .disabled(viewModel.isDeviceDisabled(device))
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .limiFloatingOrbClearance()
            }

            Spacer()

            if viewModel.shouldShowContinue {
                Button(action: { viewModel.showLiginSkip = true }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.themeWhite)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }

    @ViewBuilder
    private var connectingOverlay: some View {
        if viewModel.isConnectingToBLE {
            ZStack {
                Color.themeBlack.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                        .scaleEffect(1.5)
                    Text("Connecting to device...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.themeWhite)
                }
            }
        }
    }
}

#Preview { DemoScanDevicesView() }
