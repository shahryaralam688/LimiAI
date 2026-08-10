//
//  ARSurfaceDetection.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 01/12/2025.
//

import SwiftUI

enum ARSurfaceGuideType {
    case floor
    case ceiling
    case wall
    
    var title: String {
        switch self {
        case .floor: return "Floor"
        case .ceiling: return "Ceiling"
        case .wall: return "Wall"
        }
    }
    
    var instruction: String {
        switch self {
        case .floor: return "Point camera down toward the floor"
        case .ceiling: return "Point camera up toward the ceiling"
        case .wall: return "Point camera toward a wall"
        }
    }
    
    var iconName: String {
        switch self {
        case .floor: return "arrow.down.circle.fill"
        case .ceiling: return "arrow.up.circle.fill"
        case .wall: return "arrow.forward.circle.fill"
        }
    }
}

struct ARSurfaceGuideView: View {
    let type: ARSurfaceGuideType
    @State private var animate: Bool = false
    @State private var pulseAnimation: Bool = false
    
    
    var body: some View {
        VStack(spacing: 24) {
            // Main visual guide
            ZStack {
                surfaceVisualization
                phoneIndicator
            }
            .frame(height: 120)
            
            // Instruction text with icon
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: type.iconName)
                        .font(LimiTypography.title2)
                        .foregroundColor(.appTextPrimary)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    Text(type.title)
                        .font(LimiTypography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.appTextPrimary)
                }
                
//                Text(type.instruction)
//                    .font(LimiTypography.subheadline)
//                    .foregroundColor(.appTextPrimary.opacity(0.8))
//                    .multilineTextAlignment(.center)
//                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation {
                animate = true
                pulseAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.title) detection guide")
        .accessibilityHint(type.instruction)
    }

    // MARK: - Surface Visualizations
    @ViewBuilder
    private var surfaceVisualization: some View {
        switch type {
        case .floor:
            floorVisualization
        case .ceiling:
            ceilingVisualization
        case .wall:
            wallVisualization
        }
    }
    
    private var floorVisualization: some View {
        ZStack {
            // Floor plane with perspective
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.themeWhite.opacity(0.3), Color.appGlassFillStrong],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200, height: 60)
                .rotation3DEffect(.degrees(65), axis: (x: 1, y: 0, z: 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.themeWhite.opacity(0.6), lineWidth: 2)
                        .frame(width: 200, height: 60)
                        .rotation3DEffect(.degrees(65), axis: (x: 1, y: 0, z: 0))
                )
            
            // Grid pattern
            modernGrid(rows: 4, columns: 6, spacing: 20)
                .rotation3DEffect(.degrees(65), axis: (x: 1, y: 0, z: 0))
                .opacity(0.6)
        }
    }

    private var ceilingVisualization: some View {
        ZStack {
            // Ceiling plane with perspective
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.appGlassFillStrong, Color.themeWhite.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200, height: 60)
                .rotation3DEffect(.degrees(-65), axis: (x: 1, y: 0, z: 0))
                .offset(y: -15)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.themeWhite.opacity(0.6), lineWidth: 2)
                        .frame(width: 200, height: 60)
                        .rotation3DEffect(.degrees(-65), axis: (x: 1, y: 0, z: 0))
                        .offset(y: -15)
                )
            
            // Grid pattern
            modernGrid(rows: 4, columns: 6, spacing: 20)
                .rotation3DEffect(.degrees(-65), axis: (x: 1, y: 0, z: 0))
                .offset(y: -15)
                .opacity(0.6)
        }
    }

    private var wallVisualization: some View {
        ZStack {
            // Wall plane with slight perspective
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.themeWhite.opacity(0.2), Color.appGlassFillStrong],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 180, height: 120)
                .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.themeWhite.opacity(0.6), lineWidth: 2)
                        .frame(width: 180, height: 120)
                        .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                )
            
            // Grid pattern
            modernGrid(rows: 5, columns: 5, spacing: 18)
                .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                .opacity(0.6)
        }
    }

    // MARK: - Phone Indicator
    private var phoneIndicator: some View {
        ZStack {
            // Phone outline with modern design
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.themeWhite, lineWidth: 2.5)
                .frame(width: 36, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appGlassStrokeLight)
                        .frame(width: 36, height: 64)
                )
            
            // Screen area
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.brandAction.opacity(0.6), Color.brandHighlight.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 48)
            
            // Camera notch
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.themeWhite.opacity(0.8))
                .frame(width: 12, height: 3)
                .offset(y: -22)
            
            // Animated scanning line
            Rectangle()
                .fill(Color.themeWhite.opacity(0.8))
                .frame(width: 24, height: 1)
                .offset(y: animate ? -15 : 15)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: animate
                )
        }
        .offset(phoneOffset)
        .scaleEffect(animate ? 1.1 : 0.9)
        .animation(
            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
            value: animate
        )
    }

    private var phoneOffset: CGSize {
        switch type {
        case .floor:
            return CGSize(width: 0, height: animate ? -12 : 8)
        case .ceiling:
            return CGSize(width: 0, height: animate ? -12 : 8)
        case .wall:
            return CGSize(width: animate ? -14 : 14, height: 0)
        }
    }

    // MARK: - Modern Grid Pattern
    private func modernGrid(rows: Int, columns: Int, spacing: CGFloat) -> some View {
        let totalWidth = CGFloat(columns - 1) * spacing
        let totalHeight = CGFloat(rows - 1) * spacing
        
        return ZStack {
            // Horizontal lines
            ForEach(0..<rows, id: \.self) { row in
                Rectangle()
                    .fill(Color.themeWhite.opacity(0.4))
                    .frame(width: totalWidth, height: 1)
                    .offset(y: CGFloat(row) * spacing - totalHeight / 2)
            }
            
            // Vertical lines
            ForEach(0..<columns, id: \.self) { column in
                Rectangle()
                    .fill(Color.themeWhite.opacity(0.4))
                    .frame(width: 1, height: totalHeight)
                    .offset(x: CGFloat(column) * spacing - totalWidth / 2)
            }
            
            // Intersection dots with animated pulse
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { column in
                    Circle()
                        .fill(Color.themeWhite)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity(row: row, column: column, rows: rows, columns: columns))
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(row + column) * 0.1),
                            value: pulseAnimation
                        )
                        .offset(
                            x: CGFloat(column) * spacing - totalWidth / 2,
                            y: CGFloat(row) * spacing - totalHeight / 2
                        )
                }
            }
        }
    }
    
    private func dotOpacity(row: Int, column: Int, rows: Int, columns: Int) -> Double {
        let centerRow = Double(rows - 1) / 2.0
        let centerCol = Double(columns - 1) / 2.0
        let dr = Double(row) - centerRow
        let dc = Double(column) - centerCol
        let distance = sqrt(dr * dr + dc * dc)
        let maxDistance = sqrt(centerRow * centerRow + centerCol * centerCol)
        let normalized = 1.0 - (distance / maxDistance)
        return max(0.3, min(0.9, normalized))
    }
}
#Preview {
    VStack(spacing: 40) {
        ARSurfaceGuideView(type: .floor)
            .frame(height: 200)
        
        ARSurfaceGuideView(type: .ceiling)
            .frame(height: 200)
        
        ARSurfaceGuideView(type: .wall)
            .frame(height: 200)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appCanvasPrimary)
}
