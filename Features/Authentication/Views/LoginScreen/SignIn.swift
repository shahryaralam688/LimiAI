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
    static let display = "Here when you need me.\nThoughtful by design."
}

/// Spoken after the headline (voice only — buttons pulse on key phrases).
private enum SignInLoginScriptCopy {
    static let display = """
    Let's get you settled in — pick the option that feels right for you.
    You can continue with your email, or sign in quickly using the "Continue with Google" button. If you'd like to explore first, feel free to continue as a guest.
    By continuing, you agree to our Terms and Privacy Policy.
    """
}

struct SignInView: View {
    var managesPostLoginNavigation: Bool = true

    @StateObject private var viewModel: SignInViewModel
    @StateObject private var signInSpeech = SignInScreenSpeechSync()

    init(managesPostLoginNavigation: Bool = true) {
        self.managesPostLoginNavigation = managesPostLoginNavigation
        _viewModel = StateObject(wrappedValue: SignInViewModel(managesPostLoginNavigation: managesPostLoginNavigation))
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalInset: CGFloat = 24
            let maxColumn = min(geo.size.width - horizontalInset * 2, 400)
            let bottomInset = max(geo.safeAreaInsets.bottom, 12) + 8
            let orbSize = min(geo.size.width, geo.size.height) * 0.48

            ZStack {
                // Fills any gap if layout is inset; keeps bottom bar from flashing white.
                Color.appCanvasPrimary
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    signInColumn(maxWidth: maxColumn, orbSize: orbSize)
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
            if viewModel.postLoginShowsHomeDirectly {
                HomeView()
            } else {
                OnboardingFlowView()
            }
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
                "ui_guide": "Welcome to Limi. Choose Continue with Email, Continue with Google, or continue as a guest. Privacy Policy is available here."
            ]
        )
    }

    @ViewBuilder
    private func signInColumn(maxWidth: CGFloat, orbSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            SignInAnimatedLogo(maxWidth: maxWidth)

            SignInSpeechAlignedHeadline(speech: signInSpeech)
                .frame(maxWidth: .infinity)

            PlexusOrbView(size: orbSize, isActive: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
                .allowsHitTesting(false)

            Text("Choose how you'd like to continue")
                .font(LimiTypography.subheadline)
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, 16)


            Button(action: { viewModel.showEmailLogin() }) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(LimiTypography.body)
                    Text("Continue with Email")
                        .font(LimiTypography.callout)
                }
                .foregroundColor(.appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .limiPanel(cornerRadius: 16)
            .signInSpeechLoginHighlight(signInSpeech.loginSpeechHighlight, target: .email)

            Button(action: {
                viewModel.signInWithGoogle()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                    } else {
                        Image("google")
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text("Continue with Google")
                            .font(LimiTypography.callout)
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .limiPanel(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .disabled(viewModel.isLoading)
            .signInSpeechLoginHighlight(signInSpeech.loginSpeechHighlight, target: .google)
            .padding(.top, 10)

            if let error = viewModel.signInErrorMessage {
                Text(error)
                    .font(LimiTypography.footnote)
                    .foregroundColor(.appDanger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

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
            Text("By continuing, you agree to our")
                .font(LimiTypography.caption)
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button(action: { }) {
                    Text("Terms")
                        .font(LimiTypography.caption)
                        .foregroundColor(Color.appTextQuiet)
                        .underline(true, color: Color.appTextQuiet)
                }
                Text("·")
                    .foregroundColor(Color.appTextQuiet.opacity(0.6))
                Button(action: { viewModel.showPrivacy() }) {
                    Text("Privacy Policy")
                        .font(LimiTypography.caption)
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
            .shadow(color: Color.themeWhite.opacity(active ? 0.9 : 0), radius: 6, x: 0, y: 0)
            .shadow(color: Color.themeWhite.opacity(active ? 0.55 : 0), radius: 14, x: 0, y: 2)
            .shadow(color: Color.themeWhite.opacity(active ? 0.35 : 0), radius: 24, x: 0, y: 4)
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

// MARK: - Animated top logo

private struct SignInAnimatedLogo: View {
    let maxWidth: CGFloat

    @State private var appeared = false
    @State private var breathe = false

    private var logoHeight: CGFloat {
        min(104, max(88, maxWidth * 0.24))
    }

    var body: some View {
        Image("logoSplash")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: logoHeight)
            .scaleEffect(appeared ? (breathe ? 1.03 : 0.98) : 0.86)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? (breathe ? -3 : 3) : 14)
            .shadow(color: Color.brandAction.opacity(appeared ? 0.22 : 0), radius: appeared ? 18 : 0, y: 6)
            .padding(.bottom, 12)
            .padding(.top, 72)
            .onAppear {
                withAnimation(LimiMotion.gentle) {
                    appeared = true
                }
                withAnimation(LimiMotion.breathe.delay(0.45)) {
                    breathe = true
                }
            }
    }
}

private struct SignInSpeechAlignedHeadline: View {
    @ObservedObject var speech: SignInScreenSpeechSync

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 4) {
                Text(speech.displayedText)
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)
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
            .fill(Color.brandHighlight)
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
