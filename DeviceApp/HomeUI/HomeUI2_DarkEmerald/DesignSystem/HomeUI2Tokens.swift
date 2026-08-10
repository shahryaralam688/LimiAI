//
//  HomeUI2Tokens.swift
//  LIMI AI Device — Home UI 2 (Dark emerald)
//
//  Dark emerald neumorphic system + motion tokens for UI feedback
//  (pressed / focus / success micro-interactions).
//  Visual direction aligned with product UI styleguide foundations:
//  https://www.pinterest.com/pin/1096274734320084795/
//

import SwiftUI

enum HomeUI2Color {
    static let canvas = Color(hex: "0B1F1A")
    static let surface = Color(hex: "12352C")
    static let surfaceRaised = Color(hex: "184539")
    static let primary = Color(hex: "2F9E7B")
    static let primaryDeep = Color(hex: "047857")
    static let focus = Color(hex: "34D399")
    static let textPrimary = Color(hex: "F2EBE3")
    static let textSecondary = Color(hex: "A7C2B8")
    static let border = Color(hex: "1E4A3D")
    static let success = Color(hex: "10B981")
    static let warning = Color(hex: "FBBF24")
    static let error = Color(hex: "F87171")
    static let shadowLight = Color(hex: "1A5C4A").opacity(0.55)
    static let shadowDark = Color.black.opacity(0.55)
}

enum HomeUI2Radius {
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let pill: CGFloat = 999
}

enum HomeUI2Spacing {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
}

enum HomeUI2Type {
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

/// Motion tokens for UI feedback (press / settle / focus ring).
enum HomeUI2Motion {
    static let press = Animation.easeOut(duration: 0.12)
    static let settle = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let focus = Animation.easeInOut(duration: 0.2)
    static let feedback = Animation.spring(response: 0.22, dampingFraction: 0.7)
}

struct HomeUI2ElevationModifier<S: Shape>: ViewModifier {
    let raised: Bool
    let shape: S
    var fill: Color = HomeUI2Color.surface

    func body(content: Content) -> some View {
        content
            .background(shape.fill(fill))
            .clipShape(shape)
            .overlay(shape.stroke(HomeUI2Color.border.opacity(0.65), lineWidth: 1))
            .shadow(
                color: raised ? HomeUI2Color.shadowLight : .clear,
                radius: raised ? 6 : 0,
                x: raised ? -3 : 0,
                y: raised ? -3 : 0
            )
            .shadow(
                color: HomeUI2Color.shadowDark,
                radius: raised ? 10 : 4,
                x: raised ? 4 : 1,
                y: raised ? 6 : 2
            )
    }
}

extension View {
    func homeUI2Raised(
        cornerRadius: CGFloat = HomeUI2Radius.md,
        fill: Color = HomeUI2Color.surface
    ) -> some View {
        modifier(
            HomeUI2ElevationModifier(
                raised: true,
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                fill: fill
            )
        )
    }

    func homeUI2Canvas() -> some View {
        background(HomeUI2Color.canvas.ignoresSafeArea())
    }
}
