import SwiftUI
import AVKit
import Foundation

struct SplashScreen: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("globalUserLocation") private var storedLocation = ""
    /// Lets users continue without sharing location after the logged-in prompt.
    @AppStorage("locationPromptSkipped") private var locationPromptSkipped = false
    @State private var isActive = false
    @State private var logoScale = 0.8
    @State private var logoOpacity = 0.0
    @State private var taglineOffset: CGFloat = 20
    @State private var taglineOpacity = 0.0
    @State private var pulsePhase = 0.0
    @State private var orbBreathe = false

    var body: some View {
        Group {
            if isActive {
                destinationView
                    .transition(.opacity.animation(.easeInOut(duration: 0.8)))
            } else {
                splashContent
            }
        }
        .animation(.easeInOut(duration: 0.8), value: isActive)
        .trackScreen("SplashScreen", metadata: ["phase": "splash_or_routing"])
    }

    @ViewBuilder
    private var destinationView: some View {
        if authManager.isAuthenticated {
            if storedLocation.isEmpty && !locationPromptSkipped {
                LocationStorageView(showSkipButton: true)
                    .ignoresSafeArea()
            } else {
                HomeView()
                    .ignoresSafeArea()
            }
        } else if !hasLaunchedBefore || !hasCompletedOnboarding {
            OnboardingView()
                .ignoresSafeArea()
        } else {
            GetStart()
                .ignoresSafeArea()
        }
    }

    private var splashContent: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()

            // Subtle ambient glow
            RadialGradient(
                colors: [
                    Color.appBrandSecondary.opacity(0.10),
                    Color.appBrandPrimary.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 350
            )
            .ignoresSafeArea()
            .scaleEffect(orbBreathe ? 1.1 : 0.9)

            VStack(spacing: 28) {
                Spacer()

                // Logo with glow
                ZStack {
                    Image("logoSplash")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.appBrandPrimary)
                        .frame(width: 100, height: 84)
                        .blur(radius: 20)
                        .opacity(logoOpacity * 0.32)

                    Image("logoSplash")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.appTextPrimary)
                        .frame(width: 100, height: 84)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                VStack(spacing: 10) {
//                    Text("Limi")
//                        .font(.system(size: 44, weight: .bold, design: .rounded))
//                        .foregroundColor(.appTextPrimary)
//                        .tracking(-1)

                    Text("The Operating System for Physical Space")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .tracking(0.3)
                }
                .offset(y: taglineOffset)
                .opacity(taglineOpacity)

                Spacer()

                // Loader — orbiting dot
                ZStack {
                    Circle()
                        .stroke(Color.appBorderPrimary.opacity(0.45), lineWidth: 1)
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(Color.appBrandSecondary)
                        .frame(width: 6, height: 6)
                        .offset(x: 22)
                        .rotationEffect(.degrees(pulsePhase * 360))

                    Circle()
                        .fill(Color.appBrandPrimary.opacity(0.35))
                        .frame(width: 6, height: 6)
                        .offset(x: 22)
                        .rotationEffect(.degrees(pulsePhase * 360))
                        .blur(radius: 4)
                }
                .frame(height: 80)
                .padding(.bottom, 40)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            taglineOpacity = 1.0
            taglineOffset = 0
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            pulsePhase = 1.0
        }
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            orbBreathe = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.8)) {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashScreen()
}
