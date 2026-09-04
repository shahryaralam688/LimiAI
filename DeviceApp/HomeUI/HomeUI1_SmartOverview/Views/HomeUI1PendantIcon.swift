//
//  HomeUI1PendantIcon.swift
//  LIMI AI Device — Home UI 1
//
//  Dining-room hub scene (woven pendants over table):
//  ON  = warm lit photo
//  OFF = same photo, dulled (desaturated / darkened)
//  Fills the featured media container edge-to-edge.
//

import SwiftUI

/// Full-bleed featured scene for the device card media well.
struct HomeUI1PendantHero: View {
    var isOn: Bool
    var isOnline: Bool

    private var lit: Bool { isOn && isOnline }

    var body: some View {
        GeometryReader { geo in
            Image(lit ? "HomeUI1PendantOn" : "HomeUI1PendantOff")
                .resizable()
                .scaledToFill()
                // Prefer the hanging pendants — crop from the top of the frame.
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .clipped()
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.clear,
                    Color.black.opacity(lit ? 0.05 : 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .animation(HomeUI1Motion.soft, value: lit)
        .accessibilityLabel(lit ? "Room lights on" : "Room lights off")
    }
}

/// Compact row thumbnail — same scene, top-cropped to the fixture.
struct HomeUI1PendantThumb: View {
    var isOn: Bool
    var isOnline: Bool
    var size: CGFloat = 40

    private var lit: Bool { isOn && isOnline }

    var body: some View {
        Image(lit ? "HomeUI1PendantOn" : "HomeUI1PendantOff")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .top)
            .clipped()
            .animation(HomeUI1Motion.soft, value: lit)
            .accessibilityHidden(true)
    }
}
