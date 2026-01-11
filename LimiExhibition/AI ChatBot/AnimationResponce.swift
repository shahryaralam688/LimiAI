//
//  AnimationResponce.swift
//  LimiExhibition
//
//  Created by Cascade on 24/11/2025.
//

import SwiftUI

// MARK: - Animated Waveform Bars
struct AnimatedWaveformBars: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0.3, count: 11)
    @State private var animationTrigger = false
    let isAnimating: Bool
    let barColor: Color
    let barWidth: CGFloat
    let barSpacing: CGFloat
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barHeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor)
                    .frame(width: barWidth, height: 40 * barHeights[index])
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                        value: animationTrigger
                    )
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<barHeights.count {
            barHeights[i] = CGFloat.random(in: 0.3...1.0)
        }
        // Trigger animation by toggling the state
        withAnimation {
            animationTrigger.toggle()
        }
        // Keep re-triggering for continuous animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if isAnimating {
                startAnimation()
            }
        }
    }
    
    private func stopAnimation() {
        for i in 0..<barHeights.count {
            barHeights[i] = 0.3
        }
    }
}

// MARK: - AI Response Indicator
struct AIResponseIndicator: View {
    let isAISpeaking: Bool
    let barColor: Color
    
    var body: some View {
        VStack(spacing: 12) {
            if isAISpeaking {
                // Animated waveform when AI is speaking
                AnimatedWaveformBars(
                    isAnimating: isAISpeaking,
                    barColor: barColor,
                    barWidth: 4,
                    barSpacing: 3
                )
                .frame(height: 40)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)

    }
}

// MARK: - Compact Waveform (for chat bubbles)
struct CompactWaveform: View {
    let isAnimating: Bool
    let barCount: Int
    let barColor: Color
    
    @State private var barHeights: [CGFloat]?
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<(barHeights?.count ?? barCount), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor)
                    .frame(width: 2, height: 12 * (barHeights?[index] ?? 0.3))
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.06),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            barHeights = Array(repeating: 0.3, count: barCount)
            if isAnimating {
                updateHeights()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                updateHeights()
            } else {
                if barHeights != nil {
                    barHeights = Array(repeating: 0.3, count: barCount)
                }
            }
        }
    }
    
    private func updateHeights() {
        guard var heights = barHeights else { return }
        for i in 0..<heights.count {
            heights[i] = CGFloat.random(in: 0.3...1.0)
        }
        barHeights = heights
    }
}

#Preview {
    VStack(spacing: 20) {
        // Speaking state
        AIResponseIndicator(isAISpeaking: true, barColor: .white)

    }
    .padding()
    .background(Color.black)
}
