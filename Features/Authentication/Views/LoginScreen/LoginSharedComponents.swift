import SwiftUI

struct OTPDigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.appBorderPrimary : Color.appBorderPrimary.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appGlassFillMedium)
                )
                .frame(width: 45, height: 55)
                .shadow(color: isActive ? Color.appCanvasPrimary.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)

            if !digit.isEmpty {
                Text(digit)
                    .font(LimiTypography.title)
                    .foregroundColor(.appTextInverse)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digit)
    }
}

struct LottieLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.appSurfacePrimary)
                    .frame(width: 8, height: 8)
                    .offset(y: isAnimating ? -10 : 0)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.2 * Double(index)),
                        value: isAnimating
                    )
            }
            .offset(x: -20)

            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.appSurfacePrimary)
                    .frame(width: 8, height: 8)
                    .offset(y: isAnimating ? -10 : 0)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.2 * Double(index) + 0.3),
                        value: isAnimating
                    )
            }
            .offset(x: 20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 5), y: 0))
    }
}

struct KeyboardResponsiveModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height - 20
                    }
                }

                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func keyboardResponsive() -> some View {
        modifier(KeyboardResponsiveModifier())
    }
}
