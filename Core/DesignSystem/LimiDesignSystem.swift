import SwiftUI

// MARK: - Design Tokens

enum LimiRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let extraLarge: CGFloat = 24
}

enum LimiSpacing {
    static let screenHorizontal: CGFloat = 20
    static let screenTop: CGFloat = 56
    static let sectionGap: CGFloat = 24
    static let itemGap: CGFloat = 16
    static let innerPadding: CGFloat = 14
    /// Bottom inset so scroll content clears the global floating voice orb.
    static let floatingOrbClearance: CGFloat = 100
}

enum LimiTypography {
    static let largeTitle: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let title: Font = .system(size: 24, weight: .bold, design: .rounded)
    static let title2: Font = .system(size: 22, weight: .semibold, design: .rounded)
    static let title3: Font = .system(size: 20, weight: .semibold, design: .rounded)
    static let headline: Font = .system(size: 17, weight: .semibold, design: .rounded)
    static let body: Font = .system(size: 16, weight: .regular, design: .rounded)
    static let callout: Font = .system(size: 15, weight: .medium, design: .rounded)
    static let subheadline: Font = .system(size: 14, weight: .regular, design: .rounded)
    static let footnote: Font = .system(size: 13, weight: .medium, design: .rounded)
    static let caption: Font = .system(size: 12, weight: .medium, design: .rounded)
    static let caption2: Font = .system(size: 11, weight: .medium, design: .rounded)
}

// MARK: - Motion Constants (Arc-inspired physics)

enum LimiMotion {
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let gentle = Animation.spring(response: 0.7, dampingFraction: 0.75)
    static let breathe = Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true)
    static let appear = Animation.easeOut(duration: 0.5)
    static let stagger: (Int) -> Animation = { index in
        .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)
    }
}

// MARK: - Appear Animation Modifier

struct LimiAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(LimiMotion.smooth.delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func limiAppear(delay: Double = 0) -> some View {
        modifier(LimiAppearModifier(delay: delay))
    }
}

// MARK: - Shimmer Loading Modifier

struct LimiShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1.5
                        }
                    }
                }
                .clipped()
            )
    }
}

extension View {
    func limiShimmer() -> some View {
        modifier(LimiShimmerModifier())
    }
}

// MARK: - Glass Card Modifier

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var strokeOpacity: Double = 0.08
    var fillOpacity: Double = 0.06
    var blurRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content.modifier(NeuElevationModifier(
            level: 1,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ))
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        strokeOpacity: Double = 0.08,
        fillOpacity: Double = 0.06,
        blur: CGFloat = 0
    ) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Tap Scale Effect

struct TapScaleEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func tapScale() -> some View {
        modifier(TapScaleEffect())
    }
}

// MARK: - Limi Floating Orb (main AI entry point — Neural Sphere)

struct LimiOrbView: View {
    var size: CGFloat = 72
    var isActive: Bool = false
    var onTap: () -> Void = {}

    @State private var breathe = false
    @State private var rotation: Double = 0
    @State private var pulseGlow = false

    private let cyanAccent  = Color(hex: "00E5FF")
    private let violetCore  = Color(hex: "9B5DE5")
    private let deepViolet  = Color(hex: "6A1B9A")

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Ambient glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                cyanAccent.opacity(isActive ? 0.25 : 0.10),
                                violetCore.opacity(isActive ? 0.15 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.25,
                            endRadius: size * 1.3
                        )
                    )
                    .frame(width: size * 2.4, height: size * 2.4)
                    .scaleEffect(breathe ? 1.06 : 0.94)

                // Outer glass shell ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                cyanAccent.opacity(0.5),
                                violetCore.opacity(0.3),
                                cyanAccent.opacity(0.15),
                                violetCore.opacity(0.5),
                                cyanAccent.opacity(0.5)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(rotation))
                    .blur(radius: 0.5)

                // Neural sphere image
                Image("neuralOrb")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        cyanAccent.opacity(0.4),
                                        violetCore.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: cyanAccent.opacity(isActive ? 0.6 : 0.3), radius: isActive ? 24 : 12)
                    .shadow(color: violetCore.opacity(isActive ? 0.4 : 0.2), radius: isActive ? 40 : 20)
                    .scaleEffect(breathe ? 1.02 : 0.98)

                // Specular highlight dot
                Circle()
                    .fill(Color.white.opacity(pulseGlow ? 0.18 : 0.08))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .offset(x: -size * 0.14, y: -size * 0.14)
                    .blur(radius: 3)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}

// MARK: - Section Header

struct LimiSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextMuted)
            }
        }
    }
}

// MARK: - Glassmorphic Floating Input

