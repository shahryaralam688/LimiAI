//
//  SpacesListView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//

import SwiftUI

// MARK: - Spaces List Component
struct SpacesListView: View {
    var demoEmail: String
    var searchText: String
    @Binding var isLoaded: Bool
    @Binding var isNavigatingToAddDevice: Bool
    @ObservedObject var bluetoothManager: HomeBluetoothAdapter
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Connected Devices")
                    .font(LimiTypography.headline)
                    .tracking(-0.0083) // matches -0.15px letter spacing
                    .lineSpacing(3.6)  // ~120% line-height
                    .foregroundColor(.appTextPrimary)

            }
            .padding(.horizontal, 5)
            .padding(.top, 15)
            .opacity(isLoaded ? 1 : 0)
            .animation(.easeIn.delay(0.3), value: isLoaded)
            
            if demoEmail == "umer.asif@terralumen.co.uk" {
                DemoHubsListView(isLoaded: isLoaded, bluetoothManager: bluetoothManager, searchText: searchText)
            } else {
                if bluetoothManager.storedHubs.isEmpty {
                    EmptyStateView(isLoaded: isLoaded, isNavigatingToAddDevice: $isNavigatingToAddDevice)
                } else {
                    HubsListView(isLoaded: isLoaded, bluetoothManager: bluetoothManager, searchText: searchText)
                }
            }
        }
        .onAppear {
            isLoaded = true
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(isPresented: $isNavigatingToAddDevice) {
            AddDeviceCoordinator.destination(for: .legacyInstallerFlow)
        }
    }
}
