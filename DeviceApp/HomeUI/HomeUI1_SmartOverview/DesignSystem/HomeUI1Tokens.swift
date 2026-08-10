//
//  HomeUI1Tokens.swift
//  LIMI AI Device — Home UI 1 (default)
//
//  Exact tokens from neumorphism/premium-v13.css:
//  --bg-main, --text-*, --accent-*, --shadow-*, Nunito, radius 20px.
//

import SwiftUI

enum HomeUI1Color {
    /// --bg-main
    static let canvas = Color(hex: "EDEDED")
    /// Same material as canvas (true neumorphism)
    static let surface = Color(hex: "EDEDED")
    /// Soft cream wash for animated ambient canvas (theme-safe, low contrast)
    static let ambientWarm = Color(hex: "F5F5EF")
    /// Pale mint wash — desaturated tint of accent green
    static let ambientMint = Color(hex: "E6F1EA")
    /// --text-primary
    static let textPrimary = Color(hex: "3D3D3D")
    /// --text-secondary
    static let textSecondary = Color(hex: "707070")
    /// --accent-green
    static let accentGreen = Color(hex: "10B981")
    /// --accent-red
    static let accentRed = Color(hex: "EF4444")
    /// --shadow-light
    static let shadowLight = Color(hex: "FFFFFF")
    /// --shadow-dark
    static let shadowDark = Color(hex: "C7C7C7")

    // Semantic aliases used by Home UI 1 chrome
    static let primary = accentGreen
    static let focus = accentGreen
    static let success = accentGreen
    static let warning = Color(hex: "FBBF24")
    static let error = accentRed
    static let border = shadowDark
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
    /// --transition: all 0.3s ease-in-out
    static let soft = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.3)
}
