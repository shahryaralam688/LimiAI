import SwiftUI

// MARK: - Limi Neumorphic Engine — Single Source of Truth

enum NeuTheme {
    static let baseCanvas   = Color(hex: "0B0B0F")
    static let baseSurface  = Color(hex: "131318")

    static let shadowLight  = Color(hex: "1C1C26")
    static let shadowDark   = Color.black.opacity(0.8)

    static let accentEdge   = Color.white.opacity(0.05)
}

// MARK: - Elevation Modifier

struct NeuElevationModifier<S: Shape>: ViewModifier {
    let level: Int
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        switch level {
        case 1:
            raisedBody(content: content)
        case -1:
            recessedBody(content: content)
        default:
            baseBody(content: content)
        }
    }

    // MARK: Level 1 — Raised

    private func raisedBody(content: Content) -> some View {
        content
            .background(shape.fill(NeuTheme.baseSurface))
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [NeuTheme.accentEdge, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: NeuTheme.shadowLight, radius: 8, x: -4, y: -4)
            .shadow(color: NeuTheme.shadowDark, radius: 10, x: 4, y: 4)
            .drawingGroup()
    }

    // MARK: Level -1 — Recessed

    private func recessedBody(content: Content) -> some View {
        content
            .background(shape.fill(NeuTheme.baseCanvas))
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.clear,
                                NeuTheme.shadowLight.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .clipShape(shape)
            .scaleEffect(0.98)
            .drawingGroup()
    }

    // MARK: Level 0 — Base

    private func baseBody(content: Content) -> some View {
        content
            .background(shape.fill(NeuTheme.baseCanvas))
            .clipShape(shape)
    }
}

// MARK: - View Extensions

extension View {

    func neuElevation(level: Int, cornerRadius: CGFloat = 16) -> some View {
        modifier(NeuElevationModifier(
            level: level,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ))
    }

    func neuElevationCircle(level: Int) -> some View {
        modifier(NeuElevationModifier(level: level, shape: Circle()))
    }

    func neuElevationCapsule(level: Int) -> some View {
        modifier(NeuElevationModifier(level: level, shape: Capsule(style: .continuous)))
    }

    func applyLimiBackground() -> some View {
        self.background(NeuTheme.baseCanvas.ignoresSafeArea())
    }
}

// MARK: - Legacy API Bridge

extension View {

    func neuCard(cornerRadius: CGFloat = 16, isPressed: Bool = false) -> some View {
        neuElevation(level: isPressed ? -1 : 1, cornerRadius: cornerRadius)
            .animation(LimiMotion.quick, value: isPressed)
    }

    func neuCircle(isPressed: Bool = false) -> some View {
        neuElevationCircle(level: isPressed ? -1 : 1)
            .animation(LimiMotion.quick, value: isPressed)
    }

    func neuCapsule(isPressed: Bool = false) -> some View {
        neuElevationCapsule(level: isPressed ? -1 : 1)
            .animation(LimiMotion.quick, value: isPressed)
    }

    func neuCapsuleSocket() -> some View {
        neuElevationCapsule(level: -1)
    }

    func neuCarvedField(cornerRadius: CGFloat = 16) -> some View {
        neuElevation(level: -1, cornerRadius: cornerRadius)
    }
}
