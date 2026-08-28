//
//  HomeUI2Tokens.swift
//  LIMI AI Device — Home UI 2 (Dark sage)
//
//  Design system matched to the shared dark smart-home reference:
//  black canvas, charcoal cards, muted sage accent, soft continuous radii.
//

import SwiftUI

enum HomeUI2Color {
    /// Pure black canvas.
    static let canvas = Color(hex: "000000")
    /// Charcoal card surface.
    static let surface = Color(hex: "1C1C1E")
    static let surfaceRaised = Color(hex: "2A2A2C")
    /// Muted sage / olive accent from the reference.
    static let accent = Color(hex: "889C81")
    static let accentDeep = Color(hex: "6F8369")
    static let accentSoft = Color(hex: "A3B39C")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "A1A1A6")
    static let textOnAccent = Color(hex: "121412")
    static let border = Color.white.opacity(0.12)
    static let sun = Color(hex: "F5C542")
    static let shadow = Color.black.opacity(0.45)
}

enum HomeUI2Radius {
    static let sm: CGFloat = 16
    static let md: CGFloat = 22
    static let lg: CGFloat = 28
    static let pill: CGFloat = 999
}

enum HomeUI2Spacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum HomeUI2Type {
    static func display(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func regular(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

enum HomeUI2Motion {
    static let soft = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let press = Animation.easeOut(duration: 0.12)
}

extension View {
    func homeUI2Card(
        cornerRadius: CGFloat = HomeUI2Radius.lg,
        fill: Color = HomeUI2Color.surface
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
