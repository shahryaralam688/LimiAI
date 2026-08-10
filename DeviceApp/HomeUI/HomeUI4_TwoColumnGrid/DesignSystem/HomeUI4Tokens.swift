//
//  HomeUI4Tokens.swift
//  LIMI AI Device — Home UI 4 2-column grid
//

import SwiftUI

enum HomeUI4Color {
    static let canvas = Color(hex: "EEF2F0")
    static let card = Color.white
    static let accent = Color(hex: "54BB74")
    static let text = Color(hex: "222826")
    static let secondary = Color(hex: "6B766F")
}

enum HomeUI4Radius {
    static let card: CGFloat = 18
}

enum HomeUI4Type {
    static let title = Font.system(size: 26, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
}
