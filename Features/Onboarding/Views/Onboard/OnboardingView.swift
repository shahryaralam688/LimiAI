import SwiftUI

// MARK: - AI Bubble Storyboard Onboarding

struct OnboardingView: View {
    @StateObject private var onboardingSpeech = OnboardingSpeechSync()
    @State private var currentPage = 0
    @State private var showSignIn = false
    @State private var showPostStoryboardLocation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("globalUserLocation") private var storedLocation = ""

    private let totalPages = 4

    var body: some View {
        ZStack {
            if showSignIn {
                SignInView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                storyboardContent
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showPostStoryboardLocation) {
            LocationStorageView(
                onFinished: {
                    showPostStoryboardLocation = false
                    finishOnboardingAndShowSignIn()
                },
                showSkipButton: true
            )
        }
        .onAppear { FloatingAssistantManager.shared.hide() }
        .onChange(of: showSignIn) { _, showing in
            if showing { onboardingSpeech.stop() }
        }
        .onChange(of: showPostStoryboardLocation) { _, showing in
            if showing { onboardingSpeech.stop() }
        }
        .onDisappear {
            onboardingSpeech.stop()
            FloatingAssistantManager.shared.refreshFloatingVisibility()
        }
    }

    private func finishOnboardingAndShowSignIn() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.6)) { showSignIn = true }
        FloatingAssistantManager.shared.refreshFloatingVisibility()
    }

    private func handleStoryboardActivated() {
        let trimmed = storedLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            showPostStoryboardLocation = true
        } else {
            finishOnboardingAndShowSignIn()
        }
    }

    private func storyboardMetadata(page: Int) -> [String: String] {
        var m: [String: String] = [
            "page_index": "\(page)",
            "page_number": "\(page + 1)",
            "total_pages": "\(totalPages)",
            "surface": "ai_storyboard_onboarding"
        ]
        switch page {
        case 0: m["ui_guide"] = "Intro: meet Limi AI — swipe left for the next story."
        case 1: m["ui_guide"] = "Talk naturally; Limi controls lights and routines from context."
        case 2: m["ui_guide"] = "The orb can be dragged; tap for voice, long-press for more later."
        case 3: m["ui_guide"] = "Final frame: larger orb — Continue to sign in or enable the assistant."
        default: break
        }
        return m
    }

    private var storyboardContent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                TabView(selection: $currentPage) {
                    StoryboardPage(backgroundImage: "storyboard_bg_1", screenSize: geo.size).tag(0).ignoresSafeArea()
                    StoryboardPage(backgroundImage: "storyboard_bg_2", screenSize: geo.size).tag(1).ignoresSafeArea()
                    StoryboardPage(backgroundImage: "storyboard_bg_3", screenSize: geo.size).tag(2).ignoresSafeArea()
                    StoryboardPage(backgroundImage: "storyboard_bg_4", screenSize: geo.size).tag(3).ignoresSafeArea()
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()

                OrbWithSpeechCard(
                    currentPage: currentPage,
                    screenWidth: w,
                    screenHeight: h,
                    speech: onboardingSpeech
                )
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    BottomContent(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onComplete: handleStoryboardActivated
                    )
                }
            }
            .onAppear {
                ContextManager.shared.updateContext(
                    screen: "OnboardingStoryboard",
                    metadata: storyboardMetadata(page: currentPage)
                )
                onboardingSpeech.speakPage(currentPage)
            }
            .onChange(of: currentPage) { _, new in
                ContextManager.shared.updateContext(
                    screen: "OnboardingStoryboard",
                    metadata: storyboardMetadata(page: new)
                )
                onboardingSpeech.speakPage(new)
            }
        }
    }
}

// MARK: - Page Background

private struct StoryboardPage: View {
    let backgroundImage: String
    let screenSize: CGSize

    var body: some View {
        ZStack {
            NeuTheme.baseCanvas.ignoresSafeArea()
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: screenSize.width, height: screenSize.height)
                .clipped()
                .opacity(0.30)
                .ignoresSafeArea()
            AmbientParticlesView(count: 15)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Typing Text View

private struct TypingText: View {
    let fullText: String
    let speed: Double
    let font: Font
    let color: Color
    let alignment: TextAlignment

    @State private var displayed = ""
    @State private var charIndex = 0
    @State private var isComplete = false

    init(_ text: String, speed: Double = 0.056, font: Font = .system(size: 16, weight: .semibold, design: .rounded), color: Color = .appTextPrimary, alignment: TextAlignment = .leading) {
        self.fullText = text
        self.speed = speed
        self.font = font
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(displayed)
                .font(font)
                .foregroundColor(color)
                .multilineTextAlignment(alignment)
                .lineSpacing(3)

            if !isComplete {
                TypingCursor()
            }
        }
        .onAppear { startTyping() }
        .onChange(of: fullText) { _, _ in
            displayed = ""
            charIndex = 0
            isComplete = false
            startTyping()
        }
    }

    private func startTyping() {
        let chars = Array(fullText)
        func typeNext() {
            guard charIndex < chars.count else {
                isComplete = true
                return
            }
            displayed.append(chars[charIndex])
            charIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + speed) { typeNext() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { typeNext() }
    }
}

// MARK: - Typing Cursor

private struct TypingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color.appInfoBright)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Orb + Speech Card

private struct OrbWithSpeechCard: View {
    let currentPage: Int
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    @ObservedObject var speech: OnboardingSpeechSync

