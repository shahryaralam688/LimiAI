import SwiftUI

struct AnimatedSearchButton: View {
    @State private var isAnimating = false
    @State private var glowIntensity: Double = 0.3
    let iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [Color.appSurfaceNeutral, Color.appSurfaceNeutralAlt]), startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
                .shadow(color: Color.themeWhite.opacity(glowIntensity), radius: 25, x: 0, y: 8)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)

            Image(systemName: iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.themeWhite)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

            Circle()
                .stroke(Color.themeWhite.opacity(0.4), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 0.8)
                .animation(.easeOut(duration: 2.5).repeatForever(autoreverses: false), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glowIntensity = 0.8 }
        }
    }
}
