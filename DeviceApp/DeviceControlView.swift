//
//  DeviceControlView.swift
//  LIMI AI Device
//
//  Routes CCT / RGB channels to the same 3D dial control screens as the
//  main LIMI AI app (CCTLEDPreviewView / RGBLEDPreviewView). Commands,
//  persistence keys, and UI stay identical across both apps.
//
//  Home UI 1: neumorphic canvas + connection chrome (theme-gated).
//

import SwiftUI

struct DeviceControlView: View {
    let deviceName: String
    let chennalMac: String
    let channel: Int
    let channelType: String

    @ObservedObject private var pendantTypeStore = DevicePendantTypeStore.shared
    @ObservedObject private var socket = LightControllingSocket.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }

    private var normalizedType: String {
        channelType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "RGB" ? "RGB" : "CCT"
    }

    var body: some View {
        // Observe store so the USDZ updates when device_status arrives.
        let _ = pendantTypeStore.pendantTypesByDeviceId
        let pendantModel = PendantModelCatalog.bundledName(forDeviceId: chennalMac)

        ZStack {
            if usesHomeUI1 {
                HomeUI1ControlScreenBackground()
            }

            VStack(spacing: 0) {
                if socket.connectionStatus != .connected {
                    Group {
                        if usesHomeUI1 {
                            HomeUI1ControlConnectionBanner()
                        } else {
                            DeviceConnectionBanner()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.bar)
                        }
                    }
                    .padding(.horizontal, usesHomeUI1 ? 16 : 0)
                    .padding(.top, usesHomeUI1 ? 10 : 0)
                    .padding(.bottom, usesHomeUI1 ? 8 : 0)
                }

                Group {
                    if normalizedType == "RGB" {
                        RGBLEDPreviewView(
                            chennalMac: chennalMac,
                            chennelPosition: channel,
                            bundledName: pendantModel
                        )
                        .id("rgb-\(chennalMac)-\(channel)-\(pendantModel)")
                    } else {
                        CCTLEDPreviewView(
                            chennalMac: chennalMac,
                            chennelPosition: channel,
                            bundledName: pendantModel
                        )
                        .id("cct-\(chennalMac)-\(channel)-\(pendantModel)")
                    }
                }
            }
        }
        .navigationTitle(deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
        .onAppear {
            LightControllingSocket.shared.connect()
            let key = LimiDeviceNaming.normalizedHardwareId(chennalMac)
            guard !key.isEmpty else { return }
            DevicePresenceCoordinator.shared.requestRefresh(
                deviceIds: [key],
                reason: .homeAppear,
                force: true
            )
        }
    }
}

#Preview {
    NavigationStack {
        DeviceControlView(
            deviceName: "Living Room",
            chennalMac: "80B54EE8B228",
            channel: 1,
            channelType: "CCT"
        )
    }
}
