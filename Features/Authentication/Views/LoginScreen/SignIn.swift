//
//  SignIn.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 30/12/2025.
//

import SwiftUI
import RealityKit
import AVFoundation

/// Headline shown on screen; same string drives TTS so speech + text stay aligned.
private enum SignInHeadlineCopy {
    static let display = "Invisible by design,\nIntelligent by nature"
}

/// Spoken after the headline (voice only — buttons pulse on key phrases).
private enum SignInLoginScriptCopy {
    static let display = """
    To get started, please log in using one of the options below.
    You can continue with your email, or sign in quickly using the "Continue with Google" button. If you'd like to explore first, feel free to continue as a guest.
    By proceeding, you agree to our Terms and Privacy Policy.
    """
}

struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()
    @StateObject private var signInSpeech = SignInScreenSpeechSync()
    var body: some View {
        GeometryReader { geo in
            let horizontalInset: CGFloat = 24
            let maxColumn = min(geo.size.width - horizontalInset * 2, 400)
            let bottomInset = max(geo.safeAreaInsets.bottom, 12) + 8

            ZStack {
                // Fills any gap if layout is inset; keeps bottom bar from flashing white.
                Color.black
                    .ignoresSafeArea(.all)

                // Edge-to-edge: GeometryReader size is often inset from safe areas; fill + ignore safe areas avoids white bars.
                Image("signInBg")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.all)

                SignInCenterNeuralOrb(
                    orbSize: min(geo.size.width, geo.size.height) * 0.175
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
//                    Spacer(minLength: 0)

                    signInColumn(maxWidth: maxColumn)
                        .frame(maxWidth: maxColumn)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, bottomInset)
                .padding(.top, max(geo.safeAreaInsets.top, 8))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.all)
        .opacity(viewModel.appeared ? 1 : 0)
        .offset(y: viewModel.appeared ? 0 : 20)
        .onAppear {
            withAnimation(LimiMotion.gentle) { viewModel.appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                signInSpeech.speak()
            }
        }
        .onDisappear { signInSpeech.stop() }
        .onChange(of: viewModel.showHomeView) { _, open in if open { signInSpeech.stop() } }
        .onChange(of: viewModel.showLoginView) { _, open in if open { signInSpeech.stop() } }
        .onChange(of: viewModel.showPrivacyPolicy) { _, open in if open { signInSpeech.stop() } }
        .fullScreenCover(isPresented: $viewModel.showHomeView) {
            //HomeView()
            OnboardingFlowView()
        }
        .fullScreenCover(isPresented: $viewModel.showLoginView) {
            LoginSkipView()
        }
        .fullScreenCover(isPresented: $viewModel.showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .trackScreen(
            "SignInView",
            metadata: [
                "ui_guide": "Welcome to Limi AI. Use Continue with Email (opens full login), Continue with Google, or Guest. You can open Privacy Policy from here."
            ]
        )
    }

    @ViewBuilder
    private func signInColumn(maxWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image("LoginViewLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: min(160, maxWidth * 0.85), height: 32)
                .padding(.bottom, 10)
                .padding(.top, 50)

            SignInSpeechAlignedHeadline(speech: signInSpeech)
                .frame(maxWidth: .infinity)

            Spacer()

            Text("Login with the options below")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, 16)



            Button(action: { viewModel.showEmailLogin() }) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16, weight: .regular))
                    Text("Continue with Email")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.themeWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .background(Color.appSurfacePrimary)
            .cornerRadius(16)
            .signInSpeechLoginHighlight(signInSpeech.loginSpeechHighlight, target: .email)

            Button(action: {
                viewModel.signInWithGoogle()
            }) {
                HStack(spacing: 8) {
                    Image("google")
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text("Continue with Google")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appSurfacePrimary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .signInSpeechLoginHighlight(signInSpeech.loginSpeechHighlight, target: .google)
            .padding(.top, 10)

            Button {
                viewModel.continueAsGuest()
            } label: {
                Text("Continue as a Guest")
                    .font(LimiTypography.body)
                    .foregroundColor(.appTextPrimary)
                    .kerning(0)
                    .multilineTextAlignment(.center)
                    .underline()
                    .padding()
            }
            .buttonStyle(.plain)
            .tapScale()
            .signInSpeechLoginHighlight(signInSpeech.loginSpeechHighlight, target: .guest)

            legalAgreementFooter
                .padding(.top, 8)
        }
        .frame(maxWidth: maxWidth)
    }

    private var legalAgreementFooter: some View {
        VStack(spacing: 10) {
            Text("By continuing you are agreeing to our")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button(action: { print("Terms tapped") }) {
                    Text("Terms")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .underline(true, color: Color.appTextQuiet)
                }
                Text("·")
                    .foregroundColor(Color.appTextQuiet.opacity(0.6))
                Button(action: { viewModel.showPrivacy() }) {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .underline(true, color: Color.appTextQuiet)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

}

// MARK: - Speech sync: headline first, then login script (chained utterances)

private enum SignInSpeechPhase {
    case headline
    case loginScript
}

/// Which login control to briefly emphasize when the voice hits matching phrases in `SignInLoginScriptCopy.display`.
private enum SignInLoginSpeechHighlight: Equatable {
    case idle
    case email
    case google
    case guest
}

/// Scale + soft white border glow when TTS highlights this login option.
private struct SignInSpeechLoginButtonHighlight: ViewModifier {
    let highlight: SignInLoginSpeechHighlight
    let target: SignInLoginSpeechHighlight

    private var active: Bool { highlight == target }

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.07 : 1.0)
            .shadow(color: Color.white.opacity(active ? 0.9 : 0), radius: 6, x: 0, y: 0)
            .shadow(color: Color.white.opacity(active ? 0.55 : 0), radius: 14, x: 0, y: 2)
            .shadow(color: Color.white.opacity(active ? 0.35 : 0), radius: 24, x: 0, y: 4)
            .animation(.spring(response: 0.34, dampingFraction: 0.72), value: highlight)
    }
}

