//
//  DeviceSearchSheet.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//



//
//  DeviceSearchSheet.swift
//  Limi
//
//  Created by Mac Mini on 08/04/2025.
//


import SwiftUI

struct DeviceSearchSheet: View {
    @Binding var isPresented: Bool
    @Binding var lightNames: [String]
    @Binding var lightStatus: [Bool]
    
    @State private var isSearching = true
    @State private var foundDevices: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Handle at the top for visual indication of sheet
            Rectangle()
                .frame(width: 40, height: 5)
                .cornerRadius(2.5)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 10)
            
            Text("Add Device")
                .font(LimiTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(.appTextInverse)
            
            if isSearching {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .foregroundColor(.appTextInverse)

                    
                    Text("Searching for devices...")
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextInverse)

                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .onAppear {
                    // Simulate finding devices after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        foundDevices = [
                            "Smart Light \(lightNames.count + 1)",
                            "Smart Light \(lightNames.count + 2)",
                            "Smart Light \(lightNames.count + 3)"
                        ]
                        isSearching = false
                    }
                }
            } else {
                // List of found devices
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(foundDevices, id: \.self) { device in
                            Button(action: {
                                // Add the selected device
                                lightNames.append(device)
                                lightStatus.append(false)
                                
                                // Close the sheet
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.eton)
                                        .padding(.trailing, 5)
                                    
                                    Text(device)
                                        .foregroundColor(.appTextInverse)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.emerald)
                                }
                                .padding()
                                .background(Color.themeWhite)
                                .cornerRadius(10)
                                .shadow(color: Color.themeBlack.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Cancel button
            Button(action: {
                isPresented = false
            }) {
                Text("Cancel")
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.appTextInverse)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
        .background(Color.appCanvasPrimary)
        .clipShape(
            .rect(
                topLeadingRadius: 20,
                topTrailingRadius: 20
            )
        )
        .edgesIgnoringSafeArea(.bottom)
    }
}

