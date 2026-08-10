//
//  DemoAddDeviceView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//



import SwiftUI

struct DemoAddDeviceView: View {
    @ObservedObject var bluetoothManager: HomeBluetoothAdapter
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            if isSearching {
                Text("Searching…")
                    .font(LimiTypography.headline)
                    .padding()
            } else {
                Button(action: {
                    isSearching = true
                    bluetoothManager.addDummyDevice()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isSearching = false
                    }
                }) {
                    Text("Add Device")
                        .font(LimiTypography.title)
                        .padding()
                        .foregroundColor(.appTextInverse)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LimiGradients.cta)
                        )
                }
            }
        }
        .padding()
    }
}
