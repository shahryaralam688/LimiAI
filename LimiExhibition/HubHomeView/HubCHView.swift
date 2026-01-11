//
//  ContentView.swift
//  Limi
//
//  Created by Mac Mini on 01/04/2025.
//


import SwiftUI

struct HubCHView: View {
    let hub: Hub
    var body: some View {
        // A grid layout with 4 columns
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        VStack{
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(1...16, id: \.self) { index in
                        CardView(hub: hub, cardNumber: index)
                    }
                }
                .padding()
            }
        }
        .background(ElegantGradientBackgroundView())

    }
}

struct CardView: View {
    let hub: Hub
    var cardNumber: Int
    @State private var selectedMode: String? = nil
    @State private var brightness: Double = 0.5
    @State private var warmCold: Double = 0.5
    @State private var showAlert = false
    @State private var buttonOpacity = 0.2
    @State private var isAnimating = true


    var destinationView: some View {
        switch selectedMode {
        case "PWM":
            return AnyView(PWM2LEDView(hub: hub))
        case "RGB":
            return AnyView(DataRGBView(hub: hub))
        case "MiniController":
            return AnyView(MiniControllerView(hub: hub, brightness: $brightness, warmCold: $warmCold)) // Pass the hub to MiniControllerView
        default:
            return AnyView(EmptyView())
        }
    }
    var body: some View {
        VStack {
            Button(action: {
                showAlert = true
            }) {
                Text("Ch-\(cardNumber)")
                    .font(.title)
                    .foregroundColor(.black)
                    .opacity(buttonOpacity)
                    .animation(isAnimating ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .none, value: buttonOpacity)
            }
            .disabled(selectedMode != nil)
            .onAppear {
                startAnimation()
            }
            .confirmationDialog("Please Select Your Ch-\(cardNumber) Mode", isPresented: $showAlert, titleVisibility: .visible) {
                Button("PWM") { selectMode("PWM") }
                Button("RGB") { selectMode("RGB") }
                Button("MiniController") { selectMode("MiniController") }
                Button("Cancel", role: .cancel) { }
            }


        }
        .frame(width: (UIScreen.main.bounds.width - 60) / 4, height: 100) // Responsive width
        .background(Color.alabaster)
        .cornerRadius(10)
        .shadow(radius: 5)
        
        NavigationLink(destination: destinationView, isActive: Binding(
            get: { selectedMode != nil },
            set: { if !$0 { selectedMode = nil } }
        )) {
            EmptyView()
        }
        .opacity(0)
        .onTapGesture {
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
    

}


#Preview {
    HubCHView(hub: Hub(name: "Test Hub"))
}
