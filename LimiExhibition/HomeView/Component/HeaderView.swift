import SwiftUI

struct HeaderView: View {
    @Binding var isSidebarOpen: Bool
    @State private var logoScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0

    var body: some View {
        HStack {
            ZStack {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 70)
                    .blur(radius: 8)
                    .opacity(glowOpacity * 0.3)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 70)
                    .scaleEffect(logoScale)
            }
            .padding(5)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    logoScale = 1.03
                    glowOpacity = 0.4
                }
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isSidebarOpen.toggle()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.orbGlow4.opacity(0.15))
                        .frame(width: 46, height: 46)
                        .blur(radius: 4)
                        .opacity(isSidebarOpen ? 0.6 : 0)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )

                    Image(systemName: isSidebarOpen ? "xmark" : "line.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.appTextPrimary)
                }
                .rotationEffect(.degrees(isSidebarOpen ? 90 : 0))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSidebarOpen)
            }
            .padding(.horizontal, 15)
        }
        .padding(.top, 50)
        .padding(.bottom, 0)
        .background(
            ZStack {
                Color.appCanvasPrimary

                LinearGradient(
                    colors: [Color.orbGlow2.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(
                RoundedCornerShape(cornerRadius: 5, corners: [.bottomLeft, .bottomRight])
            )
        )
    }
}