private extension View {
    func signInSpeechLoginHighlight(_ highlight: SignInLoginSpeechHighlight, target: SignInLoginSpeechHighlight) -> some View {
        modifier(SignInSpeechLoginButtonHighlight(highlight: highlight, target: target))
    }
}

private final class SignInScreenSpeechSync: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var displayedText = ""
    @Published private(set) var headlineFinished = false
    @Published private(set) var loginSpeechHighlight: SignInLoginSpeechHighlight = .idle

    private let synthesizer = AVSpeechSynthesizer()
    private var fullText = ""
    private var phase: SignInSpeechPhase = .headline

    private var didPulseEmail = false
    private var didPulseGoogle = false
    private var didPulseGuest = false

    /// Character ranges in `SignInLoginScriptCopy.display` for phrase → button mapping (must stay in sync with copy).
    private static let scriptPhraseRanges: (email: NSRange, google: NSRange, guest: NSRange)? = {
        let s = SignInLoginScriptCopy.display as NSString
        let email = s.range(of: "continue with your email", options: .caseInsensitive)
        let google = s.range(of: "Continue with Google", options: [])
        let guest = s.range(of: "continue as a guest", options: .caseInsensitive)
        guard email.location != NSNotFound, google.location != NSNotFound, guest.location != NSNotFound else {
            return nil
        }
        return (email, google, guest)
    }()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        phase = .headline
        fullText = SignInHeadlineCopy.display
        displayedText = ""
        headlineFinished = false
        loginSpeechHighlight = .idle
        didPulseEmail = false
        didPulseGoogle = false
        didPulseGuest = false

        enqueueUtterance(text: fullText)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        headlineFinished = true
        loginSpeechHighlight = .idle
    }

    private func enqueueUtterance(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: preferredVoiceLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    private func preferredVoiceLanguageCode() -> String {
        for lang in Locale.preferredLanguages {
            if AVSpeechSynthesisVoice.speechVoices().contains(where: { $0.language == lang }) {
                return lang
            }
        }
        return "en-US"
    }

    private func pulseHighlight(_ target: SignInLoginSpeechHighlight) {
        loginSpeechHighlight = target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
            guard let self = self else { return }
            if self.loginSpeechHighlight == target {
                self.loginSpeechHighlight = .idle
            }
        }
    }

    private func detectLoginScriptPhrasePulses(characterRange: NSRange) {
        guard let ranges = Self.scriptPhraseRanges else { return }
        if !didPulseEmail, NSIntersectionRange(characterRange, ranges.email).length > 0 {
            didPulseEmail = true
            pulseHighlight(.email)
        }
        if !didPulseGoogle, NSIntersectionRange(characterRange, ranges.google).length > 0 {
            didPulseGoogle = true
            pulseHighlight(.google)
        }
        if !didPulseGuest, NSIntersectionRange(characterRange, ranges.guest).length > 0 {
            didPulseGuest = true
            pulseHighlight(.guest)
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let ns = fullText as NSString
        let end = min(NSMaxRange(characterRange), ns.length)
        DispatchQueue.main.async {
            switch self.phase {
            case .headline:
                self.displayedText = ns.substring(to: end)
            case .loginScript:
                self.detectLoginScriptPhrasePulses(characterRange: characterRange)
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            switch self.phase {
            case .headline:
                self.displayedText = SignInHeadlineCopy.display
                self.headlineFinished = true
                self.phase = .loginScript
                self.fullText = SignInLoginScriptCopy.display
                self.enqueueUtterance(text: self.fullText)
            case .loginScript:
                self.loginSpeechHighlight = .idle
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if self.phase == .headline {
                self.displayedText = SignInHeadlineCopy.display
            }
            self.headlineFinished = true
            self.loginSpeechHighlight = .idle
        }
    }
}

// MARK: - Center neural orb (matches `OrbWithSpeechCard.orbView` in OnboardingView)

private struct SignInCenterNeuralOrb: View {
    let orbSize: CGFloat

    @State private var breathe = false
    @State private var rotation: Double = 0
    @State private var wiggle = false
    /// Organic float (different periods → non-repetitive motion).
    @State private var driftX = false
    @State private var driftY = false
    /// Outer halo “breathing” brightness.
    @State private var glowPulse = false
    /// Core luminosity / shadow throb.
    @State private var coreShimmer = false
    @State private var haloRotation: Double = 0

    private let cyanAccent = Color(hex: "00E5FF")
    private let violetCore = Color(hex: "9B5DE5")

    private var clampedSize: CGFloat {
        min(max(orbSize, 56), 150)
    }

    var body: some View {
        ZStack {
            // Soft outer halo — slow counter-rotation + pulse for “alive” energy
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            cyanAccent.opacity(glowPulse ? 0.35 : 0.18),
                            violetCore.opacity(glowPulse ? 0.22 : 0.1),
                            cyanAccent.opacity(0.08),
                            violetCore.opacity(glowPulse ? 0.25 : 0.12),
                            cyanAccent.opacity(glowPulse ? 0.3 : 0.15)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.2
                )
                .frame(width: clampedSize * 2.15, height: clampedSize * 2.15)
                .rotationEffect(.degrees(-haloRotation * 0.65))
                .blur(radius: glowPulse ? 2.2 : 1.0)
                .opacity(0.85)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            cyanAccent.opacity(glowPulse ? 0.16 : 0.08),
                            violetCore.opacity(glowPulse ? 0.09 : 0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: clampedSize * 0.25,
                        endRadius: clampedSize * 1.5
                    )
                )
                .frame(width: clampedSize * 2.4, height: clampedSize * 2.4)
                .scaleEffect(breathe ? 1.06 : 0.94)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [cyanAccent.opacity(0.4), violetCore.opacity(0.2), cyanAccent.opacity(0.1), violetCore.opacity(0.4), cyanAccent.opacity(0.4)],
                        center: .center
                    ),
                    lineWidth: 0.8
                )
                .frame(width: clampedSize + 6, height: clampedSize + 6)
                .rotationEffect(.degrees(rotation))
                .blur(radius: 0.5)

            Image("neuralOrb")
                .resizable()
                .scaledToFill()
                .frame(width: clampedSize, height: clampedSize)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [
                                cyanAccent.opacity(0.35 + (coreShimmer ? 0.12 : 0)),
                                violetCore.opacity(0.15 + (coreShimmer ? 0.08 : 0)),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                )
                .shadow(color: cyanAccent.opacity(0.25 + (coreShimmer ? 0.2 : 0)), radius: coreShimmer ? 16 : 10)
                .shadow(color: violetCore.opacity(0.12 + (coreShimmer ? 0.12 : 0)), radius: coreShimmer ? 22 : 16)
                .scaleEffect((breathe ? 1.02 : 0.98) * (coreShimmer ? 1.03 : 0.97))
                .rotationEffect(.degrees(wiggle ? 4 : 0))
        }
        .offset(x: driftX ? 4 : -4, y: driftY ? -5 : 5)
        .animation(.spring(response: 4.2, dampingFraction: 0.78), value: driftX)
        .animation(.spring(response: 5.0, dampingFraction: 0.82), value: driftY)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { rotation = 360 }
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { haloRotation = 360 }
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.3)) { wiggle = true }

        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) { driftY = true }
        withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true).delay(0.45)) { driftX = true }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glowPulse = true }
        withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true).delay(0.2)) { coreShimmer = true }
    }
}

private struct SignInSpeechAlignedHeadline: View {
    @ObservedObject var speech: SignInScreenSpeechSync

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 4) {
                Text(speech.displayedText)
                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 62, alignment: .top)

                if !speech.headlineFinished {
                    SignInTypingCursor()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SignInTypingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color(hex: "00E5FF"))
            .frame(width: 2, height: 18)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

#Preview {
    SignInView()
}

// Same response model used in LoginView for installer user API
