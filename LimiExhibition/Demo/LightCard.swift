//
//  LightCard.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//


import SwiftUI

struct LightCard: View {
    let lightName: String
    let index: Int // NEW: Position in the list
    @Binding var isAIEnabled: Bool

    @State private var isOn: Bool = false
    @State private var brightness: Double = 1.0
    @State private var animate = false
    @State private var isNavigatingToPWM = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    
                    .foregroundColor(.eton)
                Text(lightName)
                    .font(.headline)
                    .foregroundColor(.charlestonGreen)
                Spacer()

                Toggle(isOn: $isOn) {
                    Text(isOn ? "On" : "Off")
                        .foregroundColor(isOn ? .green : .red)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .disabled(isAIEnabled)
                .labelsHidden()

                NavigationLink(
                    destination: PWM2LEDView(hub: Hub(name: "Test Hub")),
                    isActive: $isNavigatingToPWM
                ) {
                    EmptyView()
                }
            }
            .padding()
            .background(Color.white.opacity(brightness))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .onTapGesture {
            isNavigatingToPWM = true
        }
        .onChange(of: isAIEnabled) { _, newValue in
            if newValue {
                startAIModeWithDelay()
            } else {
                stopAIMode()
            }
        }
    }

    // MARK: - AI Mode Logic
    func startAIModeWithDelay() {
        // Delay based on card index to stagger ON state
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index)) {
            guard isAIEnabled else { return }
            isOn = true
            animate = true
            runLightAnimation()
            runAutoToggleLoop()
        }
    }

    func stopAIMode() {
        animate = false
        isOn = false
        brightness = 1.0
    }

    func runLightAnimation() {
        guard animate else { return }
        withAnimation(.easeInOut(duration: 2.0)) {
            brightness = brightness == 1.0 ? 0.5 : 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            runLightAnimation()
        }
    }

    func runAutoToggleLoop() {
        Task {
            while isAIEnabled {
                isOn.toggle()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}
