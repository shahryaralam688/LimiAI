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
        VStack {
            
            VStack(alignment: .center, spacing:12){
                HStack{
                    Button {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image("Solid arrow right sm")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(12) // space inside the circle
                            .background(
                                Rectangle()
                                    .fill(Color.appSurfacePrimary) // gray background
                                    .cornerRadius(16)
                            )
                    }
                    Spacer()
                    Text("Add Device")
                        .font(.custom("Poppins-Bold", size: 30)) // font-family: Poppins; weight: 700 (Bold)
                        .multilineTextAlignment(.center)          // text-align: center
                        .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                        .kerning(-0.3)                            // letter-spacing: -1%
                        .foregroundColor(Color.alabaster)
                        .padding(.trailing, 20)

                    Spacer()
                    Spacer()

//                    Text("Skip")
//                        .font(.custom("Poppins-Medium", size: 16)) // font-family + style
//                        .foregroundColor(Color.appTextPrimary)    // background color in design is likely text color
//                        .underline(true, color: Color.appTextPrimary) // underline as specified
//                        .kerning(0)                               // letter-spacing: 0%
//                        .lineSpacing(0)                            // line-height: 100%
//                        .padding(.top, 14)
//                        .onTapGesture {
//                            showConnectedView = true
//                        }
                    
                }
                .padding(.horizontal, 16)
                HStack{
                    Image(systemName: "wifi")
                        .resizable()                    // Make it resizable
                        .scaledToFit()                  // Keep aspect ratio
                        .frame(width: 60, height: 60) // Set desired size
                        .foregroundColor(.alabaster)
                    

                }

                
                
            }.padding(.bottom, 12)
            
            VStack{
                List {
                    ForEach(Array(wifiList.enumerated()), id: \.offset) { index, ssid in
                        HStack(spacing: 12) {
                            Text(ssid)
                                .font(.custom("Poppins-SemiBold", size: 24))
                                .foregroundColor(.alabaster)
                                .lineSpacing(0) // Adjust if needed for line-height
                                .kerning(-0.5) // letter-spacing
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    wifiSSIDs = ssid
                                    isShowingAddingWifiSheet = true
                                }
                            
                            Spacer()
                            Image(systemName: "wifi")
                                .foregroundColor(.alabaster)
                            
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
                                .foregroundColor(.gray)
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
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.appCanvasPrimary)
        .fullScreenCover(isPresented: $isShowingAddingWifiSheet) {
            DemoAddingWifiView(deviceName: deviceName, deviceId: deviceId,  wifiSSID : wifiSSIDs )

        }
        .fullScreenCover(isPresented: $showConnectedView) {
            DemoConnectedWifiView( deviceName: deviceName)
        }

    }
}


#Preview {
    WifiList(deviceName: "", deviceId:  "" , wifiList : ["home wifi", "work wifi", "school wifi"])
}
