//
//  HomeUI1AnimatedCanvas.swift
//  LIMI AI Device — Home UI 1
//
//  Soft cream → mint ambient gradient that slowly drifts.
//  Kept low-contrast so neumorphic surfaces still read cleanly.
//

import SwiftUI

/// Full-bleed animated background for Home UI 1 (matches soft mint/cream reference).
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

            // Gentle mint bloom (top-trailing → drifts)
            RadialGradient(
                colors: [
                    HomeUI1Color.ambientMint.opacity(0.9),
                    Color.clear
                ],
                center: UnitPoint(x: 0.82 - drift * 0.32, y: 0.18 + drift * 0.22),
                startRadius: 24,
                endRadius: 340
            )

            // Soft warm pool (bottom-leading → drifts)
            RadialGradient(
                colors: [
                    HomeUI1Color.ambientWarm.opacity(0.75),
                    Color.clear
                ],
                center: UnitPoint(x: 0.16 + drift * 0.28, y: 0.78 - drift * 0.18),
                startRadius: 16,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }
}
