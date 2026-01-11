import SwiftUI

struct CurvedSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var onEditingChanged: (Bool) -> Void
    var isDisabled: Bool
    
    private let trackHeight: CGFloat = 10
    private let knobSize: CGFloat = 36
    private let radius: CGFloat = 180
    
    @State private var isDragging = false

    @State private var showPercentagePopup = false
    @State private var longPressTimer: Timer?
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, disabled: Bool = false) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.isDisabled = disabled
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scale = min(1.0, geometry.size.width / (2 * radius + knobSize))
            ZStack(alignment: .center) {
                // Track background
                CircularTrackShape(radius: radius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: trackHeight)
                    .frame(width: 2 * radius, height: radius)

                // Gradient track
                CircularTrackShape(radius: radius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.8),
                                Color.white,
                                Color(red: 0.8, green: 0.9, blue: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: trackHeight, lineCap: .round)
                    )
                    .frame(width: 2 * radius, height: radius)

                // Knob with percentage popup
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: knobSize + 8, height: knobSize + 8)
                        .blur(radius: 4)

                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.white.opacity(0.9)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize * 0.6, height: knobSize * 0.6)
                }
                .overlay(
                    Group {
                        if showPercentagePopup {
                            VStack(spacing: 4) {
                                Text("Cold: \(coldPercentage())%")
                                    .foregroundColor(.charlestonGreen)
                                Text("Warm: \(warmPercentage())%")
                                    .foregroundColor(.charlestonGreen)
                            }
                            .padding(8)
                            .background(Color.alabaster)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .frame(width: 120) // 👈 Width fix kar di
                            .offset(y: -80) // 👈 thoda upar kiya
                        }
                    }
                )
                .position(x: knobXPosition(), y: knobYPosition())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if isDisabled { return }
                            if !isDragging {
                                isDragging = true

                                startLongPressTimer()
                                onEditingChanged(true)
                            }
                            updateValue(with: gesture.location)
                        }
                        .onEnded { _ in
                            if isDisabled { return }
                            isDragging = false
                            cancelLongPressTimer()
                            showPercentagePopup = false
                            onEditingChanged(false)
                        }
                )


                // Tap-to-move the knob anywhere on the arc
                Color.clear
                    .contentShape(CircularTrackShape(radius: radius))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { drag in
                                if isDisabled { return }
                                updateValue(with: drag.location)
                                onEditingChanged(true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onEditingChanged(false)
                                }
                            }
                    )
            }
            .frame(width: 2 * radius, height: radius)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .frame(height: radius + knobSize / 2)
    }
    
    private func knobXPosition() -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let angle = percentage * .pi
        return radius + radius * cos(angle)
    }
    
    private func knobYPosition() -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let angle = percentage * .pi
        return radius - radius * sin(angle)
    }
    
    private func updateValue(with location: CGPoint) {
        let cx = radius
        let cy = radius
        let dx = location.x - cx
        let dy = cy - location.y
        var angle = atan2(dy, dx)
        angle = max(min(angle, .pi), 0)
        
        let lastPercentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let lastAngle = lastPercentage * .pi
        let angleDelta = abs(lastAngle - angle)

        if angleDelta > .pi / 1.5 {
            return
        }

        let percentage = angle / .pi
        var newValue = range.lowerBound + percentage * (range.upperBound - range.lowerBound)
        if step > 0 {
            newValue = round(newValue / step) * step
        }
        newValue = max(range.lowerBound, min(range.upperBound, newValue))
        self.value = newValue
    }

    private func startLongPressTimer() {
        cancelLongPressTimer()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.5 , repeats: false) { _ in
            showPercentagePopup = true
        }
    }
    
    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func coldPercentage() -> Int {
        let cold = 100 - Int((value / (range.upperBound - range.lowerBound)) * 100)
        return max(0, min(100, cold))
    }
    
    private func warmPercentage() -> Int {
        let warm = Int((value / (range.upperBound - range.lowerBound)) * 100)
        return max(0, min(100, warm))
    }
}

// Custom shape for the circular track
struct CircularTrackShape: Shape {
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = radius
        let centerY = radius
        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

// Preview provider
struct CurvedSlider_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        @State private var sliderValue: Double = 50.0
        
        var body: some View {
            VStack {
                Text("Temperature Control")
                    .font(.headline)
                    .padding(.bottom, 20)
                
                CurvedSlider(value: $sliderValue, in: 0...100, step: 1)
                
                Text("Value: \(Int(sliderValue))")
                    .padding(.top, 20)
            }
            .padding(40)
            .background(Color(.systemBackground))
        }
    }
}
