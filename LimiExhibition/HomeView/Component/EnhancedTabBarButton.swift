//
//  EnhancedTabBarButton.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI

// MARK: - Tab Bar Button Component
struct EnhancedTabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var bounceAnimation = false
    @State private var glowOpacity = 0.0

    var body: some View {
        Button(action: {
            action()
            // Trigger bounce animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bounceAnimation = false
                }
            }
        }) {
            VStack(spacing: 4) {
                // Enhanced icon with glow and animation
                ZStack {
                    // Glow effect for selected tab
                    if isSelected {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .blur(radius: 4)
                            .opacity(glowOpacity)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: glowOpacity
                            )
                            .onAppear {
                                glowOpacity = 0.5
                            }
                    }
                    
                    // Icon
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .scaleEffect(bounceAnimation && isSelected ? 1.2 : 1.0)
                }
                
                // Title with animation
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // Enhanced indicator for selected tab
            .overlay(
                ZStack {
                    if isSelected {
                        // Pill indicator
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 25, height: 3)
                            .offset(y: 16)
                        
                        // Dot indicator
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(y: 16)
                    }
                },
                alignment: .bottom
            )
        }
    }
}