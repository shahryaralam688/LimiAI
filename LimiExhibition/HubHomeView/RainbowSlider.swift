//
//  RainbowSlider.swift
//  Limi
//
//  Created by Mac Mini on 17/03/2025.
//
import SwiftUI
import RealityKit
struct RainbowSlider: View {
    @Binding var value: Double
    @Binding var selectedColor: Color
    
    private static let gradientColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .indigo, .purple, .pink
    ]
    
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                LinearGradient(
                    gradient: Gradient(colors: Self.gradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.themeWhite.opacity(0.5), lineWidth: 2)
                )
                .frame(height: 40)
                
                Circle()
                    .frame(width: 38, height: 38)
                    .foregroundColor(selectedColor)
                    .shadow(color: Color.themeBlack.opacity(0.3), radius: 5)
                    .overlay(
                        Circle()
                            .stroke(Color.themeWhite.opacity(0.7), lineWidth: 2)
                    )
                    .position(
                        x: max(10, min(geometry.size.width - 10, geometry.size.width * CGFloat(value / 100))),
                        y: 20
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let width = geometry.size.width - 20
                                let rawPosition = gesture.location.x - 10
                                let newValue = (min(max(rawPosition, 0), width) / width) * 100
                                if abs(newValue - value) > 1 {
                                    haptic.impactOccurred()
                                }
                                value = newValue
                                selectedColor = getColorAt(position: value)
                            }
                    )
            }
            .onAppear {
                // Sync `value` with current `selectedColor`
                if let newValue = getPosition(for: selectedColor) {
                    value = newValue
                }
            }
        }
        .padding(.horizontal)
        .frame(height: 40)
    }
    
    private func getColorAt(position: Double) -> Color {
        let index = position / 100 * Double(Self.gradientColors.count - 1)
        let lowerIndex = Int(index)
        let upperIndex = min(lowerIndex + 1, Self.gradientColors.count - 1)
        let progress = index - Double(lowerIndex)
        
        return interpolateColor(from: Self.gradientColors[lowerIndex],
                                to: Self.gradientColors[upperIndex],
                                progress: progress)
    }

    private func getPosition(for color: Color) -> Double? {
        // Find nearest color index
        for i in 0..<Self.gradientColors.count {
            if color.description == Self.gradientColors[i].description {
                return Double(i) / Double(Self.gradientColors.count - 1) * 100
            }
        }
        return nil
    }

    private func interpolateColor(from startColor: Color, to endColor: Color, progress: Double) -> Color {
        guard let startComponents = UIColor(startColor).cgColor.components,
              let endComponents = UIColor(endColor).cgColor.components else {
            return startColor
        }

        let r = startComponents[0] + (endComponents[0] - startComponents[0]) * progress
        let g = startComponents[1] + (endComponents[1] - startComponents[1]) * progress
        let b = startComponents[2] + (endComponents[2] - startComponents[2]) * progress
        let a = startComponents[3] + (endComponents[3] - startComponents[3]) * progress
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
