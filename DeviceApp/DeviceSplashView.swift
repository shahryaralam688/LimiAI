//
//  DeviceSplashView.swift
//  LIMI AI Device — Soft UI splash.
//
//  Full-bleed lit pendant scene (faded) + logo / wordmark on top.
//  Lifecycle-safe for force-quit → relaunch.
//

import SwiftUI

struct DeviceSplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow: CGFloat = 0
    @State private var backgroundOpacity: Double = 0
    @State private var brandOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.92
    @State private var didFinish = false
    @State private var introTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            fullBleedBackground

            // Soft fade / vignette so logo stays readable
            fadeOverlay

            // Warm light bloom
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.18 * glow),
                    HomeUI1Color.accentGreen.opacity(0.08 * glow),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 480
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                brandBlock
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 72)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startIntro() }
        .onDisappear {
            introTask?.cancel()
            introTask = nil
        }
    }

    // MARK: - Full-bleed lit scene only (no dull / off image)

    private var fullBleedBackground: some View {
        ZStack {
            HomeUI1Color.canvas.ignoresSafeArea()

            if UIImage(named: "HomeUI1PendantOn") != nil {
                Image("HomeUI1PendantOn")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            }
        }
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Darken / fade the photo so Soft UI logo sits cleanly on top.
    private var fadeOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HomeUI1Color.canvas.opacity(0.22)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Logo / brand on top

    private var brandBlock: some View {
        VStack(spacing: 14) {
            Group {
                if UIImage(named: "IconWordmark_White") != nil {
                    Image("IconWordmark_White")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                } else {
                    Text("LIMI")
                        .font(HomeUI1Type.logo(40))
                        .foregroundStyle(HomeUI1Color.textPrimary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.lg, fill: HomeUI1Color.surface.opacity(0.82))
            .scaleEffect(logoScale)
            .opacity(brandOpacity)

            Text("AI Device")
                .font(HomeUI1Type.body(15))
                .foregroundStyle(HomeUI1Color.accentGreen)
                .opacity(brandOpacity)

            Text("Your lights. Ready.")
                .font(HomeUI1Type.regular(14))
                .foregroundStyle(HomeUI1Color.textPrimary.opacity(0.92))
                .multilineTextAlignment(.center)
                .opacity(taglineOpacity)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
        }
    }

    // MARK: - Choreography

    private func startIntro() {
        introTask?.cancel()
        didFinish = false
        glow = 0
        backgroundOpacity = 0
        brandOpacity = 0
        taglineOpacity = 0
        logoScale = 0.92

        if reduceMotion {
            glow = 1
            backgroundOpacity = 1
            brandOpacity = 1
            taglineOpacity = 1
            logoScale = 1
            introTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                finishOnce()
            }
            return
        }

        introTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.7)) {
                backgroundOpacity = 1
                glow = 1
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                brandOpacity = 1
                logoScale = 1
            }
            withAnimation(.easeOut(duration: 0.4)) {
                taglineOpacity = 1
            }

            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            finishOnce()
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

#Preview {
    DeviceSplashView(onFinished: {})
}
