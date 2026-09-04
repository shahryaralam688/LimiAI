import SwiftUI
import UIKit

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

// MARK: - Brand Gradients (single source for CTAs)

enum LimiGradients {
    static let ctaColors: [Color] = [.brandAction, .brandActionDark]

    static var cta: LinearGradient {
        LinearGradient(colors: ctaColors, startPoint: .leading, endPoint: .trailing)
    }

    static var ctaVertical: LinearGradient {
        LinearGradient(colors: ctaColors, startPoint: .top, endPoint: .bottom)
    }

    /// Animated borders / orb rings — emerald + eton only
    static let accentRingColors: [Color] = [
        .brandHighlight, .brandAction, .brandActionDark, .brandHighlight
    ]

    /// Subtle weather / hero tint on dark cards (collapsed home weather)
    static var weatherAccent: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandHighlight.opacity(0.14),
                Color.brandAction.opacity(0.06),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// iOS-style card tokens — one family for Home grids, weather, modules.
enum LimiCard {
    static let radius: CGFloat = 16
    static let radiusLarge: CGFloat = 20
    static let moduleMinHeight: CGFloat = 110
    static let weatherCompactHeight: CGFloat = 80
    static let weatherExpandedHeight: CGFloat = 200
}

extension View {
    /// Standard dark canvas behind screen content.
    func limiScreenBackground(showParticles: Bool = false) -> some View {
        background(DeepSpaceBackground(showParticles: showParticles))
    }
}

// MARK: - Brand Typography (Amenti headings + Poppins body)

enum LimiFont {
    enum Amenti {
        static let thin = "Amenti-Thin"
        static let light = "Amenti-Light"
        static let regular = "Amenti-Regular"
        static let medium = "Amenti-Medium"
        static let bold = "Amenti-Bold"
        static let black = "Amenti-Black"
    }

    enum Poppins {
        static let regular = "Poppins-Regular"
        static let medium = "Poppins-Medium"
        static let semiBold = "Poppins-SemiBold"
        static let bold = "Poppins-Bold"
        static let light = "Poppins-Light"
    }

    static func amenti(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:
            name = LimiFont.Amenti.black
        case .bold:
            name = LimiFont.Amenti.bold
        case .medium, .semibold:
            name = LimiFont.Amenti.medium
        case .light, .thin, .ultraLight:
            name = LimiFont.Amenti.light
        default:
            name = LimiFont.Amenti.regular
        }
        return custom(name, size: size, weight: weight, fallbackDesign: .rounded)
    }

    static func amentiMedium(size: CGFloat) -> Font {
        custom(LimiFont.Amenti.medium, size: size, weight: .medium, fallbackDesign: .rounded)
    }

    static func poppins(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = LimiFont.Poppins.bold
        case .semibold:
            name = LimiFont.Poppins.semiBold
        case .medium:
            name = LimiFont.Poppins.medium
        case .light, .thin, .ultraLight:
            name = LimiFont.Poppins.light
        default:
            name = LimiFont.Poppins.regular
        }
        return custom(name, size: size, weight: weight, fallbackDesign: .default)
    }

    private static func custom(
        _ name: String,
        size: CGFloat,
        weight: Font.Weight,
        fallbackDesign: Font.Design
    ) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: fallbackDesign)
    }
}

/// App-wide type scale, mapped to Apple's semantic text styles so every token
/// scales automatically with Dynamic Type (accessibility) and adapts to the
/// device's optical sizing. Display/heading/action tokens use SF Pro Rounded to
/// pair with the app's soft neumorphic surfaces; text tokens use SF Pro.
///
/// Token names are stable — screens keep calling `LimiTypography.body` etc.
enum LimiTypography {
    // Display & headings — SF Pro Rounded.
    static let largeTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    static let title: Font = .system(.title, design: .rounded, weight: .bold)
    static let title2: Font = .system(.title2, design: .rounded, weight: .semibold)
    static let title3: Font = .system(.title3, design: .rounded, weight: .semibold)
    static let headline: Font = .system(.headline, design: .rounded, weight: .semibold)

    // Body & secondary text — SF Pro. Slightly heavier weights improve
    // legibility on low-contrast neumorphic backgrounds.
    static let body: Font = .system(.body, design: .default, weight: .regular)
    static let callout: Font = .system(.callout, design: .default, weight: .medium)
    static let subheadline: Font = .system(.subheadline, design: .default, weight: .regular)
    static let footnote: Font = .system(.footnote, design: .default, weight: .medium)
    static let caption: Font = .system(.caption, design: .default, weight: .medium)
    static let caption2: Font = .system(.caption2, design: .default, weight: .medium)

