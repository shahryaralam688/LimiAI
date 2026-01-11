//
//  HubRowView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Hub Row Component
struct HubRowView: View {
    var hub: Hub
    var index: Int
    var isLoaded: Bool
    var bluetoothManager: BluetoothManager

    var body: some View {
        NavigationLink(destination: Text("\(hub.name) Detail View")) {
            HubCardView(hub: hub, bluetoothManager: bluetoothManager)
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .offset(x: isLoaded ? 0 : 300)
                .opacity(isLoaded ? 1 : 0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(index) * 0.1 + 0.3),
                    value: isLoaded
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
