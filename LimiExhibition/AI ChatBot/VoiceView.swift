import SwiftUI
import Combine
import Network

enum AssistantVisualState {
    case idle
    case listening
    case thinking
    case speaking
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isTyping: Bool = false
}

// MARK: - Voice View (Living AI Presence)

struct VoiceView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var client = WebRTCVoiceClient(backendBaseURL: URL(string: "https://dev.api.limitless-lighting.co.uk/")!)
    @StateObject private var networkMonitor = NetworkMonitor()

    @State private var conversationHistory: [ChatMessage] = []
    @State private var textInput = ""
    @State private var currentTranscription = ""
    @State private var assistantState: AssistantVisualState = .idle
    @State private var isChatMode = false
    @State private var isRecordingFromChat = false
    @State private var showAIConnection = false
    @State private var appeared = false

    // Ambient glow animation
    @State private var ambientPhase: CGFloat = 0
    @State private var statusOpacity: Double = 1

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if networkMonitor.isConnected {
                    // Ambient deep space with living glow
                    ambientBackground

                    if isChatMode {
                        chatModeLayout(geometry: geometry)
                    } else {
                        presenceLayout
                    }
                } else {
                    offlineView
                }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appeared = true }
            startAmbientLoop()
            // Auto-connect: Limi is always listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if client.state == .disconnected {
                    client.start()
                    assistantState = .listening
                }
            }
        }
        .onDisappear {
            if client.state == .connected || client.state == .connecting {
                client.stop()
            }
        }
        .onChange(of: client.state) { _, newState in
            handleStateChange(newState)
        }
        .onReceive(client.$isUserSpeaking.removeDuplicates()) { speaking in
            updateAssistantState(userSpeaking: speaking, assistantSpeaking: client.isAssistantSpeaking)
        }
        .onReceive(client.$isAssistantSpeaking.removeDuplicates()) { speaking in
            updateAssistantState(userSpeaking: client.isUserSpeaking, assistantSpeaking: speaking)
        }
        .sheet(isPresented: $showAIConnection) { AIAppStoreView() }
        .alert("Limi", isPresented: Binding(
            get: { client.lastUserVisibleError != nil },
            set: { if !$0 { client.lastUserVisibleError = nil } }
        )) {
            Button("OK", role: .cancel) { client.lastUserVisibleError = nil }
        } message: {
            Text(client.lastUserVisibleError ?? "")
        }
        .onReceive(client.$latestTranscript.compactMap { $0 }.removeDuplicates()) { transcript in
            currentTranscription = transcript
        }
        .onReceive(client.$finalizedTranscript.compactMap { $0 }) { transcript in
            withAnimation(.easeOut(duration: 0.3)) {
                conversationHistory.append(ChatMessage(content: transcript, isUser: false, timestamp: Date()))
                currentTranscription = ""
            }
        }
        .onReceive(client.$lastToolCall.compactMap { $0 }) { toolCall in
            withAnimation(.easeOut(duration: 0.3)) {
                conversationHistory.append(ChatMessage(content: "💡 \(toolCall.displayText)", isUser: false, timestamp: Date()))
            }
        }
    }

    // MARK: - Ambient Background (living, breathing glow)

    private var ambientBackground: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()

            // Breathing radial glow behind orb
            RadialGradient(
                colors: [
                    orbGlowColor.opacity(0.12 + ambientPhase * 0.06),
                    orbGlowColor.opacity(0.04),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.38),
                startRadius: 40,
                endRadius: 300
            )
            .ignoresSafeArea()
            .blur(radius: 40)

            // Subtle particles
            AmbientParticlesView(count: 15)
                .ignoresSafeArea()
                .opacity(0.6)
        }
    }

    // MARK: - Presence Layout (the "Her" experience)

    private var presenceLayout: some View {
        VStack(spacing: 0) {
            // Minimal header — almost invisible
            presenceHeader
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: appeared)

            Spacer()

            // The living orb — center of everything
            FirstOrbView(
                hue: orbHue,
                hoverIntensity: orbHoverIntensity,
                rotateOnHover: orbRotateOnHover,
                forceHoverState: orbForceHover
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.spring(response: 1.2, dampingFraction: 0.7), value: appeared)

            // Living status — changes with state
            presenceStatus
                .padding(.top, 12)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

            // Live transcription bubble (appears when speaking)
            if !currentTranscription.isEmpty {
                liveTranscriptionBubble
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.top, 16)
            }

            Spacer()

            // Bottom — keyboard toggle only (no mic button — Limi is already listening)
            presenceBottom
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)
        }
    }

    // MARK: - Presence Header (minimal, calm)

    private var presenceHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextMuted)
                    .frame(width: 36, height: 36)
                    .glassCard(cornerRadius: 18, fillOpacity: 0.06)
            }
            .buttonStyle(.plain)

            Spacer()

            // Connection indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 6, height: 6)
                Text(connectionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appTextMuted)
            }
            .opacity(0.7)

            Spacer()

            Button(action: { showAIConnection = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextMuted)
                    .frame(width: 36, height: 36)
                    .glassCard(cornerRadius: 18, fillOpacity: 0.06)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 58)
        .padding(.horizontal, 20)
    }

    // MARK: - Presence Status (living text)

    private var presenceStatus: some View {
        VStack(spacing: 6) {
            Text(statusTitle)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .opacity(statusOpacity)
                .animation(.easeInOut(duration: 0.6), value: assistantState)

            Text(statusSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.appTextSecondary)
                .opacity(statusOpacity * 0.8)
                .animation(.easeInOut(duration: 0.6).delay(0.1), value: assistantState)
        }
    }

    private var statusTitle: String {
        switch assistantState {
        case .idle: return "I'm here"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking"
        }
    }

    private var statusSubtitle: String {
        switch assistantState {
        case .idle: return "Say anything"
        case .listening: return "I can hear you"
        case .thinking: return "Processing"
        case .speaking: return "One moment"
        }
    }

    // MARK: - Live Transcription Bubble

    private var liveTranscriptionBubble: some View {
        Text(currentTranscription)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.appTextPrimary.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 20, strokeOpacity: 0.06, fillOpacity: 0.06)
            .padding(.horizontal, 40)
            .lineLimit(3)
            .multilineTextAlignment(.center)
    }

    // MARK: - Presence Bottom (minimal — no mic button)

    private var presenceBottom: some View {
        HStack {
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isChatMode = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 14, weight: .medium))
                    Text("Type instead")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.appTextMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 24, fillOpacity: 0.04)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, 50)
    }

    // MARK: - Chat Mode

    private func chatModeLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            chatModeHeader
            liveTranscriptionView
                .frame(maxHeight: .infinity)
            chatModeBottomView(geometry: geometry)
        }
    }

    private var chatModeHeader: some View {
        HStack {
            LimiBackButton {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isChatMode = false
                }
            }
            Spacer()
            Text("Limi")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Spacer()
            // Connection dot
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .padding(.trailing, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 10)
    }

    private var liveTranscriptionView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(conversationHistory) { msg in
                        ConversationBubbleView(message: msg.content, isUser: msg.isUser)
                            .id(msg.id)
                            .transition(.fadeSlideUp)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onChange(of: conversationHistory.count) { _, _ in
                withAnimation(.easeOut(duration: 0.4)) {
                    if let lastId = conversationHistory.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatModeBottomView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isRecordingFromChat {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.orbGlow4)
                        Text("Recording...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 24, fillOpacity: 0.06)
                } else {
                    TextField("", text: $textInput, prompt: Text("Message Limi...").foregroundColor(.appTextPlaceholder))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .foregroundColor(.appTextPrimary)
                        .font(.system(size: 16))
                        .glassCard(cornerRadius: 24, fillOpacity: 0.06)
                }

                Button(action: {
                    let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        isRecordingFromChat.toggle()
                        toggleVoice()
                    } else {
                        sendTextMessage()
                    }
                }) {
                    let showMic = textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orbGlow4, .orbGlow1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: showMic ? (isRecordingFromChat ? "stop.fill" : "mic.fill") : "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Offline

    private var offlineView: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(.appTextMuted)
                Text("Waiting for connection")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Text("Limi will reconnect automatically.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Orb State Mapping

    private var orbHue: Float {
        switch assistantState {
        case .idle: return 0.72
        case .listening: return 0.58
        case .thinking: return 0.50
        case .speaking: return 0.30
        }
    }

    private var orbHoverIntensity: Float {
        switch assistantState {
        case .idle: return 0.15
        case .listening: return 0.45
        case .thinking: return 0.30
        case .speaking: return 0.65
        }
    }

    private var orbRotateOnHover: Bool {
        assistantState == .thinking || assistantState == .speaking
    }

    private var orbForceHover: Bool {
        assistantState != .idle
    }

    private var orbGlowColor: Color {
        switch assistantState {
        case .idle: return .orbGlow2
        case .listening: return .orbGlow4
        case .thinking: return .orbGlow3
        case .speaking: return .orbGlow1
        }
    }

    private var connectionColor: Color {
        switch client.state {
        case .connected: return .appSuccess
        case .connecting: return .appWarning
        case .error: return .appDanger
        case .disconnected: return .appTextMuted
        }
    }

    private var connectionLabel: String {
        switch client.state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .error: return "Error"
        case .disconnected: return "Offline"
        }
    }

    // MARK: - Ambient Loop

    private func startAmbientLoop() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            ambientPhase = 1.0
        }
    }

    // MARK: - Actions

    private func toggleVoice() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if client.state == .connected || client.state == .connecting {
                client.stop()
                assistantState = .idle
            } else {
                client.start()
                assistantState = .listening
            }
        }
    }

    private func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            conversationHistory.append(ChatMessage(content: text, isUser: true, timestamp: Date()))
            textInput = ""
        }
        if !isChatMode {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isChatMode = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                conversationHistory.append(ChatMessage(content: "I received your message. Voice responses come through the live connection.", isUser: false, timestamp: Date()))
            }
        }
    }

    private func handleStateChange(_ newState: VoiceConnectionState) {
        switch newState {
        case .connected:
            assistantState = .listening
        case .error:
            assistantState = .idle
            // Auto-retry after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if client.state == .error || client.state == .disconnected {
                    client.start()
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
            } else if client.state == .connected || client.state == .connecting {
                assistantState = .thinking
            } else {
                assistantState = .idle
            }
        }
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text("Message Limi...").foregroundColor(.appTextPlaceholder))
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(.appTextPrimary)
                .padding(.leading, 14)
                .padding(.vertical, 12)

            Button(action: handleSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .frame(height: 50)
        .padding(6)
        .glassCard(cornerRadius: 28, fillOpacity: 0.06)
        .shadow(color: Color.orbGlow1.opacity(0.06), radius: 16, y: 4)
        .submitLabel(.send)
        .onSubmit(handleSend)
    }

    private func handleSend() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
    }
}

