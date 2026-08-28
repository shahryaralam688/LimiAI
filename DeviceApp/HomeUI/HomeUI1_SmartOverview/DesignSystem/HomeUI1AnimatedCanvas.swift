//
//  HomeUI1AnimatedCanvas.swift
//  LIMI AI Device — Home UI 1
//
//  Dark charcoal-green ambient gradient with a slow emerald glow drift.
//

import SwiftUI

/// Full-bleed animated background for Home UI 1.
struct HomeUI1AnimatedCanvas: View {
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            HomeUI1Color.canvas

            LinearGradient(
                colors: [
                    HomeUI1Color.ambientWarm,
                    HomeUI1Color.canvas,
                    HomeUI1Color.ambientMint
                ],
                startPoint: UnitPoint(x: 0.05 + drift * 0.22, y: 0.0),
                endPoint: UnitPoint(x: 0.95 - drift * 0.18, y: 1.0)
            )

            // Emerald bloom (top-trailing → drifts)
            RadialGradient(
                colors: [
                    HomeUI1Color.accentGreen.opacity(0.14),
                    Color.clear
                ],
                center: UnitPoint(x: 0.82 - drift * 0.32, y: 0.18 + drift * 0.22),
                startRadius: 24,
                endRadius: 360
            )

            // Warm charcoal pool (bottom-leading → drifts)
            RadialGradient(
                colors: [
                    HomeUI1Color.ambientWarm.opacity(0.55),
                    Color.clear
                ],
                center: UnitPoint(x: 0.16 + drift * 0.28, y: 0.78 - drift * 0.18),
                startRadius: 16,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(HomeUI1Motion.ambient.repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }
}
