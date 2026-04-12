//
//  HubCardView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Hub Card Component
struct HubCardView: View {
    let hub: Hub
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var pulseAnimation = false
    @State private var isExpanded = false
    @State private var showAlert = false
    @State private var navigateTo16CH = false
    @State private var isAnimating = true
    @State private var buttonOpacity = 0.2
    @State private var selectedMode: String? = nil
    @State private var brightness: Double = 0.5
    @State private var warmCold: Double = 0.5
    @State private var navigateToMiniController = false
    @State private var navigateToLightScreen = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var destinationView: some View {
        switch selectedMode {
        case "PWM":
            return AnyView(PWM2LEDView(hub: hub))
        case "RGB":
            return AnyView(DataRGBView(hub: hub))
        case "MiniController":
            return AnyView(MiniControllerView(hub: hub, brightness: $brightness, warmCold: $warmCold))
        default:
            return AnyView(EmptyView())
        }
    }
    
    var body: some View {
        ZStack {
            if demoEmail == "umer.asif@terralumen.co.uk" {
                // Display a button that opens LightScreen
                NavigationLink(destination: LightScreen(title: hub.name), isActive: $navigateToLightScreen) {
                    Button(action: {
                        navigateToLightScreen = true
                    }) {
                        HubCardContent(hub: hub, pulseAnimation: pulseAnimation, isExpanded: isExpanded, bluetoothManager: bluetoothManager)
                    }
                }
            } else {
                if !hasModeButton {
                    NavigationLink(destination: MiniControllerView(hub: hub, brightness: $brightness, warmCold: $warmCold), isActive: $navigateToMiniController) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                
                if hasHubButton {
                    NavigationLink(destination: HubCHView(hub: hub)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                HubCardContent(hub: hub, pulseAnimation: pulseAnimation, isExpanded: isExpanded, bluetoothManager: bluetoothManager)
                    .onTapGesture {
                        let impactMed = UIImpactFeedbackGenerator(style: .light)
                        impactMed.impactOccurred()
                        
                        withAnimation {
                            isPressed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isPressed = false
                            }
                        }
                        
                        if !hasModeButton {
                            navigateToMiniController = true
                        }
                        if !hasHubButton {
                            navigateTo16CH = true
                        }
                    }
                    .onHover { hovering in
                        isHovered = hovering
                    }
                if hasModeButton {
                    HStack{
                        Spacer()
                        Button(action: {
                            showAlert = true
                        }) {
                            Text(selectedMode == nil ? "Mode" : "Mode: \(selectedMode!)")
                                .font(.title)
                                .foregroundColor(.themeBlack)
                                .opacity(buttonOpacity)
                                .animation(isAnimating ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .none, value: buttonOpacity)
                        }
                        .padding(.horizontal, 30)
                        .disabled(selectedMode != nil)
                        .onAppear {
                            startAnimation()
                        }
                        .confirmationDialog("Please Select Your Mode", isPresented: $showAlert, titleVisibility: .visible) {
                            Button("PWM") { selectMode("PWM") }
                            Button("RGB") { selectMode("RGB") }
                            Button("MiniController") { selectMode("MiniController") }
                            Button("Cancel", role: .cancel) { }
                        }
                    }
                    
                }
                
                NavigationLink(destination: destinationView, isActive: Binding(
                    get: { selectedMode != nil },
                    set: { if !$0 { selectedMode = nil } }
                )) {
                    EmptyView()
                }
                .opacity(0)
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
    
    private func startAnimation() {
        DispatchQueue.main.async {
            buttonOpacity = 1.0
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                buttonOpacity = 0.5
            }
        }
    }
    
    private func selectMode(_ mode: String) {
        selectedMode = mode
        isAnimating = false
        buttonOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = true
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                buttonOpacity = 0.8
            }
        }
    }
    
    private var hasModeButton: Bool {
        return (bluetoothManager.connectedDeviceName ?? hub.name) != "LIMI-CONTROLLER"
    }
    
    private var hasHubButton: Bool {
        return (bluetoothManager.connectedDeviceName ?? hub.name) != "16 CH-HUB"
    }
}
