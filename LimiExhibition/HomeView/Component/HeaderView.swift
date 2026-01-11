//
//  HeaderView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Header View Component
struct HeaderView: View {
    @Binding var isSidebarOpen: Bool
    @State private var logoScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0

    var body: some View {
        HStack {
            // Enhanced logo with glow effect
            ZStack {
                // Glow effect
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 80)
                    .blur(radius: 5)
                    .opacity(glowOpacity)
                
                // Actual logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 80)
                    .scaleEffect(logoScale)
            }
            .padding(5)
            .onAppear {
                // Animation: Subtle logo pulse with glow
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    logoScale = 1.05
                    glowOpacity = 0.3
                }
            }
            
            Spacer()
            
            // Enhanced menu button with rotation and glow
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isSidebarOpen.toggle()
                    
                    // Haptic feedback when toggling menu
                    let impactMed = UIImpactFeedbackGenerator(style: .light)
                    impactMed.impactOccurred()
                }
            }) {
                ZStack {
                    // Button glow
                    Circle()
                        .fill(Color.eton.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .blur(radius: 5)
                        .opacity(isSidebarOpen ? 0.7 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isSidebarOpen)
                    
                    // Button background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.alabaster.opacity(0.9)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    
                    // Icon
                    Image(systemName: isSidebarOpen ? "xmark" : "line.horizontal.3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.charlestonGreen)
                }
                // Animation: Rotate when toggling
                .rotationEffect(.degrees(isSidebarOpen ? 90 : 0))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSidebarOpen)
            }
            .padding(.horizontal, 15)
        }
        .padding(.top, 50)
        .padding(.bottom, 0)
        .background(
            // Enhanced header background with depth and animation
            ZStack {
                // Base color
                Color.charlestonGreen.opacity(0.8)
                
                // Animated gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.1), Color.clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(glowOpacity * 2)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowOpacity)
                
                // Decorative elements
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: -120, y: 20)
                    .scaleEffect(logoScale)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: logoScale)
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .offset(x: 140, y: -30)
                    .scaleEffect(2 - logoScale)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: logoScale)
            }
            .clipShape(
                RoundedCornerShape(cornerRadius: 5, corners: [.bottomLeft, .bottomRight])
            )
        )
        .shadow(
            color: Color.black.opacity(0.65),
            radius: 10,
            x: 0,
            y: 5
        )
    }
}
