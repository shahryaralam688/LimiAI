//
//  HomeUI1Components.swift
//  LIMI AI Device — Home UI 1
//
//  Components matching premium-v13 neumorphic patterns:
//  raised buttons, inset inputs, chips, cards.
//

import SwiftUI

enum HomeUI1ButtonStyleKind {
    case raised   // .btn-neumorphic
    case inset    // .btn-neumorphic-inset / active
    case disabled
}

struct HomeUI1PrimaryButton: View {
    let title: String
    var kind: HomeUI1ButtonStyleKind = .raised
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HomeUI1Type.body(16))
                .foregroundStyle(foreground)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .homeUI1Elevation(
                    kind == .inset || kind == .disabled ? .recessed : .two,
                    cornerRadius: HomeUI1Radius.md,
                    fill: HomeUI1Color.surface
                )
        }
        .buttonStyle(.plain)
        .disabled(kind == .disabled)
        .animation(HomeUI1Motion.soft, value: kind == .inset)
    }

    private var foreground: Color {
        switch kind {
        case .raised: return HomeUI1Color.textSecondary
        case .inset: return HomeUI1Color.accentGreen
        case .disabled: return HomeUI1Color.textSecondary.opacity(0.5)
        }
    }
}

struct HomeUI1SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .font(HomeUI1Type.regular(16))
                .foregroundStyle(HomeUI1Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HomeUI1Color.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // .form-input — inset neumorphic field
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
    }
}

struct HomeUI1Chip: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(HomeUI1Type.body(13))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            // Unclicked = raised, clicked = pressed/inset
            .homeUI1Elevation(
                isSelected || isDisabled ? .recessed : .one,
                cornerRadius: HomeUI1Radius.nav,
                fill: HomeUI1Color.surface
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(HomeUI1Motion.soft, value: isSelected)
    }

    private var foreground: Color {
        if isDisabled { return HomeUI1Color.textSecondary.opacity(0.45) }
        if isSelected { return HomeUI1Color.textPrimary }
        return HomeUI1Color.textSecondary
    }
}

struct HomeUI1SegmentedTabs: View {
    let titles: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    withAnimation(HomeUI1Motion.soft) { selectedIndex = index }
                } label: {
                    Text(titles[index])
                        .font(HomeUI1Type.body(13))
                        .foregroundStyle(
                            selectedIndex == index
                                ? HomeUI1Color.accentGreen
                                : HomeUI1Color.textSecondary
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .homeUI1Elevation(
                            selectedIndex == index ? .recessed : .one,
                            cornerRadius: HomeUI1Radius.nav,
                            fill: HomeUI1Color.surface
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
    }
}

struct HomeUI1UnderlineTabs: View {
    let titles: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 20) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    withAnimation(HomeUI1Motion.soft) { selectedIndex = index }
                } label: {
                    VStack(spacing: 6) {
                        Text(titles[index])
                            .font(HomeUI1Type.body(14))
                            .foregroundStyle(
                                selectedIndex == index
                                    ? HomeUI1Color.textPrimary
                                    : HomeUI1Color.textSecondary
                            )
                        Capsule()
                            .fill(selectedIndex == index ? HomeUI1Color.accentGreen : Color.clear)
                            .frame(height: 3)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

enum HomeUI1AlertKind {
    case success, warning, error

    var fill: Color { HomeUI1Color.canvas }

    var accent: Color {
        switch self {
        case .success: return HomeUI1Color.accentGreen
        case .warning: return HomeUI1Color.warning
        case .error: return HomeUI1Color.accentRed
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct HomeUI1AlertBanner: View {
    let kind: HomeUI1AlertKind
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.icon)
                .foregroundStyle(kind.accent)
            Text(message)
                .font(HomeUI1Type.regular(13))
                .foregroundStyle(HomeUI1Color.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
    }
}

struct HomeUI1Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(HomeUI1Type.title(18)) // h4
                    .foregroundStyle(HomeUI1Color.textPrimary)
            }
            content()
        }
        .padding(HomeUI1Spacing.lg)
        // .event-card / .neumorphic-shadow
        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }
}
