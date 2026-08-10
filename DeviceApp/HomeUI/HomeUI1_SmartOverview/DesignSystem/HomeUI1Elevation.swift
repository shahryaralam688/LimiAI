//
//  HomeUI1Elevation.swift
//  LIMI AI Device — Home UI 1
//
//  Stronger premium-v13 neumorphism — tactile raised / pressed depth
//  without Metal blur overlays (safe for many simultaneous views).
//

import SwiftUI

enum HomeUI1ElevationLevel: Int {
    case recessed = -1
    case flat = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
}

struct HomeUI1ElevationModifier<S: Shape>: ViewModifier {
    let level: HomeUI1ElevationLevel
    let shape: S
    var fill: Color = HomeUI1Color.surface

    func body(content: Content) -> some View {
        switch level {
        case .recessed:
            content
                .background(shape.fill(fill))
                .overlay { insetDarkEdge }
                .overlay { insetLightEdge }
                .clipShape(shape)
                .compositingGroup()
                // Outer soft cradle so recessed wells still read on the canvas
                .shadow(color: HomeUI1Color.shadowLight.opacity(0.55), radius: 1, x: -1, y: -1)
                .shadow(color: HomeUI1Color.shadowDark.opacity(0.22), radius: 2, x: 1, y: 1)
        case .flat:
            content
                .background(shape.fill(fill))
                .clipShape(shape)
        default:
            let spec = shadowSpec(for: level)
            content
                .background(shape.fill(fill))
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                HomeUI1Color.shadowLight.opacity(0.85),
                                Color.clear,
                                HomeUI1Color.shadowDark.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                }
                .clipShape(shape)
                .compositingGroup()
                .shadow(
                    color: HomeUI1Color.shadowDark.opacity(spec.darkOpacity),
                    radius: spec.blur,
                    x: spec.offset,
                    y: spec.offset
                )
                .shadow(
                    color: HomeUI1Color.shadowLight.opacity(spec.lightOpacity),
                    radius: spec.blur,
                    x: -spec.offset,
                    y: -spec.offset
                )
        }
    }

    private var insetDarkEdge: some View {
        shape
            .stroke(HomeUI1Color.shadowDark.opacity(0.55), lineWidth: 6)
            .offset(x: 2.5, y: 2.5)
            .clipShape(shape)
            .allowsHitTesting(false)
    }

    private var insetLightEdge: some View {
        shape
            .stroke(HomeUI1Color.shadowLight.opacity(0.95), lineWidth: 5)
            .offset(x: -2, y: -2)
            .clipShape(shape)
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }

    private func shadowSpec(
        for level: HomeUI1ElevationLevel
    ) -> (offset: CGFloat, blur: CGFloat, darkOpacity: Double, lightOpacity: Double) {
        switch level {
        case .one:
            return (5, 5, 0.78, 0.95)
        case .two:
            return (7, 7, 0.82, 0.98)
        case .three:
            return (10, 10, 0.85, 1.0)
        case .four, .five:
            return (14, 14, 0.88, 1.0)
        default:
            return (8, 8, 0.8, 0.95)
        }
    }
}

extension View {
    func homeUI1Elevation(
        _ level: HomeUI1ElevationLevel,
        cornerRadius: CGFloat = HomeUI1Radius.md,
        fill: Color = HomeUI1Color.surface
    ) -> some View {
        modifier(
            HomeUI1ElevationModifier(
                level: level,
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                fill: fill
            )
        )
    }

    func homeUI1CapsuleElevation(
        _ level: HomeUI1ElevationLevel,
        fill: Color = HomeUI1Color.surface
    ) -> some View {
        modifier(
            HomeUI1ElevationModifier(
                level: level,
                shape: Capsule(style: .continuous),
                fill: fill
            )
        )
    }

    func homeUI1CircleElevation(
        _ level: HomeUI1ElevationLevel,
        fill: Color = HomeUI1Color.surface
    ) -> some View {
        modifier(
            HomeUI1ElevationModifier(
                level: level,
                shape: Circle(),
                fill: fill
            )
        )
    }

    func homeUI1Canvas() -> some View {
        background { HomeUI1AnimatedCanvas() }
    }
}
