import SwiftUI
import AVKit
import Foundation


struct SplashScreen: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("globalUserLocation") private var storedLocation = ""
    @State private var isActive = false
    @State private var isAnimating = false
    @State private var logoOpacity = 0.0

    
    var body: some View {
        if isActive {
            // First check if location is stored
            if storedLocation.isEmpty {
                LocationStorageView()
                    .ignoresSafeArea()
            } else {
                // Location is available, proceed with authentication logic
                if authManager.isAuthenticated {
//                    if globalUserSpace == "home" {
                        HomeView()
                            .ignoresSafeArea()
//                    ARModelList()

//                    } else if globalUserSpace == "hospatelity" {
//                        HotelHomeView()
//                            .ignoresSafeArea()
//                    }
                    
//                    TestingARPreviewView()
//                        .ignoresSafeArea()

                } else if !hasLaunchedBefore {
                    // First-time user
                    OnboardingView()
                        .ignoresSafeArea()
//                    WifiList(deviceName: "", deviceId: "")
//                    DemoScanDevicesView()
                    
                } else if !hasCompletedOnboarding {
                    OnboardingView()
                        .ignoresSafeArea()
                } else {
                    GetStart()
                        .ignoresSafeArea()
                }
            }
        } else {
            // Splash Screen
            ZStack {
                Color.charlestonGreen.ignoresSafeArea()
                
                VStack {
                    Spacer()
                        Image("logoSplash")
                            .resizable()
                            .frame(width: 120, height: 100)
                            .padding()
                            .shadow(radius: 20)
                            .opacity(logoOpacity)
                    Spacer()
                    ZStack {
                        Image("Splash_bottom")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .opacity(0.3)

                        // Custom circular loader
                        ZStack {
                            Circle()
                                .stroke(Color.charlestonGreen.opacity(0.4), lineWidth: 8) // background ring
                                .frame(width: 50, height: 50)

                            Circle()
                                .trim(from: 0, to: 0.25) // only a segment
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                        }
                    }
                    .onAppear {
                        isAnimating = true
                    }
                    
                }
                .ignoresSafeArea(.all)
                
            }
            .onAppear {
                logoOpacity = 0.0
                withAnimation(.easeIn(duration: 1.0)) {
                    logoOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isActive = true
                }
            }
        }
    }
}
#Preview {
    SplashScreen()
}
