//
//  HomeUI1Elevation.swift
//  LIMI AI Device — Home UI 1
//
//  Dark charcoal-green neumorphism — soft blurred dual shadows, inset wells.
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
                .shadow(color: HomeUI1Color.shadowLight.opacity(0.18), radius: 2, x: -1, y: -1)
                .shadow(color: HomeUI1Color.shadowDark.opacity(0.45), radius: 4, x: 2, y: 2)
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
                                HomeUI1Color.shadowLight.opacity(0.42),
                                Color.clear,
                                HomeUI1Color.shadowDark.opacity(0.35)
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
            .stroke(HomeUI1Color.shadowDark.opacity(0.72), lineWidth: 6)
            .offset(x: 2.5, y: 2.5)
            .clipShape(shape)
            .allowsHitTesting(false)
    }

    private var insetLightEdge: some View {
        shape
            .stroke(HomeUI1Color.shadowLight.opacity(0.38), lineWidth: 5)
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
            return (5, 8, 0.62, 0.28)
        case .two:
            return (6, 10, 0.68, 0.32)
        case .three:
            return (8, 14, 0.72, 0.36)
        case .four, .five:
            return (10, 18, 0.78, 0.40)
        default:
            return (7, 12, 0.65, 0.30)
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
