import SwiftUI
import Foundation

// MARK: - SplashScreen

struct SplashScreen: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("globalUserLocation") private var storedLocation = ""
    @AppStorage("locationPromptSkipped") private var locationPromptSkipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isActive = false
    @State private var choreographyTrigger = false
    @State private var showWordmark = false
    @Namespace private var logoMorph

    var body: some View {
        Group {
            if isActive {
                destinationView
                    .transition(.opacity)
            } else {
                splashContent
            }
        }
        .animation(.smooth(duration: 0.55), value: isActive)
        .trackScreen("SplashScreen", metadata: ["phase": "splash_or_routing"])
    }

    @ViewBuilder
    private var destinationView: some View {
        AppRouter.destination(
            for: AppRouter.rootRoute(
                isAuthenticated: authManager.isAuthenticated,
                hasLaunchedBefore: hasLaunchedBefore,
                hasCompletedOnboarding: hasCompletedOnboarding,
                storedLocationEmpty: storedLocation.isEmpty,
                locationPromptSkipped: locationPromptSkipped
            )
        )
    }

    @ViewBuilder
    private var splashContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if reduceMotion {
                SplashStaticLogo()
            } else {
                SplashMeshAtmosphere()
                SplashParticleField()
                SplashChoreographyLayer(
                    trigger: choreographyTrigger,
                    showWordmark: showWordmark,
                    logoMorph: logoMorph
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: beginSequence)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: showWordmark)
    }

    private func beginSequence() {
        if reduceMotion {
            showWordmark = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                finishAndRoute()
            }
            return
        }

        choreographyTrigger = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.62) {
            withAnimation(.smooth(duration: 0.55)) {
                showWordmark = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.45) {
            finishAndRoute()
        }
    }

    private func finishAndRoute() {
        hasLaunchedBefore = true
        withAnimation(.smooth(duration: 0.5)) {
            isActive = true
        }
    }
}

// MARK: - Static / Reduce Motion

private struct SplashStaticLogo: View {
    var body: some View {
        Image("IconWordmark_White")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(maxWidth: 220)
            .accessibilityLabel("Limi")
    }
}

// MARK: - Animation Values

private struct SplashAnimValues {
    var bloom: CGFloat = 0
    var markOpacity: CGFloat = 0
    var markScale: CGFloat = 0.68
    var markBlur: CGFloat = 22
    var wordmarkOpacity: CGFloat = 0
    var wordmarkScale: CGFloat = 0.9
    var wordmarkBlur: CGFloat = 14
    var ringPrimary: CGFloat = 0
    var ringSecondary: CGFloat = 0
    var contentOpacity: CGFloat = 1
    var contentScale: CGFloat = 1
}

// MARK: - Choreography

private struct SplashChoreographyLayer: View {
    let trigger: Bool
    let showWordmark: Bool
    let logoMorph: Namespace.ID

    var body: some View {
        KeyframeAnimator(
            initialValue: SplashAnimValues(),
            trigger: trigger
        ) { values in
            SplashAnimatedStage(
                values: values,
                showWordmark: showWordmark,
                logoMorph: logoMorph
            )
        } keyframes: { _ in
            KeyframeTrack(\.bloom) {
                CubicKeyframe(0.0, duration: 0.05)
                CubicKeyframe(1.0, duration: 0.75)
                CubicKeyframe(0.85, duration: 1.1)
                CubicKeyframe(0.55, duration: 0.9)
                CubicKeyframe(0.0, duration: 0.55)
            }
            KeyframeTrack(\.markOpacity) {
                CubicKeyframe(0.0, duration: 0.12)
                CubicKeyframe(1.0, duration: 0.55)
                CubicKeyframe(1.0, duration: 1.05)
                CubicKeyframe(0.0, duration: 0.38)
                CubicKeyframe(0.0, duration: 1.25)
            }
            KeyframeTrack(\.markScale) {
                CubicKeyframe(0.68, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.7, spring: .smooth(duration: 0.7, extraBounce: 0.08))
                CubicKeyframe(1.0, duration: 0.9)
                CubicKeyframe(1.14, duration: 0.38)
                CubicKeyframe(1.14, duration: 1.25)
            }
            KeyframeTrack(\.markBlur) {
                CubicKeyframe(22, duration: 0.12)
                CubicKeyframe(0, duration: 0.65)
                CubicKeyframe(0, duration: 0.95)
                CubicKeyframe(10, duration: 0.38)
                CubicKeyframe(10, duration: 1.25)
            }
            KeyframeTrack(\.wordmarkOpacity) {
                CubicKeyframe(0.0, duration: 1.55)
                CubicKeyframe(0.0, duration: 0.12)
                CubicKeyframe(1.0, duration: 0.55)
                CubicKeyframe(1.0, duration: 0.85)
                CubicKeyframe(0.0, duration: 0.55)
            }
            KeyframeTrack(\.wordmarkScale) {
                CubicKeyframe(0.9, duration: 1.55)
                SpringKeyframe(1.0, duration: 0.7, spring: .snappy(duration: 0.65, extraBounce: 0.05))
                CubicKeyframe(1.0, duration: 0.82)
                CubicKeyframe(1.05, duration: 0.55)
            }
            KeyframeTrack(\.wordmarkBlur) {
                CubicKeyframe(14, duration: 1.55)
                CubicKeyframe(0, duration: 0.55)
                CubicKeyframe(0, duration: 0.95)
                CubicKeyframe(6, duration: 0.55)
            }
            KeyframeTrack(\.ringPrimary) {
                CubicKeyframe(0.0, duration: 0.55)
                CubicKeyframe(1.0, duration: 1.25)
                CubicKeyframe(1.0, duration: 1.55)
            }
            KeyframeTrack(\.ringSecondary) {
                CubicKeyframe(0.0, duration: 0.95)
                CubicKeyframe(1.0, duration: 1.3)
                CubicKeyframe(1.0, duration: 1.1)
            }
            KeyframeTrack(\.contentOpacity) {
                CubicKeyframe(1.0, duration: 2.85)
                CubicKeyframe(0.0, duration: 0.55)
            }
            KeyframeTrack(\.contentScale) {
                CubicKeyframe(1.0, duration: 2.85)
                CubicKeyframe(1.06, duration: 0.55)
            }
        }
    }
}

