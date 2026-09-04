//
//  HomeUI1AnimatedCanvas.swift
//  LIMI AI Device — Home UI 1
//
//  Dark charcoal-green ambient gradient with a slow emerald glow drift.
//

import SwiftUI

/// Full-bleed ambient background for Home UI 1.
///
/// Rendered statically (no per-frame animation): the gradients are rasterized
/// once and cached, so stacking this behind multiple screens costs ~0 ongoing
/// GPU/CPU. A fixed `drift` picks a settled, balanced composition.
struct HomeUI1AnimatedCanvas: View {
    private let drift: CGFloat = 0.5

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
        .drawingGroup()
    }
}
