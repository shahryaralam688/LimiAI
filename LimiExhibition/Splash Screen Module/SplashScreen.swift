import SwiftUI
import AVKit
import Foundation

struct SplashScreen: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("globalUserLocation") private var storedLocation = ""
    @State private var isActive = false
    @State private var logoScale = 0.8
    @State private var logoOpacity = 0.0
    @State private var taglineOffset: CGFloat = 20
    @State private var taglineOpacity = 0.0
    @State private var hardwareScale = 0.9
    @State private var hardwareOpacity = 0.0
    @State private var pulsePhase = 0.0

    private let brandGreen = Color(hex: "#76E094")

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
    }

    @ViewBuilder
    private var destinationView: some View {
        if storedLocation.isEmpty {
            LocationStorageView()
                .ignoresSafeArea()
        } else {
            if authManager.isAuthenticated {
                HomeView()
                    .ignoresSafeArea()
            } else if !hasLaunchedBefore || !hasCompletedOnboarding {
                OnboardingView()
                    .ignoresSafeArea()
            } else {
                GetStart()
                    .ignoresSafeArea()
            }
        }
    }

    private var splashContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Hardware imagery layer - uncomment and replace "hardwareDevice" with your asset
            // Image("hardwareDevice")
            //     .resizable()
            //     .scaledToFit()
            //     .frame(width: 280)
            //     .opacity(hardwareOpacity)
            //     .scaleEffect(hardwareScale)
            //     .blur(radius: hardwareOpacity < 0.5 ? 2 : 0)

            VStack(spacing: 24) {
                Spacer()

                Image("logoSplash")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(brandGreen)
                    .frame(width: 120, height: 100)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: brandGreen.opacity(0.3), radius: 30, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Limi")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("The Operating System for Physical Space")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(brandGreen.opacity(0.8))
                        .tracking(0.5)
                }
                .offset(y: taglineOffset)
                .opacity(taglineOpacity)

                Spacer()

                // Modern minimalist loader - glowing pulse effect
                ZStack {
                    Circle()
                        .stroke(brandGreen.opacity(0.15), lineWidth: 1)
                        .frame(width: 60, height: 60)
                        .scaleEffect(1.0 + pulsePhase * 0.3)
                        .opacity(1.0 - pulsePhase)

                    Circle()
                        .stroke(brandGreen.opacity(0.3), lineWidth: 1)
                        .frame(width: 50, height: 50)
                        .scaleEffect(1.0 + pulsePhase * 0.2)
                        .opacity(0.8 - pulsePhase * 0.5)

                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(brandGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(Angle(degrees: 360 * pulsePhase))
                        .shadow(color: brandGreen, radius: 8, x: 0, y: 0)
                }
                .frame(height: 100)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.2)) {
            hardwareOpacity = 0.15
            hardwareScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            taglineOpacity = 1.0
            taglineOffset = 0
        }

        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            pulsePhase = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashScreen()
}