private struct SplashAnimatedStage: View {
    let values: SplashAnimValues
    let showWordmark: Bool
    let logoMorph: Namespace.ID

    var body: some View {
        ZStack {
            SplashBloom(bloom: values.bloom)
            SplashRippleRing(progress: values.ringPrimary, bloom: values.bloom)
            SplashRippleRing(progress: values.ringSecondary, bloom: values.bloom)
            SplashLogoStage(
                values: values,
                showWordmark: showWordmark,
                logoMorph: logoMorph
            )
        }
        .scaleEffect(values.contentScale)
        .opacity(values.contentOpacity)
    }
}

private struct SplashBloom: View {
    let bloom: CGFloat

    var body: some View {
        let colors: [Color] = [
            Color.white.opacity(0.16 * bloom),
            Color.white.opacity(0.05 * bloom),
            Color.clear
        ]

        Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 4,
                    endRadius: 200
                )
            )
            .frame(width: 440, height: 440)
            .scaleEffect(0.92 + 0.18 * bloom)
            .blur(radius: 36)
            .allowsHitTesting(false)
    }
}

private struct SplashRippleRing: View {
    let progress: CGFloat
    let bloom: CGFloat

    var body: some View {
        let fade = 1 - progress
        Circle()
            .stroke(Color.white.opacity(0.22 * fade), lineWidth: 0.9)
            .frame(width: 108, height: 108)
            .scaleEffect(0.85 + progress * 1.35)
            .opacity(Double(bloom * fade))
            .allowsHitTesting(false)
    }
}

private struct SplashLogoStage: View {
    let values: SplashAnimValues
    let showWordmark: Bool
    let logoMorph: Namespace.ID

    var body: some View {
        ZStack {
            if showWordmark {
                wordmark
            } else {
                mark
            }
        }
    }

    private var mark: some View {
        Image("LogoIcon_White")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: 80, height: 68)
            .matchedGeometryEffect(id: "limiLogo", in: logoMorph)
            .scaleEffect(values.markScale)
            .blur(radius: values.markBlur)
            .opacity(values.markOpacity)
            .shadow(color: Color.white.opacity(0.18 * values.markOpacity), radius: 18, y: 0)
    }

    private var wordmark: some View {
        Image("IconWordmark_White")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(maxWidth: 236)
            .matchedGeometryEffect(id: "limiLogo", in: logoMorph)
            .scaleEffect(values.wordmarkScale)
            .blur(radius: values.wordmarkBlur)
            .opacity(max(values.wordmarkOpacity, 0.01))
            .shadow(color: Color.white.opacity(0.12 * values.wordmarkOpacity), radius: 22, y: 0)
            .accessibilityLabel("Limi")
    }
}

// MARK: - Living Mesh Atmosphere (iOS 18)

private struct SplashMeshAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            SplashMeshGradient(time: context.date.timeIntervalSinceReferenceDate)
        }
    }
}

private struct SplashMeshGradient: View {
    let time: TimeInterval

    var body: some View {
        let a = Float((sin(time * 0.55) + 1) * 0.5)
        let b = Float((cos(time * 0.38) + 1) * 0.5)
        let c = Float((sin(time * 0.27 + 1.2) + 1) * 0.5)
        let points = meshPoints(a: a, b: b)
        let colors = meshColors(c: c)

        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .ignoresSafeArea()
            .opacity(0.9)
            .allowsHitTesting(false)
    }

    private func meshPoints(a: Float, b: Float) -> [SIMD2<Float>] {
        [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5),
            SIMD2(0.35 + 0.18 * a, 0.42 + 0.12 * b),
            SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
        ]
    }

    private func meshColors(c: Float) -> [Color] {
        let highlight = Color.white.opacity(0.07 + 0.04 * Double(c))
        return [
            .black, .black, .black,
            .black, highlight, .black,
            .black, .black, .black
        ]
    }
}

// MARK: - Soft Particle Field

private struct SplashParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let phase: CGFloat
}

private struct SplashParticleField: View {
    private let particles: [SplashParticle] = {
        var rng = SeededGenerator(seed: 42)
        return (0..<18).map { index in
            SplashParticle(
                id: index,
                x: CGFloat.random(in: 0.08...0.92, using: &rng),
                y: CGFloat.random(in: 0.12...0.88, using: &rng),
                size: CGFloat.random(in: 1.2...2.6, using: &rng),
                speed: CGFloat.random(in: 0.22...0.55, using: &rng),
                phase: CGFloat.random(in: 0...(CGFloat.pi * 2), using: &rng)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawParticles(into: &ctx, size: size, time: t)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func drawParticles(into ctx: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for p in particles {
            let driftY = sin(time * Double(p.speed) + Double(p.phase)) * 10
            let driftX = cos(time * Double(p.speed * 0.7) + Double(p.phase)) * 6
            let pulse = 0.25 + 0.55 * (0.5 + 0.5 * sin(time * Double(p.speed) + Double(p.phase)))
            let rect = CGRect(
                x: p.x * size.width + driftX - p.size / 2,
                y: p.y * size.height + driftY - p.size / 2,
                width: p.size,
                height: p.size
            )
            ctx.opacity = pulse
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

#Preview {
    SplashScreen()
}
