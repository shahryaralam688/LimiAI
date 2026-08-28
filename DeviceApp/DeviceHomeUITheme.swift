//
//  DeviceHomeUITheme.swift
//  LIMI AI Device
//
//  Home UI theme store. App is locked to Home UI 1 (theme picker removed).
//

import SwiftUI

enum DeviceHomeUIVariant: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    var id: Int { rawValue }

    var title: String { "Home UI \(rawValue)" }

    var subtitle: String {
        switch self {
        case .one: return "Smart overview (current)"
        case .two: return "Dark sage home"
        case .three: return "Clean list"
        case .four: return "2-column grid"
        case .five: return "Minimal large tiles"
        }
    }

    var systemImage: String {
        switch self {
        case .one: return "1.circle.fill"
        case .two: return "2.circle.fill"
        case .three: return "3.circle.fill"
        case .four: return "4.circle.fill"
        case .five: return "5.circle.fill"
        }
    }

    /// Folder that owns this variant's system + views.
    var folderName: String {
        switch self {
        case .one: return "HomeUI1_SmartOverview"
        case .two: return "HomeUI2_DarkEmerald"
        case .three: return "HomeUI3_CleanList"
        case .four: return "HomeUI4_TwoColumnGrid"
        case .five: return "HomeUI5_MinimalTiles"
        }
    }
}

@MainActor
final class DeviceHomeUIThemeStore: ObservableObject {
    static let shared = DeviceHomeUIThemeStore()

    /// Locked to Home UI 1 — side theme picker removed.
    @Published private(set) var selected: DeviceHomeUIVariant = .one

    private init() {}
}

struct DeviceHomeUIPreviewItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let isOnline: Bool
    let isPowerOn: Bool
}