struct FloatingInputBar: View {
    @Binding var text: String
    var placeholder: String = "Message Limi..."
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.appTextPlaceholder))
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.appTextPrimary)
                .padding(.leading, 16)
                .padding(.vertical, 14)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appCanvasPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orbGlow4, .orbGlow1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .glassCard(cornerRadius: 24, strokeOpacity: 0.1, fillOpacity: 0.08)
        .shadow(color: Color.orbGlow1.opacity(0.08), radius: 20, y: 8)
    }
}

// MARK: - Ambient Particles Background

struct AmbientParticlesView: View {
    let count: Int

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                ParticleDot(index: i, bounds: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ParticleDot: View {
    let index: Int
    let bounds: CGSize
    @State private var offset: CGPoint = .zero
    @State private var opacity: Double = 0

    private var particleSize: CGFloat {
        CGFloat.random(in: 1...3)
    }

    var body: some View {
        Circle()
            .fill(Color.orbGlow3.opacity(opacity))
            .frame(width: particleSize, height: particleSize)
            .position(x: offset.x, y: offset.y)
            .onAppear {
                offset = CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height)
                )
                let duration = Double.random(in: 6...14)
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    opacity = Double.random(in: 0.15...0.4)
                    offset = CGPoint(
                        x: CGFloat.random(in: 0...bounds.width),
                        y: CGFloat.random(in: 0...bounds.height)
                    )
                }
            }
    }
}

// MARK: - Deep Space Background

struct DeepSpaceBackground: View {
    var showParticles: Bool = true

    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()

            // Subtle radial gradient at top
            RadialGradient(
                colors: [
                    Color.orbGlow2.opacity(0.06),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.15),
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            if showParticles {
                AmbientParticlesView(count: 20)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Fade-slide transition

extension AnyTransition {
    static var fadeSlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
}

// MARK: - Unified Button System

/// Circular icon button — 44×44 raised neumorphic circle with press state
struct LimiIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 18
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.appTextPrimary)
                .frame(width: size, height: size)
                .neuCircle(isPressed: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Primary CTA — emerald gradient with neumorphic elevation toggle
struct LimiPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var height: CGFloat = 52
    var action: () -> Void

    @State private var isPressed = false
    private var effectiveEnabled: Bool { isEnabled && !isLoading }

    var body: some View {
        Button(action: {
            guard effectiveEnabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height - 10)
            .foregroundColor(effectiveEnabled ? .white : .appTextDisabled)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        effectiveEnabled
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.orbGlow4, .orbGlow1],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        : AnyShapeStyle(Color.white.opacity(0.06))
                    )
            )
            .clipShape(Capsule(style: .continuous))
            .padding(5)
        }
        .frame(height: height)
        .neuElevationCapsule(level: isPressed ? -1 : 1)
        .animation(LimiMotion.quick, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(!effectiveEnabled)
        .animation(LimiMotion.quick, value: isLoading)
    }
}

/// Danger CTA — full-width danger capsule for destructive actions
struct LimiDangerButton: View {
    let title: String
    var isLoading: Bool = false
    var height: CGFloat = 52
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundColor(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.appDanger)
            )
        }
        .disabled(isLoading)
        .tapScale()
    }
}

/// Secondary CTA — outline style, same dimensions as primary
struct LimiSecondaryButton: View {
    let title: String
    var height: CGFloat = 52
    var action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(.appTextPrimary)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .tapScale()
    }
}

/// Small pill button — raised when off (isFilled=false), sunken when on (isFilled=true)
struct LimiPillButton: View {
    let title: String
    var isFilled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFilled ? .white : .appTextPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isFilled {
                            Capsule(style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.orbGlow4, .orbGlow1],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        } else {
                            Capsule(style: .continuous)
                                .fill(Color.clear)
                        }
                    }
                )
        }
        .neuCapsule(isPressed: isFilled)
        .animation(LimiMotion.quick, value: isFilled)
    }
}

/// Standard screen header with back button + title
struct LimiScreenHeader: View {
    let title: String
    var showsCloseButton: Bool = true
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if showsCloseButton {
                LimiBackButton(icon: "xmark", action: onBack)
                    .accessibilityLabel("Close")
            }
            Text(title)
                .font(LimiTypography.title)
                .foregroundColor(.appTextPrimary)
            Spacer()
        }
        .padding(.horizontal, LimiSpacing.screenHorizontal)
        .padding(.top, LimiSpacing.screenTop)
        .padding(.bottom, 12)
    }
}

// MARK: - Unified Text Field

struct LimiTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.appTextPlaceholder))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.appTextPlaceholder))
                    .keyboardType(keyboardType)
            }
        }
        .textFieldStyle(.plain)
        .font(LimiTypography.body)
        .foregroundColor(.appTextPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .neuCarvedField(cornerRadius: CGFloat(LimiRadius.medium))
    }
}
