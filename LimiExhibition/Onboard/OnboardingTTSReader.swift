import Foundation
import AVFoundation

// MARK: - Shared copy (UI + TTS must match)

enum OnboardingStoryboardCopy {
    static func headline(_ page: Int) -> String {
        switch page {
        case 0: return "Hey! I'm Limi — your ambient AI assistant."
        case 1: return "Talk to me naturally — I understand context."
        case 2: return "I go wherever you need me."
        default: return ""
        }
    }

    static func detail(_ page: Int) -> String {
        switch page {
        case 0: return "I live inside your space, always ready to help. No app switching, no searching — just ask."
        case 1: return "\"Turn the lights warm\" or \"Set a morning routine\" — I handle your lights, schedules, and environment intelligently."
        case 2: return "Drag me to any edge of your screen. I stay tucked away until you tap. Your space, your rules."
        default: return ""
        }
    }

    /// Spoken after the card copy on pages 0–2; keep in sync with `SequentialSpeechAlignedCard` swipe line.
    static let swipeInstruction = "Swipe to go to the next screen."

    // MARK: Page 3 (static UI; copy used for TTS only)

    static let page3Subtitle = "The operating system for your physical space"

    /// Full narration for page 3 — matches title, subtitle, and instruction rows on the last screen (no UI animation).
    static let page3Speech = "Your AI, Always Ready. The operating system for your physical space. Tap to start a conversation. Tap again to end the session. Drag to reposition anywhere. When you're ready, tap Activate Limi AI to continue."
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
