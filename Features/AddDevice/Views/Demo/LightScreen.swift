//
//  LightScreen.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//

import SwiftUI

struct LightScreen: View {
    let title: String
    @State private var isLoaded = false
    @State private var searchFieldFocused = false
    @State private var headerOffset: CGFloat = -100
    @State private var shimmerAnimation = false
    @State private var isAIEnabled: Bool = false
    @State private var showToast: Bool = false
    @State private var lightNames: [String] = ["Lana Pendant Light", "Astoria Pendant Light", "Oceana Small Ceiling Light"]
    @State private var lightStatus: [Bool] = [false, false, false] // light on/off status
    
    // New state for the bottom sheet
    @State private var showDeviceSheet: Bool = false

    var body: some View {
        VStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.appCanvasPrimary.opacity(0.8), Color.appTextPrimary.opacity(0.9)]),
                               startPoint: .top,
                               endPoint: .bottom)
                
                RadialGradient(
                    gradient: Gradient(colors: [Color.themeWhite.opacity(0.3), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.width * 1.3
                )
                .scaleEffect(shimmerAnimation ? 1.2 : 0.8)
                .opacity(shimmerAnimation ? 0.7 : 0.3)
                .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true), value: shimmerAnimation)
                .onAppear {
                    shimmerAnimation = true
                }

                VStack {
                    Text(title)
                        .font(LimiTypography.largeTitle)
                        .padding()

                    if showToast {
                        Text("AI adjusting environment…")
                            .font(LimiTypography.subheadline)
                            .foregroundColor(.appTextPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.themeBlack.opacity(0.8))
                            .cornerRadius(8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                    }

                    Button(action: {
                        // Show the device search sheet instead of inline search
                        showDeviceSheet = true
                    }) {
                        Text("Add Device")
                            .fontWeight(.bold)
                            .padding()
                            .frame(width: 150, height: 60)
                            .background(Color.brandAction)
                            .foregroundColor(.appTextPrimary)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)

                    // Display light cards
                    ForEach(lightNames.indices, id: \.self) { index in
                        LightCard(
                            lightName: lightNames[index],
                            index: index,
                            isAIEnabled: $isAIEnabled
                        )
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Lights")
            }
            .edgesIgnoringSafeArea(.all)
            // Add the sheet presentation
            .sheet(isPresented: $showDeviceSheet) {
                DeviceSearchSheet(
                    isPresented: $showDeviceSheet,
                    lightNames: $lightNames,
                    lightStatus: $lightStatus
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - AI Mode Logic
    func startAIMode() {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showToast = false
            }
        }

        for index in lightNames.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) {
                if isAIEnabled {
                    lightStatus[index] = true
                }
            }
        }
    }

    func stopAIMode() {
        for index in lightStatus.indices {
            lightStatus[index] = false
        }
        showToast = false
    }
}
