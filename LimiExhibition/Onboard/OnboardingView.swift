import SwiftUI
import UIKit
import WebKit
import SDWebImageSwiftUI

class ImageRotationCeiling: ObservableObject {
    @Published var currentIndex = 0
    private var timer: Timer?

    let images = ["ceilingVertical", "ceilingHorizontal"]

    init() {
        startImageRotation()
    }

    func startImageRotation() {
        stopImageRotation() // Stop any existing timer before starting a new one
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.currentIndex = (self.currentIndex + 1) % self.images.count
            }
        }
    }

    func stopImageRotation() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopImageRotation() // Ensure timer is stopped when the object is deallocated
    }
}

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showDemoAddDevice = false // ✅ showDemoAddDevice state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var skipButtonOpacity: Double = 0
    private let totalPages = 5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if showDemoAddDevice {
                SignInView()
//                LoginSkipView()
                .transition(.asymmetric( insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity) ))
            }
            else {
                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        index: 0,
                        image: "Onboarding_img_1",
                        title: "Meet LIMI — Your Ambient AI System",
                        description: "LIMI blends intelligence into your space. Always present. Always aware. Always helpful — without demanding your attention.",
                        pageIndex: $currentPage,
                        totalPages: totalPages,
                        showDemoAddDevice: $showDemoAddDevice
                    ).tag(0).ignoresSafeArea()
                    
                    OnboardingPageView(
                        index: 1,
                        image: "Onboarding_img_2",
                        title: "Control Your World, Naturally",
                        description: "Lights, comfort, routines, moments — all controlled by voice, touch, or automation. Your space responds to you, not the other way around.",
                        pageIndex: $currentPage,
                        totalPages: totalPages,
                        showDemoAddDevice: $showDemoAddDevice
                    ).tag(1).ignoresSafeArea()
                    
                    OnboardingPageView(
                        index: 2,
                        image: "Onboarding_img_3",
                        title: "Spaces That Feel Alive",
                        description: "LLIMI adapts lighting and ambience to your mood, time, and activity — from focus to relaxation, mornings to evenings.",
                        pageIndex: $currentPage,
                        totalPages: totalPages,
                        showDemoAddDevice: $showDemoAddDevice
                    ).tag(2).ignoresSafeArea()
                    
                    OnboardingPageView(
                        index: 3,
                        image: "Onboarding_img_4",
                        title: "Learns Quietly. Acts Intelligently.",
                        description: "LIMI understands patterns — not just commands. It senses routines, anticipates needs, and supports you without interruption.",
                        pageIndex: $currentPage,
                        totalPages: totalPages,
                        showDemoAddDevice: $showDemoAddDevice
                    ).tag(3).ignoresSafeArea()
                    
                    OnboardingPageView(
                        index: 4,
                        image: "Onboarding_img_5",
                        title: "Welcome to Intelligent Living",
                        description: "Installation-free. Effortless to use. AI that lives in your space — not on your screen.",
                        pageIndex: $currentPage,
                        totalPages: totalPages,
                        showDemoAddDevice: $showDemoAddDevice
                    ).tag(4).ignoresSafeArea()
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
//                if currentPage != 4 {
//                    Button("Skip") {
//                        hasCompletedOnboarding = true
//                        showDemoAddDevice = true // ✅ showDemoAddDevice triggers on Skip
//                    }
//                    .foregroundColor(.white)
//                    .padding(.top, 50)
//                    .padding(.trailing, 20)
//                    .opacity(skipButtonOpacity)
//                    .animation(.easeOut(duration: 0.6).delay(0.8), value: skipButtonOpacity)
//                }
                
            }
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                skipButtonOpacity = 1.0
            }
        }
        .onChange(of: currentPage) { _, _ in
            skipButtonOpacity = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                skipButtonOpacity = 1.0
            }
        }
    }
}

struct OnboardingPageView: View {
    let index: Int
    let image: String
    let title: String
    let description: String
    @Binding var pageIndex: Int
    let totalPages: Int

    @Binding var showDemoAddDevice: Bool // ✅ binding for showDemoAddDevice
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var imageOpacity: Double = 0
    @State private var cardOffset: CGFloat = 50
    @State private var cardOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    @State private var descriptionOpacity: Double = 0
    @State private var buttonScale: CGFloat = 0.8
    @State private var buttonOpacity: Double = 0
    @State private var indicatorOpacity: Double = 0
    @State private var wasActive: Bool = false

