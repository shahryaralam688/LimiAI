//
//  HomeUI5Tokens.swift
//  LIMI AI Device — Home UI 5 Minimal large tiles
//

import SwiftUI

enum HomeUI5Color {
    static let canvas = Color(hex: "FAFAF8")
    static let tile = Color.white
    static let accent = Color(hex: "0F766E")
    static let text = Color(hex: "111827")
    static let secondary = Color(hex: "6B7280")
}

enum HomeUI5Radius {
    static let tile: CGFloat = 28
}

enum HomeUI5Type {
    static let hero = Font.system(size: 32, weight: .bold, design: .rounded)
    static let tileTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let caption = Font.system(size: 14, weight: .medium, design: .rounded)
}
