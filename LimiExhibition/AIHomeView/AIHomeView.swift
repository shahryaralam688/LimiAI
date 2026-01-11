//
//  AIHomeView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 20/11/2025.
//

import SwiftUI

struct AIHomeView: View {
    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                statusBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 24)

                voiceOrb

                Spacer(minLength: 32)

                modulesCard
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
    }

    private var background: some View {
        Color(.black)
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 14, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white, lineWidth: 1)
                    .frame(width: 22, height: 10)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 18, height: 6)
                    )
            }
        }
        .frame(height: 44)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .scaledToFit()        // image ko aspect ratio ke saath fit karega
                    .frame(width: 160, height: 30)
                    .clipped()            // frame se bahir ka part cut ho jayega

                
            }

            Spacer()

            ZStack {
                Color(hex: "#171717").cornerRadius(20)
                Image("bottom_profile_view")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(Color(hex: "#FFFFFF"))

                Circle()
                    .stroke(Color(hex: "#FFFFFF"), lineWidth: 1.4)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 48, height: 48)
        }
        .frame(height: 44)
    }

    private var voiceOrb: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 250, height: 250)
                .shadow(color: Color.black.opacity(0.9), radius: 60, x: 0, y: 18)
                .overlay(
                    // INNER SHADOW (inset shadow equivalent)
                    Circle()
                        .stroke(Color(hex: "#484848").opacity(0.94), lineWidth: 3)
                        .blur(radius: 10)
                        .offset(x: -6, y: -1)
                        .mask(
                            Circle()
                                .fill(Color.black)
                        )
                )

            VStack(spacing: 12) {
                Text("Hey, Limi is here!")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Tap to chat")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.65))

                Image("Vector-2")
                    .scaledToFit()
            }
        }
        .frame(width: 250, height: 250)
        .contentShape(Circle())
    }


    private var modulesCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Welcome to Limi")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Tap button below to add Modules")
                    .font(.system(size: 15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.65))
            }
            .padding(.top, 32)

            Button(action: {
                // Placeholder for add modules action
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add Modules")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color.fromHex("#052010"))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.fromHex("#51D18E"))
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
            }
            .padding(.horizontal, 48)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 262)
        .background(Color.fromHex("#101217"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .foregroundColor(Color.white.opacity(0.12))
        )
    }
}

private struct EqualizerView: View {
    private let barCount = 9

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(barCount * 2 - 1)

            HStack(spacing: barWidth) {
                ForEach(0..<barCount, id: \.self) { index in
                    let heights: [CGFloat] = [0.2, 0.45, 0.8, 0.55, 0.95, 0.55, 0.8, 0.45, 0.2]
                    let heightFactor = heights[index]

                    RoundedRectangle(cornerRadius: barWidth)
                        .fill(Color.fromHex("#51D18E"))
                        .frame(width: barWidth, height: geometry.size.height * heightFactor)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct AIHomeView_Previews: PreviewProvider {
    static var previews: some View {
        AIHomeView()
    }
}
