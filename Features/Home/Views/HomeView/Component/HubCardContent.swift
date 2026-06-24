//
//  HubCardContent.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Hub Card Content Component
struct HubCardContent: View {
    let hub: Hub
    var pulseAnimation: Bool
    var isExpanded: Bool
    @ObservedObject var bluetoothManager: HomeBluetoothAdapter
    @State private var isOn = false
    @State private var wireHeight: CGFloat = 300
    
    var body: some View {
        VStack() {
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.themeWhite)
                Spacer()
            }
            .padding(10)
            
            HStack {
                Text(bluetoothManager.connectedDeviceName ?? hub.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(10)
            
            Spacer()
            
            HStack{
                Text("Connect")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Spacer()
                Toggle(isOn: $isOn) {}
                    .frame(width: 60, height: 32)
                    .toggleStyle(SwitchToggleStyle(tint: .emerald))
                    .onChange(of: isOn) {}
            }
            .padding()
        }
        .frame(height: 165.5)
        .frame(height: 160)
        .background(
            Color.appSurfacePrimary

        )
        .cornerRadius(16)
        .shadow(color: Color.themeBlack.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