    @State private var breathe = false
    @State private var rotation: Double = 0
    @State private var wiggle = false

    private let infoAccent = Color.appInfoBright
    private let violetCore = Color.appPurple

    private var orbSize: CGFloat { currentPage == 3 ? 160 : 56 }

    private var orbCenter: CGPoint {
        switch currentPage {
        case 0:  return CGPoint(x: 52, y: screenHeight * 0.20)
        case 1:  return CGPoint(x: screenWidth - 52, y: screenHeight * 0.45)
        case 2:  return CGPoint(x: 52, y: screenHeight * 0.70)
        default: return CGPoint(x: screenWidth / 2, y: screenHeight * 0.24)
        }
    }

    var body: some View {
        ZStack {
            if currentPage < 3 {
                speechCardView
            }
            orbView
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: currentPage)
        .onAppear { startAnimations() }
    }

    // MARK: - Orb

    private var orbView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            infoAccent.opacity(currentPage == 3 ? 0.22 : 0.10),
                            violetCore.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: orbSize * 0.25,
                        endRadius: orbSize * 1.5
                    )
                )
                .frame(width: orbSize * 2.4, height: orbSize * 2.4)
                .scaleEffect(breathe ? 1.06 : 0.94)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [infoAccent.opacity(0.4), violetCore.opacity(0.2), infoAccent.opacity(0.1), violetCore.opacity(0.4), infoAccent.opacity(0.4)],
                        center: .center
                    ),
                    lineWidth: currentPage == 3 ? 1.5 : 0.8
                )
                .frame(width: orbSize + 6, height: orbSize + 6)
                .rotationEffect(.degrees(rotation))
                .blur(radius: 0.5)

            Image("neuralOrb")
                .resizable()
                .scaledToFill()
                .frame(width: orbSize, height: orbSize)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [infoAccent.opacity(0.35), violetCore.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: currentPage == 3 ? 1.2 : 0.6
                    )
                )
                .shadow(color: infoAccent.opacity(currentPage == 3 ? 0.5 : 0.3), radius: currentPage == 3 ? 22 : 10)
                .shadow(color: violetCore.opacity(currentPage == 3 ? 0.35 : 0.15), radius: currentPage == 3 ? 38 : 16)
                .scaleEffect(breathe ? 1.02 : 0.98)
                .rotationEffect(.degrees(currentPage == 2 && wiggle ? 4 : 0))
        }
        .position(orbCenter)
    }

    // MARK: - Speech Card with Typing Animation

    private var speechCardView: some View {
        let cardX: CGFloat
        let cardY: CGFloat
        let cardWidth: CGFloat = screenWidth * 0.68
        /// Stable outer height so the neumorphic card doesn’t resize while text types (includes swipe line).
        let cardOuterHeight: CGFloat = min(max(screenHeight * 0.29, 196), 252)
        let innerTypingHeight: CGFloat = cardOuterHeight - 36
        let align: TextAlignment

        switch currentPage {
        case 0:
            cardX = screenWidth * 0.56
            cardY = screenHeight * 0.20
            align = .leading
        case 1:
            cardX = screenWidth * 0.42
            cardY = screenHeight * 0.45
            align = .leading
        default:
            cardX = screenWidth * 0.56
            cardY = screenHeight * 0.70 - 80
            align = .leading
        }

        return VStack(alignment: .leading, spacing: 10) {
            SequentialSpeechAlignedCard(
                speech: speech,
                pageId: currentPage,
                alignment: align,
                fixedContentHeight: innerTypingHeight
            )
        }
        .padding(18)
        .frame(width: cardWidth, height: cardOuterHeight, alignment: .top)
        .neuElevation(level: 1, cornerRadius: 20)
        .position(x: cardX, y: cardY)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { rotation = 360 }
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.3)) { wiggle = true }
    }
}

// MARK: - Speech-aligned card (text follows `AVSpeechSynthesizer` timing)

private struct SequentialSpeechAlignedCard: View {
    @ObservedObject var speech: OnboardingSpeechSync
    let pageId: Int
    let alignment: TextAlignment
    let fixedContentHeight: CGFloat

    private var headlineTarget: String { OnboardingStoryboardCopy.headline(pageId) }
    private var detailTarget: String { OnboardingStoryboardCopy.detail(pageId) }

    private var headlineDisplay: String {
        guard speech.currentPage == pageId else { return "" }
        return speech.headlineText
    }

