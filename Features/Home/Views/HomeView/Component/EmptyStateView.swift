//
//  EmptyStateView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Empty State Component
struct EmptyStateView: View {
    var isLoaded: Bool
    @Binding var isNavigatingToAddDevice: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.brandHighlight.opacity(0.1), lineWidth: 2)
                        .frame(width: 120 + CGFloat(i * 30), height: 120 + CGFloat(i * 30))
                        .scaleEffect(isLoaded ? 1.0 : 0.8)
                        .opacity(isLoaded ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0).delay(0.3 + Double(i) * 0.1), value: isLoaded)
                }
                Image(systemName: "house.fill")
                    .font(LimiTypography.title2)
                    .foregroundColor(.brandHighlight)
                    .opacity(isLoaded ? 1 : 0)
                    .scaleEffect(isLoaded ? 1 : 0.5)
                    .rotationEffect(isLoaded ? .degrees(0) : .degrees(-30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5), value: isLoaded)
            }
            .frame(height: 150)
            .padding(.top, 20)
            
            VStack(spacing: 10) {
                Text("No devices linked yet")
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextInverse)
                    .opacity(isLoaded ? 1 : 0)
                    .animation(.easeIn.delay(0.6), value: isLoaded)
                
                Text("Tap + to add your first device")
                    .font(LimiTypography.subheadline)
                    .foregroundColor(.appTextMuted)
                    .opacity(isLoaded ? 1 : 0)
                    .animation(.easeIn.delay(0.8), value: isLoaded)
                    .padding(.bottom, 10)
                
                Button(action: {
                    isNavigatingToAddDevice = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(LimiTypography.body)
                        Text("Add Device")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.appTextPrimary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.brandAction)
                    )
                    .shadow(color: Color.brandAction.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .zIndex(10) // Ensure button is above other elements
                .allowsHitTesting(true) // Explicitly enable hit testing
                .opacity(isLoaded ? 1 : 0)
                .animation(.easeIn.delay(1.0), value: isLoaded)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