    private var isActive: Bool {
        pageIndex == index
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1️⃣ Top image fills the screen
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .opacity(imageOpacity)
                    .animation(.easeOut(duration: 0.8), value: imageOpacity)

                VStack {
                    Spacer() // push bottom card to bottom

                    // 2️⃣ Bottom card
                    ZStack(alignment: .top) {
                        Image("bgOnboarding")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300 + geo.safeAreaInsets.bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                // 🔹 White transparent blur effect
                                Rectangle()
                                    .fill(.ultraThinMaterial) // system blur
                                    .background(Color.white.opacity(0.9)) // white tint
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            )
                            .opacity(0.6)

                        // Card content
                        VStack(spacing: 20) {
                            Text(title)
                                .font(.system(size: 24, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .scaleEffect(titleScale)
                                .opacity(titleOpacity)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.3), value: titleScale)
                                .animation(.easeOut(duration: 0.6).delay(0.3), value: titleOpacity)

                            Text(description)
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .opacity(descriptionOpacity)
                                .animation(.easeOut(duration: 0.6).delay(0.5), value: descriptionOpacity)

                            if pageIndex == totalPages - 1 {
                                Button(action: {
                                        hasCompletedOnboarding = true
                                        showDemoAddDevice = true // showDemoAddDevice triggers on last page
                                }) {
                                    Text( "Get Started")
                                        .font(.system(size: 17, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(hex: "#54BA73"))
                                        .foregroundColor(.black)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 30)
                                .scaleEffect(buttonScale)
                                .opacity(buttonOpacity)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0).delay(0.7), value: buttonScale)
                                .animation(.easeOut(duration: 0.5).delay(0.7), value: buttonOpacity)
                            }
                            if pageIndex != totalPages - 1 {
                                HStack(spacing: 8) {
                                    ForEach(0..<totalPages, id: \.self) { index in
                                        Circle()
                                            .fill(index == pageIndex ? Color.white : Color.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.top, 56)
                                .opacity(indicatorOpacity)
                                .animation(.easeOut(duration: 0.5).delay(0.6), value: indicatorOpacity)
                            } else {
                                HStack(spacing: 8) {
                                    ForEach(0..<totalPages, id: \.self) { index in
                                        Circle()
                                            .fill(index == pageIndex ? Color.white : Color.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.top, 26)
                                .opacity(indicatorOpacity)
                                .animation(.easeOut(duration: 0.5).delay(0.6), value: indicatorOpacity)
                            }
                            

                            Spacer(minLength: geo.safeAreaInsets.bottom)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300 + geo.safeAreaInsets.bottom)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0).delay(0.2), value: cardOffset)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: cardOpacity)
                }
            }
        }
        .onAppear {
            wasActive = isActive
            if isActive {
                startAnimations()
            }
        }
        .onChange(of: pageIndex) { _, _ in
            let currentlyActive = isActive
            if currentlyActive && !wasActive {
                resetAndStartAnimations()
            }
            wasActive = currentlyActive
        }
    }
    
    private func startAnimations() {
        imageOpacity = 1.0
        cardOffset = 0
        cardOpacity = 1.0
        titleScale = 1.0
        titleOpacity = 1.0
        descriptionOpacity = 1.0
        buttonScale = 1.0
        buttonOpacity = 1.0
        indicatorOpacity = 1.0
    }
    
    private func resetAndStartAnimations() {
        // Reset all animation states
        imageOpacity = 0
        cardOffset = 50
        cardOpacity = 0
        titleScale = 0.8
        titleOpacity = 0
        descriptionOpacity = 0
        buttonScale = 0.8
        buttonOpacity = 0
        indicatorOpacity = 0
        
        // Start animations with a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimations()
        }
    }
}

struct CustomPageIndicator: View {
    var currentPage: Int
    var totalPages: Int
    var activeColor: Color
    var inactiveColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalPages, id: \.self) { index in
                if currentPage == index {
                    Capsule()
                        .fill(activeColor)
                        .frame(width: 34, height: 8)
                        .transition(.scale)
                } else {
                    Circle()
                        .fill(inactiveColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.spring(), value: currentPage)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
