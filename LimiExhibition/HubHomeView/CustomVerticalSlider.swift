import SwiftUI

struct VerticalSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var isEnabled: Bool = true
    var onRelease: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LinearGradient(gradient: Gradient(colors: [.themeWhite, .themeWhite]), startPoint: .top, endPoint: .bottom)
                    .opacity(0.4)
                    .cornerRadius(20)
                    .shadow(color: .themeBlack, radius: 5)

                Rectangle()
                    .fill(Color.themeWhite)
                    .frame(height: CGFloat((clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geo.size.height)
                    .cornerRadius(25)
            }
            .frame(width: 50)
            .brightness(isEnabled ? 0 : -0.3)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if isEnabled {
                            let height = geo.size.height
                            let locationY = Double(min(max(gesture.location.y, 0), height))
                            let sliderHeight = Double(height)
                            let newValue = (1 - locationY / sliderHeight) * (range.upperBound - range.lowerBound) + range.lowerBound

                            value = newValue.clamped(to: range)
                        }
                    }
                    .onEnded { _ in if isEnabled { onRelease?(value) } }
            )
            .onTapGesture { loc in
                if isEnabled {
                    let newValue = (1 - Double(loc.y) / Double(geo.size.height)) * (range.upperBound - range.lowerBound) + range.lowerBound
                    value = newValue.clamped(to: range)
                    onRelease?(value)
                }
            }
            .allowsHitTesting(isEnabled)
        }
        .frame(height: 295)
        .frame(width: 51)
    }

    private var clampedValue: Double {
        value.clamped(to: range)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