    private var detailDisplay: String {
        guard speech.currentPage == pageId else { return "" }
        return speech.detailText
    }

    private var swipeDisplay: String {
        guard speech.currentPage == pageId else { return "" }
        return speech.swipeHintText
    }

    private var swipeTarget: String { OnboardingStoryboardCopy.swipeInstruction }

    private var headlineDone: Bool {
        !headlineTarget.isEmpty && headlineDisplay == headlineTarget
    }

    private var detailDone: Bool {
        !detailTarget.isEmpty && detailDisplay == detailTarget
    }

    private var showHeadlineCursor: Bool {
        speech.currentPage == pageId && !speech.isPageSpeechComplete && headlineDisplay != headlineTarget
    }

    private var showDetailCursor: Bool {
        speech.currentPage == pageId && !speech.isPageSpeechComplete && headlineDone && detailDisplay != detailTarget
    }

    private var showSwipeCursor: Bool {
        speech.currentPage == pageId && !speech.isPageSpeechComplete && detailDone && swipeDisplay != swipeTarget
    }

    var body: some View {
        VStack(alignment: alignment == .trailing ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                Text(headlineDisplay)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(alignment)
                    .lineSpacing(3)
                if showHeadlineCursor {
                    TypingCursor()
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)

            if headlineDone {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(detailDisplay)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(alignment)
                        .lineSpacing(4)
                    if showDetailCursor {
                        TypingCursor()
                    }
                }
                .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
            }

            if detailDone {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(swipeDisplay)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextMuted)
                        .multilineTextAlignment(alignment)
                        .lineSpacing(3)
                    if showSwipeCursor {
                        TypingCursor()
                    }
                }
                .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
            }
        }
        .frame(height: fixedContentHeight, alignment: .top)
        .clipped()
        .id("seqcard_\(pageId)")
    }
}

// MARK: - Swipe Hint (pulsing text + arrows)

private struct SwipeHint: View {
    @State private var pulse = false

    private let cyanAccent = Color.appInfoBright

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(cyanAccent.opacity(0.4))

            Text("Swipe to continue")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.appTextMuted)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(cyanAccent.opacity(0.4))
        }
        .opacity(pulse ? 1.0 : 0.4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Bottom Content

private struct BottomContent: View {
    let currentPage: Int
    let totalPages: Int
    let onComplete: () -> Void

    private let cyanAccent = Color.appInfoBright

    private var title: String {
        switch currentPage {
        case 0: return "Meet Limi AI"
        case 1: return "Natural Conversation"
        case 2: return "Always Within Reach"
        default: return "Your AI, Always Ready"
        }
    }

    private var subtitle: String {
        switch currentPage {
        case 0: return "Intelligence that blends into your space"
        case 1: return "Voice, touch, or full automation"
        case 2: return "Tuck it away. Call it back anytime."
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if currentPage == 3 {
                finalScreen
            } else {
                standardBottom
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 46)
    }

    private var standardBottom: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            SwipeHint()
                .padding(.top, 14)

            pageIndicators
                .padding(.top, 6)
        }
    }

    private var finalScreen: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Text(OnboardingStoryboardCopy.page3Subtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(icon: "hand.tap", label: "Tap", detail: "to start a conversation")
                InstructionRow(icon: "hand.tap.fill", label: "Tap again", detail: "to end the session")
                InstructionRow(icon: "arrow.up.and.down.and.arrow.left.and.right", label: "Drag", detail: "to reposition anywhere")
            }
            .padding(20)
            .neuElevation(level: 1, cornerRadius: 22)

            ActivateLimiButton(action: onComplete)
                .padding(.top, 8)

            pageIndicators
                .padding(.top, 4)
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { idx in
                if idx == currentPage {
                    Capsule()
                        .fill(cyanAccent)
                        .frame(width: 24, height: 6)
                } else {
                    Circle()
                        .fill(Color.appBorderPrimary.opacity(0.45))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
    }
}

// MARK: - Instruction Row (final onboarding screen)

private struct InstructionRow: View {
    let icon: String
    let label: String
    let detail: String

    private let cyanAccent = Color.appInfoBright

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(cyanAccent)
                .frame(width: 28)
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Text(detail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Activate Limi AI Button (animated gradient border)

private struct ActivateLimiButton: View {
    let action: () -> Void
    @State private var gradientRotation: Double = 0

    private let cyanAccent = Color.appInfoBright

    private let borderColors: [Color] = [
        Color.appInfoBright,
        Color.appBrandSecondary,
        Color.appIndigo,
        Color.appPink,
        Color.appOrange,
        Color.appInfoBright
    ]

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(cyanAccent)
                Text("Activate Limi AI")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextMuted)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(NeuTheme.baseSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: borderColors,
                            center: .center,
                            angle: .degrees(gradientRotation)
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: cyanAccent.opacity(0.15), radius: 16, y: 6)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
}

#Preview {
    OnboardingView()
}
