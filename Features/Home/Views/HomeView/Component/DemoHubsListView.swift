//
//  DemoHubsListView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//

import SwiftUI
// MARK: - Demo Hubs List Component
struct DemoHubsListView: View {
    var isLoaded: Bool
    @ObservedObject var bluetoothManager: HomeBluetoothAdapter
    var searchText: String
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(filteredDemoHubs.enumerated()), id: \.element.id) { index, hub in
                    HubRowView(hub: hub, index: index, isLoaded: isLoaded, bluetoothManager: bluetoothManager)
                }
            }
            .padding()
        }
        .onAppear {
            // Any setup needed for demo hubs
        }

    }
    
    private var filteredDemoHubs: [Hub] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return bluetoothManager.demoStoredHubs }
        return bluetoothManager.demoStoredHubs.filter { $0.name.lowercased().contains(text) }
    }
}
