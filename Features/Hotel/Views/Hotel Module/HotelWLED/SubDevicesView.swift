//
//  SubDevicesView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 05/11/2025.
//

import SwiftUI
import SwiftUI
import UIKit

struct SubDevicesView: View {
    
    @State private var isOn = true

    // Two equal columns
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Header
            HStack {
                Text("Settings")
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)
                    .padding()
                    .padding(.top, 40)
                Spacer()
            }
            .background(
                Rectangle()
                    .fill(Color.appSurfaceTertiary)
                    .frame(height: 114)
                    .cornerRadius(40)
            )
            .ignoresSafeArea()
            
            // MARK: - Device Grid
            VStack {
                HStack {
                    Text("Connected Devices")
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        deviceCard(deviceID: "D1", deviceName: "Living Room Light", channelCount: 2, status: true)
                        deviceCard(deviceID: "D2", deviceName: "Bedroom Lamp", channelCount: 1, status: false)
                        deviceCard(deviceID: "D3", deviceName: "Kitchen Light", channelCount: 3, status: true)
                        deviceCard(deviceID: "D4", deviceName: "Garage Light", channelCount: 1, status: false)
                    }
                    .padding()
                }
            }
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
    }
    
    
    // MARK: - Device Card Function
    private func deviceCard(deviceID: String, deviceName: String, channelCount: Int, status: Bool) -> some View {
        Button(action: {
            print("\(deviceID) tapped")
        }) {
            VStack(alignment: .leading, spacing: 16) {
                
                // Icon
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.appSurfaceCard)
                            .frame(width: 45, height: 45)
                        
                        Image(systemName: "home")
                            .font(LimiTypography.title2)
                            .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                }
                
                // Device Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(deviceName)
                        .font(LimiTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(2)
                    
                    Text("\(channelCount) channels")
                        .font(LimiTypography.footnote)
                        .foregroundColor(.appTextPrimary.opacity(0.6))
                }
                
                Spacer()
                
                // Status and Toggle
                HStack {
                    Text(isOn ? "On" : "Off")
                        .font(LimiTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.appTextPrimary)
                    
                    Spacer()
                    
                    // Custom Toggle Switch
                    Button(action: {
                        isOn.toggle()
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(isOn ? Color.appSuccess : Color.appCanvasHotel)
                                .frame(width: 50, height: 26)
                                .cornerRadius(100)
                            
                            Circle()
                                .fill(Color.themeWhite)
                                .frame(width: 20, height: 20)
                                .offset(x: isOn ? 12 : -12)
                                .animation(.easeInOut(duration: 0.2), value: isOn)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appSurfaceTertiary)
            )
            .frame(width: 163.5, height: 207)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


struct SubDevicesView_Previews: PreviewProvider {
    static var previews: some View {
        SubDevicesView()
    }
}
