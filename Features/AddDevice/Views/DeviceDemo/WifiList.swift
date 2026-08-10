//
//  WifiList.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 29/10/2025.
//

import SwiftUI
import RealityKit
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import UIKit

struct WifiList: View {
    let deviceName: String
    let deviceId: String
    let wifiList: [String]
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingRGBDataSheet: Bool = false
    @State private var networks: [String] = []
    @State private var locationManager: CLLocationManager? = nil
    @State private var wifiSSIDs: String = ""
    @State private var isShowingAddingWifiSheet: Bool = false
    @State private var showConnectedView: Bool = false
//    @StateObject private var authProxy = LocationAuthProxy()
    
    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Choose a Wi-Fi network for your device")

            HStack {
                Image(systemName: "wifi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.appTextPrimary)
            }
            .padding(.vertical, 12)
            
            VStack{
                List {
                    ForEach(Array(wifiList.enumerated()), id: \.offset) { index, ssid in
                        HStack(spacing: 12) {
                            Text(ssid)
                                .font(LimiTypography.button)
                                .foregroundColor(.appTextPrimary)
                                .lineSpacing(0) // Adjust if needed for line-height
                                .kerning(-0.5) // letter-spacing
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    wifiSSIDs = ssid
                                    isShowingAddingWifiSheet = true
                                }
                            
                            Spacer()
                            Image(systemName: "wifi")
                                .foregroundColor(.appTextPrimary)
                            
                        }
                        .padding()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("Selected SSID: \(ssid)")
                        }
                        .listRowBackground(Color.clear)
                    }
                    if wifiList.isEmpty {
                        HStack {
                            Text("No Wi‑Fi detected. Grant location permission or connect to a network.")
                                .foregroundColor(.appTextMuted)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    Rectangle()
                        .fill(Color.appSurfacePrimary)
                        .cornerRadius(24)
                )
                .limiFloatingOrbClearance()
            }
        }
        .background(Color.appCanvasPrimary)
        .fullScreenCover(isPresented: $isShowingAddingWifiSheet) {
            DemoAddingWifiView(deviceName: deviceName, deviceId: deviceId,  wifiSSID : wifiSSIDs )

        }
        .fullScreenCover(isPresented: $showConnectedView) {
            DemoConnectedWifiView( deviceName: deviceName)
        }
        .limiModalNavigationBar(title: "Add Device", onClose: {
            if let onBack {
                onBack()
            } else {
                dismiss()
            }
        })
        }
    }
}


#Preview {
    WifiList(deviceName: "", deviceId:  "" , wifiList : ["home wifi", "work wifi", "school wifi"])
}
