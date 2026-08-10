import Combine
import SwiftUI

@MainActor
final class VoiceViewModel: ObservableObject {
    @Published var conversationHistory: [ChatMessage] = []
    @Published var textInput = ""
    @Published var currentTranscription = ""
    @Published var assistantState: AssistantVisualState = .idle
    @Published var isChatMode = false
    @Published var isRecordingFromChat = false
    @Published var showAIConnection = false

    private let session: VoiceSessionControlling
    private var cancellables = Set<AnyCancellable>()
    private var didAutoConnect = false

    var connectionState: VoiceConnectionState { session.connectionState }
    var lastUserVisibleError: String? { session.lastUserVisibleError }

    init(session: VoiceSessionControlling) {
        self.session = session
        wireObservers()
    }

    convenience init(backendBaseURL: URL) {
        self.init(session: VoiceSessionService(backendBaseURL: backendBaseURL))
    }

    func onAppear() {
        guard !didAutoConnect else { return }
        didAutoConnect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.session.connectionState == .disconnected else { return }
            self.session.start()
            self.assistantState = .listening
        }
    }

    func onDisappear() {
        let state = session.connectionState
        if state == .connected || state == .connecting {
            session.stop()
        }
    }

    func clearUserVisibleError() {
        session.lastUserVisibleError = nil
    }

    func enterChatMode() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isChatMode = true
        }
    }

    func exitChatMode() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isChatMode = false
        }
    }

    func toggleVoice() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let state = session.connectionState
            if state == .connected || state == .connecting {
                session.stop()
                assistantState = .idle
            } else {
                session.start()
                assistantState = .listening
            }
        }
    }

    func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            conversationHistory.append(ChatMessage(content: text, isUser: true, timestamp: Date()))
            textInput = ""
        }
        if !isChatMode {
            enterChatMode()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.conversationHistory.append(
                    ChatMessage(
                        content: "I received your message. Voice responses come through the live connection.",
                        isUser: false,
                        timestamp: Date()
                    )
                )
            }
        }
    }

    func handleChatSendAction() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isRecordingFromChat.toggle()
            toggleVoice()
        } else {
            sendTextMessage()
        }
    }

    func connectionColor(for state: VoiceConnectionState) -> Color {
        switch state {
        case .connected: return .appSuccess
        case .connecting: return .appWarning
        case .error: return .appDanger
        case .disconnected: return .appTextMuted
        }
    }

    func connectionLabel(for state: VoiceConnectionState) -> String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .error: return "Error"
        case .disconnected: return "Offline"
        }
    }

    func orbHue(for state: AssistantVisualState) -> Float {
        switch state {
        case .idle: return 0.72
        case .listening: return 0.58
        case .thinking: return 0.50
        case .speaking: return 0.30
        }
    }

    func orbHoverIntensity(for state: AssistantVisualState) -> Float {
        switch state {
        case .idle: return 0.15
        case .listening: return 0.45
        case .thinking: return 0.30
        case .speaking: return 0.65
        }
    }

    func orbRotateOnHover(for state: AssistantVisualState) -> Bool {
        state == .thinking || state == .speaking
    }

    func orbForceHover(for state: AssistantVisualState) -> Bool {
        state != .idle
    }

    func orbGlowColor(for state: AssistantVisualState) -> Color {
        switch state {
        case .idle: return .brandActionDark
        case .listening: return .brandAction
        case .thinking: return .brandHighlight
        case .speaking: return .brandAction
        }
    }

    func statusTitle(for state: AssistantVisualState) -> String {
        switch state {
        case .idle: return "I'm here"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking"
        }
    }

    func statusSubtitle(for state: AssistantVisualState) -> String {
        switch state {
        case .idle: return "Say anything"
        case .listening: return "I can hear you"
        case .thinking: return "Processing"
        case .speaking: return "One moment"
        }
    }

    private func wireObservers() {
        session.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)

        session.isUserSpeakingPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self else { return }
                self.updateAssistantState(
                    userSpeaking: speaking,
                    assistantSpeaking: self.session.isAssistantSpeaking
                )
            }
            .store(in: &cancellables)

        session.isAssistantSpeakingPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self else { return }
                self.updateAssistantState(
                    userSpeaking: self.session.isUserSpeaking,
                    assistantSpeaking: speaking
                )
            }
            .store(in: &cancellables)

        session.latestTranscriptPublisher
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                self?.currentTranscription = transcript
            }
            .store(in: &cancellables)

        session.finalizedTranscriptPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.conversationHistory.append(
                        ChatMessage(content: transcript, isUser: false, timestamp: Date())
                    )
                    self?.currentTranscription = ""
                }
            }
            .store(in: &cancellables)

        session.lastToolCallPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] toolCall in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.conversationHistory.append(
                        ChatMessage(content: "💡 \(toolCall.displayText)", isUser: false, timestamp: Date())
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func handleConnectionStateChange(_ newState: VoiceConnectionState) {
        switch newState {
        case .connected:
            assistantState = .listening
        case .error:
            assistantState = .idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self else { return }
                let state = self.session.connectionState
                if state == .error || state == .disconnected {
                    self.session.start()
                }
            }
        case .disconnected:
            assistantState = .idle
        case .connecting:
            assistantState = .thinking
        }
    }

    private func updateAssistantState(userSpeaking: Bool, assistantSpeaking: Bool) {
        withAnimation(.easeInOut(duration: 0.4)) {
            if userSpeaking {
                assistantState = .listening
            } else if assistantSpeaking {
                assistantState = .speaking
            } else if session.connectionState == .connected || session.connectionState == .connecting {
                assistantState = .thinking
            } else {
                assistantState = .idle
            }
        }
    }
}
