import Foundation
import AVFoundation

// MARK: - Shared copy (UI + TTS must match)

enum OnboardingStoryboardCopy {
    static func headline(_ page: Int) -> String {
        switch page {
        case 0: return "Hi, I'm Limi — your AI companion for everyday life."
        case 1: return "Talk to me like you would a friend — I'll follow along."
        case 2: return "I'm always close when you need me."
        default: return ""
        }
    }

    static func detail(_ page: Int) -> String {
        switch page {
        case 0: return "I'm here in your space whenever you need me — no menus, no hunting around. Just ask."
        case 1: return "Say something like \"Turn the lights warm\" or \"Set a morning routine\" — I'll take care of the mood, the timing, and the little details."
        case 2: return "Move me anywhere on your screen — I'll stay quietly nearby until you tap. Your space, thoughtfully yours."
        default: return ""
        }
    }

    /// Spoken after the card copy on pages 0–2; keep in sync with `SequentialSpeechAlignedCard` swipe line.
    static let swipeInstruction = "Swipe when you're ready for the next step."

    // MARK: Page 3 (static UI; copy used for TTS only)

    static let page3Subtitle = "The AI-Native Operating System for your physical space"

    /// Full narration for page 3 — matches title, subtitle, and instruction rows on the last screen (no UI animation).
    static let page3Speech = "Ready whenever you are. The AI-Native Operating System for your physical space. Tap to say hello. Tap again when you're done chatting. Drag to move me anywhere you like. When you're ready, tap Let's begin to continue."
}

// MARK: - Speech ↔ UI sync (system TTS only)

final class OnboardingSpeechSync: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var headlineText = ""
    @Published private(set) var detailText = ""
    @Published private(set) var swipeHintText = ""
    @Published private(set) var isPageSpeechComplete = true

    private(set) var currentPage = 0

    private let synthesizer = AVSpeechSynthesizer()

    private var fullSpeechText = ""
    private var speechHeadline = ""
    private var speechDetail = ""
    private var speechSwipe = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPageSpeechComplete = true
    }

    func speakPage(_ page: Int) {
        stop()
        currentPage = page
        headlineText = ""
        detailText = ""
        swipeHintText = ""
        isPageSpeechComplete = false

        switch page {
        case 0...2:
            speechHeadline = OnboardingStoryboardCopy.headline(page)
            speechDetail = OnboardingStoryboardCopy.detail(page)
            speechSwipe = OnboardingStoryboardCopy.swipeInstruction
            fullSpeechText = speechHeadline + "\n" + speechDetail + "\n" + speechSwipe
        case 3:
            speechHeadline = ""
            speechDetail = ""
            speechSwipe = ""
            fullSpeechText = OnboardingStoryboardCopy.page3Speech
        default:
            speechHeadline = ""
            speechDetail = ""
            speechSwipe = ""
            fullSpeechText = ""
            isPageSpeechComplete = true
            return
        }

        guard !fullSpeechText.isEmpty else {
            isPageSpeechComplete = true
            return
        }

        let utterance = AVSpeechUtterance(string: fullSpeechText)
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

    private func applyReveal(end: Int) {
        let full = fullSpeechText as NSString
        let safeEnd = min(end, full.length)

        if currentPage < 3 {
            let h = speechHeadline as NSString
            let d = speechDetail as NSString
            let s = speechSwipe as NSString
            let hLen = h.length
            let dLen = d.length
            let detailStart = hLen + 1
            let detailExclusiveEnd = detailStart + dLen
            let swipeStart = detailExclusiveEnd + 1

            if safeEnd <= hLen {
                headlineText = h.substring(to: safeEnd)
                detailText = ""
                swipeHintText = ""
            } else if safeEnd <= detailExclusiveEnd {
                headlineText = speechHeadline
                let detailLen = safeEnd - detailStart
                detailText = d.substring(to: min(max(0, detailLen), dLen))
                swipeHintText = ""
            } else {
                headlineText = speechHeadline
                detailText = speechDetail
                let swipeLen = safeEnd - swipeStart
                swipeHintText = s.substring(to: min(max(0, swipeLen), s.length))
            }
        }
        // Page 3: static UI only — TTS plays full `page3Speech` without progressive text.
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let end = NSMaxRange(characterRange)
        DispatchQueue.main.async {
            self.applyReveal(end: end)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.applyReveal(end: (self.fullSpeechText as NSString).length)
            self.isPageSpeechComplete = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.applyReveal(end: (self.fullSpeechText as NSString).length)
            self.isPageSpeechComplete = true
        }
    }
}
