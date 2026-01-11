//
//  BackgroundView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//

import SwiftUI
// MARK: - Background View Component
struct BackgroundView: View {
    @Binding var shimmerAnimation: Bool
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(gradient: Gradient(colors: [Color.charlestonGreen.opacity(0.8), Color.alabaster.opacity(0.9)]),
                           startPoint: .top,
                           endPoint: .bottom)
            
            // Animated overlay gradient for dynamic effect
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                center: .topLeading,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 1.3
            )
            .scaleEffect(shimmerAnimation ? 1.2 : 0.8)
            .opacity(shimmerAnimation ? 0.7 : 0.3)
            .animation(
                Animation.easeInOut(duration: 4)
                    .repeatForever(autoreverses: true),
                value: shimmerAnimation
            )
            
            // Subtle pattern overlay
            ZStack {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: CGFloat.random(in: 100...200))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