    /// Primary CTA label.
    static let button: Font = .system(.headline, design: .rounded, weight: .semibold)
    /// Secondary pill / compact actions.
    static let buttonSmall: Font = .system(.subheadline, design: .rounded, weight: .semibold)
}

/// Standard SF Symbol sizes — use instead of ad‑hoc `.font(.system(size: …))`.
enum LimiIconSize {
    static let tabBar: CGFloat = 18
    static let inline: CGFloat = 20
    static let deviceRow: CGFloat = 24
    static let section: CGFloat = 40
    static let hero: CGFloat = 56
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
                            Color.themeWhite.opacity(0),
                            Color.appGlassFillMedium,
                            Color.themeWhite.opacity(0)
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

    /// Standard elevated panel — replaces flat `appSurfaceSecondaryAlt` blocks.
    func limiPanel(cornerRadius: CGFloat = LimiRadius.medium) -> some View {
        glassCard(cornerRadius: cornerRadius)
    }

    /// Home screen module / weather compact card — same neumorphic glass as the grid.
    func limiHomeCard(cornerRadius: CGFloat = LimiCard.radius) -> some View {
        glassCard(cornerRadius: cornerRadius)
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

    private let accentGlow = Color.brandHighlight
    private let coreGlow = Color.brandAction

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Ambient glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentGlow.opacity(isActive ? 0.25 : 0.10),
                                coreGlow.opacity(isActive ? 0.15 : 0.05),
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
                                accentGlow.opacity(0.5),
                                coreGlow.opacity(0.3),
                                accentGlow.opacity(0.15),
                                coreGlow.opacity(0.5),
                                accentGlow.opacity(0.5)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(rotation))
                    .blur(radius: 0.5)

                // 3D geodesic orb scene
                LimiOrbScene(isActive: isActive, size: size, renderMode: .swiftUI)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.appGlassStrokeStrong,
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
                                        accentGlow.opacity(0.4),
                                        coreGlow.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: accentGlow.opacity(isActive ? 0.6 : 0.3), radius: isActive ? 24 : 12)
                    .shadow(color: coreGlow.opacity(isActive ? 0.4 : 0.2), radius: isActive ? 40 : 20)
                    .scaleEffect(breathe ? 1.02 : 0.98)

                // Specular highlight dot
                Circle()
                    .fill(Color.themeWhite.opacity(pulseGlow ? 0.18 : 0.08))
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
                .font(LimiTypography.callout)
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(LimiTypography.footnote)
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
                .font(LimiTypography.body)
                .foregroundColor(.appTextPrimary)
                .padding(.leading, 16)
                .padding(.vertical, 14)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(LimiTypography.headline)
                    .foregroundColor(.appCanvasPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(LimiGradients.cta)
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .glassCard(cornerRadius: 24, strokeOpacity: 0.1, fillOpacity: 0.08)
        .shadow(color: Color.brandAction.opacity(0.08), radius: 20, y: 8)
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
            .fill(Color.brandHighlight.opacity(opacity))
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
                    Color.brandHighlight.opacity(0.06),
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

/// Standard full-screen shell — canvas + optional content.
struct LimiScreen<Content: View>: View {
    var showParticles: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            DeepSpaceBackground(showParticles: showParticles)
            content()
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

    private var effectiveEnabled: Bool { isEnabled && !isLoading }

    var body: some View {
        Button(action: {
            guard effectiveEnabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            ZStack {
                Text(title)
                    .font(LimiTypography.button)
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
            .foregroundColor(effectiveEnabled ? .appTextInverse : .appTextDisabled)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        effectiveEnabled
                        ? AnyShapeStyle(LimiGradients.cta)
                        : AnyShapeStyle(Color.appGlassFillMedium)
                    )
            )
            .clipShape(Capsule(style: .continuous))
            .padding(5)
            .frame(height: height)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(LimiPrimaryCapsuleButtonStyle())
        .disabled(!effectiveEnabled)
        .animation(LimiMotion.quick, value: isLoading)
    }
}

private struct LimiPrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .neuElevationCapsule(level: configuration.isPressed ? -1 : 1)
            .animation(LimiMotion.quick, value: configuration.isPressed)
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
                    .font(LimiTypography.button)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundColor(.appTextInverse)
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
                .font(LimiTypography.button)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(.appTextPrimary)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.appGlassStrokeStrong, lineWidth: 1)
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
                .font(LimiTypography.buttonSmall)
                .foregroundColor(isFilled ? .white : .appTextPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isFilled {
                            Capsule(style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.brandAction, .brandActionDark],
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
