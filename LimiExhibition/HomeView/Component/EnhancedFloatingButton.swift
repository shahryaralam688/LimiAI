//
//  EnhancedFloatingButton.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Enhanced Floating Button
struct EnhancedFloatingButton: View {
    @Binding var isNavigating: Bool
    @State private var isAnimating = false
    @State private var rotationDegrees = 0.0
    @State private var glowOpacity = 0.0
    @State private var showDemoView = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        Button(action: {
            if demoEmail == "umer.asif@terralumen.co.uk" {
                showDemoView = true // Trigger the sheet presentation
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isAnimating = true
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isNavigating = true
                        isAnimating = false
                    }
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.eton.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .blur(radius: 5)
                    .opacity(glowOpacity)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowOpacity)
                    .onAppear { glowOpacity = 0.7 }
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.eton.opacity(0.7), Color.eton.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(rotationDegrees))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                            rotationDegrees = 360
                        }
                    }
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.eton, Color.eton.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.eton.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(isAnimating ? 0.9 : 1.0)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 0.8 : 1.0)
                    .rotationEffect(.degrees(isAnimating ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            }
        }
        .sheet(isPresented: $showDemoView) {
            DemoAddDeviceView(bluetoothManager: bluetoothManager)
        }
        .padding()
    }
}

// MARK: - Enhanced Floating Button
struct WifiFloatingButton: View {
    @State private var isAnimating = false
    @State private var rotationDegrees = 0.0
    @State private var glowOpacity = 0.0
    @State private var showDemoView = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        Button(action: {
                showDemoView = true // Trigger the sheet presentation
            
        }) {
            ZStack {
                Circle()
                    .fill(Color.eton.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .blur(radius: 5)
                    .opacity(glowOpacity)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowOpacity)
                    .onAppear { glowOpacity = 0.7 }
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.eton.opacity(0.7), Color.eton.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(rotationDegrees))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                            rotationDegrees = 360
                        }
                    }
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.eton, Color.eton.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.eton.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(isAnimating ? 0.9 : 1.0)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 0.8 : 1.0)
                    .rotationEffect(.degrees(isAnimating ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            }
        }
        .sheet(isPresented: $showDemoView) {
            DemoScanDevicesView()
        }
        .padding()
    }
}
