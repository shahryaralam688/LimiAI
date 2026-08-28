//
//  HomeUI1Tokens.swift
//  LIMI AI Device — Home UI 1 (default)
//
//  Dark charcoal-green neumorphism — soft dual shadows on a matte green-black canvas.
//

import SwiftUI

enum HomeUI1Color {
    /// Main canvas — charcoal green-black
    static let canvas = Color(hex: "1A201E")
    /// Raised neumorphic material (same plane as canvas; depth from shadows)
    static let surface = Color(hex: "1E2422")
    /// Slightly lifted plane for nested wells
    static let surfaceRaised = Color(hex: "252B28")
    /// Deep well for inset controls
    static let well = Color(hex: "151A18")
    /// Subtle warm charcoal wash for animated ambient canvas
    static let ambientWarm = Color(hex: "232A27")
    /// Deep emerald pool — desaturated accent glow
    static let ambientMint = Color(hex: "172420")
    /// Primary copy on dark
    static let textPrimary = Color(hex: "E8EDEA")
    /// Secondary / metadata
    static let textSecondary = Color(hex: "8A9490")
    /// Brand green — brighter for dark surfaces
    static let accentGreen = Color(hex: "12C488")
    /// Warm accent for primary CTAs (reference play-button orange)
    static let accentWarm = Color(hex: "F97316")
    /// Destructive / alert red
    static let accentRed = Color(hex: "F87171")
    /// Top-left highlight edge (charcoal lift, not pure white)
    static let shadowLight = Color(hex: "38423E")
    /// Bottom-right depth shadow
    static let shadowDark = Color(hex: "0A0E0C")

    // Semantic aliases used by Home UI 1 chrome
    static let primary = accentGreen
    static let focus = accentGreen
    static let success = accentGreen
    static let warning = Color(hex: "FBBF24")
    static let error = accentRed
    static let border = Color(hex: "2F3834")
}

enum HomeUI1Radius {
    /// --radius: 20px
    static let sm: CGFloat = 10
    static let md: CGFloat = 20
    static let lg: CGFloat = 20
    static let nav: CGFloat = 15
    static let pill: CGFloat = 999
}

enum HomeUI1Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40
}

/// Nunito — same family as premium-v13.html (400 / 600 / 700 / 800).
enum HomeUI1Type {
    /// h1 ≈ clamp(2.5rem…3.5rem) → 40pt display
    static func display(_ size: CGFloat = 40) -> Font {
        .custom("Nunito-ExtraBold", size: size)
    }

    /// h2 = 2.25rem (36) / h3 = 1.5rem (24) / logo = 1.5rem bold
    static func title(_ size: CGFloat = 24) -> Font {
        .custom("Nunito-Bold", size: size)
    }

    /// h4 = 1.125rem (18) / body emphasis
    static func body(_ size: CGFloat = 16) -> Font {
        .custom("Nunito-SemiBold", size: size)
    }

    /// Body regular 16 / captions
    static func regular(_ size: CGFloat = 16) -> Font {
        .custom("Nunito-Regular", size: size)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .custom("Nunito-Regular", size: size)
    }

    /// Logo / heavy labels (font-weight 800)
    static func logo(_ size: CGFloat = 24) -> Font {
        .custom("Nunito-ExtraBold", size: size)
    }
}

enum HomeUI1Motion {
    /// Warm, smooth springs for pressed states and tab changes
    static let soft = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let quick = Animation.spring(response: 0.28, dampingFraction: 0.88)
    static let standard = Animation.easeInOut(duration: 0.35)
    /// Slow ambient / canvas drift
    static let ambient = Animation.easeInOut(duration: 14)
}
