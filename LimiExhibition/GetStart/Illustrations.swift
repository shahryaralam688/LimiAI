import SwiftUI

struct DeafPersonIllustration: View {
    let isSelected: Bool
    @State private var phoneAnimation = false
    @State private var headAnimation = false
    
    var body: some View {
        ZStack {
            // Animated background
            Circle()
                .fill(Color.charlestonGreen.opacity(0.8))
                .frame(width: 70, height: 70)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: isSelected)
            
            // Person
            VStack(spacing: 0) {
                // Animated head
                Circle()
                    .fill(Color.white)
                    .frame(width: 25, height: 25)
                    .offset(y: headAnimation ? -2 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                        value: headAnimation
                    )
                
                // Body
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 30)
                    .cornerRadius(8)
            }
            .offset(y: -5)
            
            // Animated phone
            PhoneShape()
                .fill(Color.white)
                .frame(width: 18, height: 32)
                .offset(x: 15, y: phoneAnimation ? 3 : 7)
                .rotationEffect(.degrees(phoneAnimation ? 10 : -10))
                .animation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true),
                    value: phoneAnimation
                )
        }
        .onAppear {
            if isSelected {
                phoneAnimation = true
                headAnimation = true
            }
        }
        .onChange(of: isSelected) {
            updateAnimations()
        }

    }
    func updateAnimations() {
        phoneAnimation = isSelected
        headAnimation = isSelected
    }
}

struct InterpreterIllustration: View {
    let isSelected: Bool
    @State private var handAnimation = false
    @State private var bodyAnimation = false
    
    var body: some View {
        ZStack {
            // Animated background
            Circle()
                .fill(Color.charlestonGreen.opacity(0.8))
                .frame(width: 70, height: 70)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: isSelected)
            
            // Person
            VStack(spacing: 0) {
                // Head with slight movement
                Circle()
                    .fill(Color.white)
                    .frame(width: 25, height: 25)
                    .offset(y: bodyAnimation ? -2 : 0)
                
                // Body
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 30)
                    .cornerRadius(8)
            }
            .offset(y: -5)
            .animation(
                .easeInOut(duration: 0.7)
                .repeatForever(autoreverses: true),
                value: bodyAnimation
            )
            
            // Animated hands
            HStack(spacing: 25) {
                // Left hand
                HandShape()
                    .fill(Color.white)
                    .frame(width: 15, height: 20)
                    .rotationEffect(.degrees(handAnimation ? -30 : 0))
                
                // Right hand
                HandShape()
                    .fill(Color.white)
                    .frame(width: 15, height: 20)
                    .rotationEffect(.degrees(handAnimation ? 30 : 0))
            }
            .offset(y: 10)
            .animation(
                .easeInOut(duration: 0.7)
                .repeatForever(autoreverses: true),
                value: handAnimation
            )
        }
        .onAppear {
            if isSelected {
                handAnimation = true
                bodyAnimation = true
            }
        }
        .onChange(of: isSelected) { oldValue, newValue in

            handAnimation = newValue
            bodyAnimation = newValue
        }
    }
}

struct PhoneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Phone body
        let cornerRadius = width * 0.2
        path.addPath(
            Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height),
                 cornerRadius: cornerRadius)
        )
        
        // Screen
        let screenInset = width * 0.1
        path.addRect(
            CGRect(
                x: screenInset,
                y: screenInset,
                width: width - (screenInset * 2),
                height: height * 0.7
            )
        )
        
        // Home button
        let buttonSize = width * 0.25
        let buttonY = height - buttonSize - (width * 0.1)
        path.addEllipse(
            in: CGRect(
                x: (width - buttonSize) / 2,
                y: buttonY,
                width: buttonSize,
                height: buttonSize
            )
        )
        
        return path
    }
}

struct HandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // More natural hand shape
        path.move(to: CGPoint(x: width * 0.3, y: height * 0.4))
        path.addCurve(
            to: CGPoint(x: width * 0.7, y: height * 0.4),
            control1: CGPoint(x: width * 0.4, y: height * 0.3),
            control2: CGPoint(x: width * 0.6, y: height * 0.3)
        )
        
        // Palm
        path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.8))
        path.addCurve(
            to: CGPoint(x: width * 0.3, y: height * 0.8),
            control1: CGPoint(x: width * 0.6, y: height * 0.9),
            control2: CGPoint(x: width * 0.4, y: height * 0.9)
        )
        path.closeSubpath()
        
        // Add fingers with curves for more natural look
        for i in 0..<4 {
            let fingerWidth = width * 0.15
            let spacing = width * 0.2
            let xPosition = width * 0.2 + CGFloat(i) * spacing
            
            var fingerPath = Path()
            fingerPath.move(to: CGPoint(x: xPosition, y: height * 0.4))
            fingerPath.addCurve(
                to: CGPoint(x: xPosition + fingerWidth, y: height * 0.4),
                control1: CGPoint(x: xPosition, y: 0),
                control2: CGPoint(x: xPosition + fingerWidth, y: 0)
            )
            path.addPath(fingerPath)
        }
        
        return path
    }
}