// MARK: - Conversation Bubble

struct ConversationBubbleView: View {
    let message: String
    let isUser: Bool
    let isLive: Bool

    @State private var showMessage = false

    init(message: String, isUser: Bool, isLive: Bool = false) {
        self.message = message
        self.isUser = isUser
        self.isLive = isLive
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 50) }

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isUser ? .white : .appTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            isUser
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.orbGlow4, .orbGlow1],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isUser ? 0.08 : 0.04), lineWidth: 0.5)
                )

            if !isUser { Spacer(minLength: 50) }
        }
        .opacity(showMessage ? 1 : 0)
        .offset(y: showMessage ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                showMessage = true
            }
        }
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var showMessage = false
    @State private var typingDots = ""

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.isTyping ? "Thinking\(typingDots)" : message.content)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                message.isUser
                                ? AnyShapeStyle(LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.white.opacity(0.06))
                            )
                    )

                Text(formatTime(message.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appTextMuted)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
        .opacity(showMessage ? 1 : 0)
        .offset(y: showMessage ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                showMessage = true
            }
            if message.isTyping { startTypingAnimation() }
        }
    }

    private func startTypingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                typingDots = typingDots.count >= 3 ? "" : typingDots + "."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { timer.invalidate() }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    VoiceView()
        .preferredColorScheme(.dark)
}
