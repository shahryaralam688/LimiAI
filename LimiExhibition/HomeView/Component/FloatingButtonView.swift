//
//  FloatingButtonView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Floating Button Component
struct FloatingButtonView: View {
    @Binding var isNavigating: Bool
    @Binding var isLoaded: Bool
    var demoEmail: String
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if bluetoothManager.storedHubs.isEmpty {
                    if demoEmail == "umer.asif@terralumen.co.uk" {
                        EnhancedFloatingButton(isNavigating: $isNavigating)
                            .offset(y: isLoaded ? 0 : 100)
                            .opacity(isLoaded ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5), value: isLoaded)
                    }
                } else {
                    EnhancedFloatingButton(isNavigating: $isNavigating)
                        .offset(y: isLoaded ? 0 : 100)
                        .opacity(isLoaded ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5), value: isLoaded)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}