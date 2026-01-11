import SwiftUI

struct GlowOrbView: View {
    @State private var pulse = false
    @State private var rotate = false
    @State private var twinkle = false
    @State private var orbitRotation1: Double = 0

    var body: some View {
        ZStack {
            // Soft green halo
            Circle()
                .fill(Color(#colorLiteral(red: 0.23, green: 0.78, blue: 0.54, alpha: 1)).opacity(0.35))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .scaleEffect(pulse ? 1.08 : 0.95)

            // Main orb (radial gradient core)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white,
                            Color(red: 0.49, green: 0.93, blue: 1.0),
                            Color(red: 0.13, green: 0.9, blue: 0.53),
                            Color(red: 0.13, green: 0.9, blue: 0.53).opacity(0.2)
                        ]),
                        center: .center,
                        startRadius: 2,
                        endRadius: 120
                    )
                )
                .frame(width: 160, height: 160)
                .overlay(
                    // Golden rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 0.3)
                )
                .shadow(color: .white.opacity(0.9), radius: 12)
                .shadow(color: Color.green.opacity(0.35), radius: 28)
                .scaleEffect(pulse ? 1.06 : 0.98)

            // Rotating spectral sweep for extra life
            AngularSweep()
                .frame(width: 162, height: 162)
                .clipShape(Circle())
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .opacity(0.55)
                .blendMode(.screen)

            // Tiny twinkling sparkles inside the orb
            Sparkles(seed: 7)
                .frame(width: 150, height: 150)
                .blendMode(.screen)
                .opacity(twinkle ? 0.95 : 0.75)
            
            // Orbiting small circles with different starting positions
            OrbitingCircle(
                color: Color.clear,
                icon: "Sensors.35",
                radius: 140,
                size: 50,
                rotation: orbitRotation1,
                startPhase: 0  // starts at top
            )
            
            OrbitingCircle(
                color: Color.clear,
                icon: "Sensors.40",
                radius: 120,
                size: 45,
                rotation: orbitRotation1,
                startPhase: 90  // starts at bottom-left
            )
            
            OrbitingCircle(
                color: Color.clear,
                icon: "Sensors.37",
                radius: 130,
                size: 48,
                rotation: orbitRotation1,
                startPhase: 180  // starts at bottom-right
            )
            OrbitingCircle(
                color: Color.clear,
                icon: "Sensors.38",
                radius: 130,
                size: 48,
                rotation: orbitRotation1,
                startPhase: 270  // starts at bottom-right
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                twinkle = true
            }
            
            // Different orbit speeds for each circle
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                orbitRotation1 = 360
            }

        }
    }
}

/// Orbiting circle that rotates around the GlowOrbView center (circular path)
private struct OrbitingCircle: View {
    let color: Color
    let icon: String
    let radius: CGFloat   // distance from center to the circle center
    let size: CGFloat
    let rotation: Double  // degrees 0...360
    let startPhase: Double // starting position offset in degrees
    
    @State private var internalRotation: Double = 0
    
    var body: some View {
        let initialRotation = rotation
        
        return ZStack {
            // Circle background with glow
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(internalRotation)) // spin itself
            
                .shadow(color: color.opacity(0.6), radius: 8)
                .shadow(color: color.opacity(0.3), radius: 16)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        internalRotation = 360
                    }
                }
            // Icon inside
            Image(icon)
                .resizable()
            
                .frame(width: size * 1.5, height: size * 1.5)
            
        }
        .offset(y: -radius)                           // place at top of the orbit
        .rotationEffect(.degrees(initialRotation + startPhase)) // spin around center with phase offset
        .zIndex(1)                                    // keep above the main orb
        .allowsHitTesting(false)                      // decorative
    }
}
private struct EllipticalOrbitingCircle: View {
    let color: Color
    let icon: String
    let radiusX: CGFloat  // horizontal radius
    let radiusY: CGFloat  // vertical radius
    let size: CGFloat
    let rotation: Double  // degrees 0...360
    let phase: Double = 0 // start offset in degrees

    @State private var internalSpin: Double = 0

    var body: some View {
        let theta = (rotation + phase) * .pi / 180
        return ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.6), radius: 8)
                .shadow(color: color.opacity(0.3), radius: 16)

            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.white)
        }
        .rotationEffect(.degrees(internalSpin))
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                internalSpin = 360
            }
        }
        .offset(x:  radiusX * cos(theta),
                y:  radiusY * sin(theta))
        .zIndex(1)
        .allowsHitTesting(false)
    }
}

/// A subtle rotating band of light (like the inner rainbow sheen)
private struct AngularSweep: View {
    var body: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.0), location: 0.00),
                        .init(color: .white.opacity(0.15), location: 0.08),
                        .init(color: .white.opacity(0.35), location: 0.12),
                        .init(color: .white.opacity(0.0), location: 0.18),
                        .init(color: Color.emerald.opacity(0.25), location: 0.28),
                        .init(color: Color.eton.opacity(0.25), location: 0.35),
                        .init(color: .white.opacity(0.0), location: 0.45),
                        .init(color: .white.opacity(0.2), location: 0.52),
                        .init(color: .white.opacity(0.0), location: 0.60),
                        .init(color: .white.opacity(0.0), location: 1.00)
                    ]),
                    center: .center
                ),
                lineWidth: 20
            )
            .blur(radius: 6)
    }
}

/// Little star-like sparkles that gently twinkle.
private struct Sparkles: View {
    let seed: Int
    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                var gen = RandomNumberGeneratorWithSeed(seed)
                let points = (0..<14).map { _ in
                    CGPoint(
                        x: CGFloat.random(in: 0...size.width, using: &gen),
                        y: CGFloat.random(in: 0...size.height, using: &gen)
                    )
                }

                for (i, p) in points.enumerated() {
                    let phase = sin(t * 1.2 + Double(i) * 0.9)
                    let alpha = 0.25 + 0.45 * abs(phase)
                    let r: CGFloat = 1.2 + 1.6 * CGFloat(abs(phase))
                    var star = Path()
                    star.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    context.fill(star, with: .color(Color.white.opacity(alpha)))
                }
            }
        }
    }
}

/// Deterministic RNG so sparkles keep their positions.
private struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: Int) { self.state = UInt64(seed) &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GlowOrbView()
    }
}
