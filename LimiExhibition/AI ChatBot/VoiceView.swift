//
//  VoiceView.swift
//  Aura
//
//  Created by Cascade on 02/09/2025.
//

import SwiftUI
import Combine
import Network

enum AssistantVisualState {
    case idle
    case listening
    case thinking
    case speaking
}

// MARK: - Message Model
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isTyping: Bool = false
}

struct VoiceView: View {
    @Environment(\.dismiss) var dismiss   // dismiss function

    @StateObject private var client = WebRTCVoiceClient(backendBaseURL: URL(string: APIConstants.baseURL)!)
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var messages: [ChatMessage] = []
    @State private var isListening = false
    @State private var pulseAnimation = false
    @State private var showTextInput = false
    @State private var textInput = ""
    @State private var glowAnimation = false
    @State private var breathingAnimation = false
    @State private var currentTranscription = ""
    @State private var waveAnimation = false
    @State private var wavePhases: [Double] = Array(repeating: 0, count: 8)
    @State private var conversationHistory: [ChatMessage] = []
    @State private var isConversationActive: Bool = false
    @State private var isConversationVisible: Bool = false
    @State private var isChatMode: Bool = false
    @State private var isRecordingFromChat: Bool = false
    @State private var assistantState: AssistantVisualState = .idle
    
    // AI
    
    @State private var showAIConnection = false

    
    // 3D animation
    @State private var intensity: CGFloat = 60
    @State private var volume: CGFloat = 0.4 // This can be bound to mic input
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if networkMonitor.isConnected {
                    // Background gradient when online
                    Color.appCanvasPrimary
                        .ignoresSafeArea()

                    if isChatMode {
                        // Chat Mode Layout
                        VStack(spacing: 0) {
                            // Header with back button
                            chatModeHeader

                            // Full screen conversation view
                            liveTranscriptionView
                                .frame(maxHeight: .infinity)

                            // Bottom chat input area (WhatsApp-style mic/send)
                            chatModeBottomView(geometry: geometry)
                        }

                    } else {
                        // Normal Mode Layout (voice-only, no live text UI)
                        VStack(spacing: 0) {
                            voiceModeHeader
                            Spacer()

                            FirstOrbView(
                                hue: orbHue,
                                hoverIntensity: orbHoverIntensity,
                                rotateOnHover: orbRotateOnHover,
                                forceHoverState: orbForceHover
                            )
                            // App Title Header
                            appTitleHeader

                            // Spacer keeps layout balanced without showing any live text
                            Spacer()

                            bottomControlsView
                        }
                    }
                } else {
                    Color.appCanvasPrimary
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        Spacer()
                        Text("Internet connection required")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.themeWhite)
                        Text("Please check your connection and try again.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.themeWhite.opacity(0.8))
                        Spacer()
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
            }
        }
        .ignoresSafeArea(.all)
    
        .onAppear {
            addWelcomeMessage()
            startBreathingAnimation()
        }
        .onChange(of: client.state) { _, newState in
            handleStateChange(newState)
        }
        .onChange(of: isListening) { _, newValue in
            glowAnimation = newValue
            waveAnimation = newValue
            if newValue {
                startWaveAnimation()
            } else {
                stopWaveAnimation()
            }
        }
        .onReceive(client.$isUserSpeaking.removeDuplicates()) { speaking in
            updateAssistantState(userSpeaking: speaking, assistantSpeaking: client.isAssistantSpeaking)
        }
        .onReceive(client.$isAssistantSpeaking.removeDuplicates()) { speaking in
            updateAssistantState(userSpeaking: client.isUserSpeaking, assistantSpeaking: speaking)
        }
        .sheet(isPresented: $showAIConnection) {
            AIAppStoreView()
        }
        // Receive live transcript updates from WebRTC client
        .onReceive(client.$latestTranscript.compactMap { $0 }.removeDuplicates()) { transcript in
            currentTranscription = transcript
        }
        // Append finalized transcripts to conversation history and clear live bubble
        .onReceive(client.$finalizedTranscript.compactMap { $0 }) { transcript in
            withAnimation(.easeOut(duration: 0.3)) {
                conversationHistory.append(ChatMessage(content: transcript, isUser: false, timestamp: Date()))
                currentTranscription = ""
            }
        }
    }

    private var orbHue: Float {
        switch assistantState {
        case .idle:
            return 0.58
        case .listening:
            return 0.33
        case .thinking:
            return 0.5
        case .speaking:
            return 0.3
        }
    }

    private var orbHoverIntensity: Float {
        switch assistantState {
        case .idle:
            return 0.1
        case .listening:
            return 0.4
        case .thinking:
            return 0.25
        case .speaking:
            return 0.6
        }
    }

    private var orbRotateOnHover: Bool {
        switch assistantState {
        case .idle:
            return false
        case .listening:
            return false
        case .thinking:
            return true
        case .speaking:
            return true
        }
    }

    private var orbForceHover: Bool {
        switch assistantState {
        case .idle:
            return false
        case .listening:
            return true
        case .thinking:
            return true
        case .speaking:
            return true
        }
    }
    // MARK: - Voice Mode Header
    private var voiceModeHeader: some View {
        // Back/Close button positioned at top left
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image("Solid arrow right sm")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(12) // space inside the circle
                        .background(
                            Rectangle()
                                .fill(Color.appSurfacePrimary) // gray background
                                .cornerRadius(16)
                        )
                }
//                        .position(x: 26 + 12, y: 54 + 12) // Adding half of width/height for center positioning
                Spacer()
                Button(action: {
                    showAIConnection = true
                }) {
                    Text("Upgrade")
                        .foregroundColor(.themeWhite)
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.appSuccess) // green background
                        )
                }
                .frame(maxWidth: 150)
//                        .position(x:  130, y: 54 + 12) // Right side positioning
            }
            .padding(.top, 55)
            .padding(.horizontal)
        }
    }
    // MARK: - Chat Mode Header
    private var chatModeHeader: some View {
        HStack {
            // Back button

            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isChatMode = false
                    showTextInput = false
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.alabaster)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .background(Color.clear)
                    )
            }
            
            Spacer()
            
            // Chat title
            Text("Chat with Limi")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.themeWhite)
            
            Spacer()
            
            Color.clear
                .frame(width: 44, height: 44)
            // Placeholder for balance
            
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 10)
    }
    
    // MARK: - App Title Header
    private var appTitleHeader: some View {
        VStack() {
            Text("Hey, Limi AI here!")
                .font(.custom("SF Pro Rounded", size: 20))   // font-family + font-size
                .fontWeight(.bold)                           // weight: 700 (Bold)
                .multilineTextAlignment(.center)             // text-align: center
                .lineSpacing((20 * 1.3) - 20)                // line-height: 130% → extra spacing
                .kerning(-0.4)                               // letter-spacing: -2% of 20px
                .foregroundColor(.themeWhite)                     // text color
                .shadow(color: Color.themeWhite.opacity(0.3),
                        radius: 10, x: 0, y: 0)              // shadow

            Text("Let me help you in seconds.")
                .font(.custom("SF Pro Rounded", size: 16)) // font-family + font-size
                .fontWeight(.regular)                      // weight: 400 (Regular)
                .multilineTextAlignment(.center)           // text-align: center
                .lineSpacing((16 * 1.4) - 16)              // line-height: 140% → extra spacing
                .kerning(-0.16)                            // letter-spacing: -1% of font size
                .foregroundColor(.themeWhite)                   // text color
                .shadow(color: Color.themeWhite.opacity(0.3),
                        radius: 10, x: 0, y: 0)            // same shadow


        }
        .padding(.top, 30)
        .padding(.bottom, 10)
    }
    
    // MARK: - Live Transcription View
    private var liveTranscriptionView: some View {
        VStack(spacing: 0) {
            // Conversation history in ChatGPT/Siri style
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Show conversation history (user + AI)
                        ForEach(conversationHistory) { msg in
                            ConversationBubbleView(
                                message: msg.content,
                                isUser: msg.isUser
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .onChange(of: conversationHistory.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        if let lastId = conversationHistory.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Central Voice Button
    private var centralVoiceButton: some View {
        VStack(spacing: 30) {
            ZStack {
                // Premium wave animation rings (Siri/ChatGPT style)
                if isListening {
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        emerald.opacity(0.8),
                                        charlesGreen.opacity(0.6),
                                        eton.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: (isListening ? 60 : 180) + CGFloat(index * (isListening ? 8 : 25)), height: (isListening ? 60 : 180) + CGFloat(index * (isListening ? 8 : 25)))
                            .scaleEffect(1.0 + sin(wavePhases[index]) * 0.15)
                            .opacity(0.9 - (Double(index) * 0.1) + sin(wavePhases[index]) * 0.3)
                            .animation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true),
                                value: wavePhases[index]
                            )
                    }
                }
                
                // Subtle breathing ring for idle state
                if !isListening {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [eton.opacity(0.4), charlesGreen.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(breathingAnimation ? 1.02 : 0.98)
                        .opacity(breathingAnimation ? 0.6 : 0.3)
                        .animation(
                            .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                            value: breathingAnimation
                        )
                }
                
                // Main voice button
                Button(action: toggle) {
                    ZStack {
                        // Button background with premium gradient
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.appAIGradientStart,
                                        Color.appAIGradientEnd
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 90
                                )
                            )
                            .frame(width: isListening ? 60 : 180, height: isListening ? 60 : 180)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isListening)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [alabaster.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(
                                color: isListening ? emerald.opacity(0.8) : alabaster.opacity(0.2),
                                radius: isListening ? 40 : 20,
                                x: 0,
                                y: 0
                            )
                        
                        // Microphone icon with premium styling
                        Image(systemName: microphoneIcon)
                            .font(.system(size: isListening ? 20 : 52, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isListening ? [emerald, charlesGreen] : [eton, charlesGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(isListening ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isListening)
                    }
                }
                .scaleEffect(isListening ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isListening)
            }
            
        }
    }
    
    // MARK: - Bottom Controls View
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Text input (optional)
            if showTextInput {
            
                ChatInputBar(text: $textInput, onSend: sendTextMessage)
                    .padding(.horizontal, 12)
            }
            
//            // Bottom control buttons
            ZStack {
                // Centered compact voice button
                if !isChatMode {
                    HStack {
                        Spacer()
                        Button(action: toggle) {
                            ZStack {
                                Circle()
                                    .fill(
                                        Color.themeWhite

                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                Color.themeWhite

                                            )
                                    )

                                
                                Image(systemName: microphoneIcon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(
                                        Color.charlestonGreen
                                    )
                            }
                        }
                        Spacer()
                    }
                    .background(
                        Rectangle()
                            .stroke(Color.appCanvasPrimary)
                            .frame(height: 132)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(40)
                    )
                }

                // Trailing keyboard toggle

                if !isChatMode {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showTextInput.toggle()
                                if showTextInput {
                                    isChatMode = true
                                }
                            }
                        }) {
                            Image(systemName: showTextInput ? "keyboard.chevron.compact.down" : "keyboard")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)     // icon size
                                .foregroundColor(.themeWhite)          // icon color
                                .padding()                        // padding to center inside circle
                        }
                        .frame(width: 50, height: 50)             // circle size
                        .background(Color.gray)                   // circle color
                        .clipShape(Circle())                      // make it circular
                        .shadow(radius: 4)                        // optional soft shadow

                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Chat Mode Bottom View
    private func chatModeBottomView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.themeWhite.opacity(0.1))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Left side: either recording UI or text input field
                if isRecordingFromChat {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(emerald)

                        Text("Recording... Release to stop")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.themeWhite)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.themeWhite.opacity(0.08))
                    )
                } else {
                    // Text input field
                    TextField("Type a message...", text: $textInput)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(.ultraThinMaterial)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.themeWhite.opacity(0.05))
                                )
                        )
                        .foregroundColor(.themeWhite)
                }
                
                // Send / Mic button (WhatsApp-style behavior + recording UI)
                Button(action: {
                    let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        // Toggle chat recording state and use existing voice toggle()
                        isRecordingFromChat.toggle()
                        toggle()
                    } else {
                        // Has text: send text message
                        sendTextMessage()
                    }
                }) {
                    let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    let showMic = trimmed.isEmpty
                    Image(systemName: showMic ? (isRecordingFromChat ? "stop.circle.fill" : "mic.fill") : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.darkGray.opacity(0.8), .themeWhite],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
//            .background(
//                Rectangle()
//                    .fill(.ultraThinMaterial)
//                    .background(Color.themeBlack.opacity(0.2))
//            )
        }
    }
    
    // MARK: - Animation Functions
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            breathingAnimation = true
        }
    }
    
    private func startWaveAnimation() {
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    wavePhases[i] = .pi * 2
                }
            }
        }
    }
    
    private func stopWaveAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            for i in 0..<8 {
                wavePhases[i] = 0
            }
        }
    }
    
    // MARK: - Color Definitions
    private var charlesGreen: Color {
        Color.darkGreen // #008000
    }
    
    private var eton: Color {
        Color.appChatUserBubbleAlt // #96C07B
    }
    
    private var emerald: Color {
        Color.appChatUserBubble // #50C878
    }
    
    private var alabaster: Color {
        Color.appNeutralLight // #F5F5F5
    }
    
    // MARK: - Computed Properties
    private var gradientColors: [Color] {
        switch client.state {
        case .connected:
            return [emerald, charlesGreen]
        case .connecting:
            return [eton, charlesGreen]
        case .error:
            return [Color.red, Color.pink]
        case .disconnected:
            return [eton, alabaster.opacity(0.7)]
        }
    }
    
    private var microphoneIcon: String {
        switch client.state {
        case .connected:
            return "Mic"
        case .connecting:
            return "Listening mic"
        case .error:
            return "mic.slash.fill"
        case .disconnected:
            return "mic"
        }
    }
    
    private var statusText: String {
        switch client.state {
        case .connected:
            return "Listening..."
        case .connecting:
            return "Connecting..."
        case .error:
            return "Connection Error"
        case .disconnected:
            return "Ready to chat"
        }
    }
    
    private var statusColor: Color {
        switch client.state {
        case .connected:
            return emerald
        case .connecting:
            return eton
        case .error:
            return .red
        case .disconnected:
            return alabaster.opacity(0.7)
        }
    }
    
    // MARK: - Actions
    private func toggle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if client.state == .connected || client.state == .connecting {
                client.stop()
                isListening = false
                assistantState = .idle
            } else {
                client.start()
                isListening = true
                assistantState = .listening
            }
        }
        // Activate conversation UI on user interaction
        if !isConversationActive {
            isConversationActive = true
        }
        if isListening {
            withAnimation(.spring()) { isConversationVisible = true }
        }
    }
    
    private func sendTextMessage() {
        let messageText = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // Add to conversation history
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            conversationHistory.append(ChatMessage(content: messageText, isUser: true, timestamp: Date()))
            textInput = ""
        }
        if !isConversationActive { isConversationActive = true }
        if !isConversationVisible {
            withAnimation(.spring()) { isConversationVisible = true }
        }
        
        // Ensure we're in chat mode when sending messages
        if !isChatMode {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isChatMode = true
                showTextInput = true
            }
        }
        
        // Simulate AI response (in real implementation, this would come from WebRTC data channel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                conversationHistory.append(ChatMessage(content: "I received your message. Voice responses will come through the WebRTC connection.", isUser: false, timestamp: Date()))
            }
        }
    }
    
    private func addWelcomeMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                conversationHistory.append(ChatMessage(content: "Hello! I'm Limi, your AI voice assistant. Tap the microphone to start our conversation.", isUser: false, timestamp: Date()))
            }
        }
    }
    
    private func handleStateChange(_ newState: VoiceConnectionState) {
        switch newState {
        case .connected:
            withAnimation(.spring()) {
                conversationHistory.append(ChatMessage(content: "🎤 Voice connection established. I'm listening!", isUser: false, timestamp: Date()))
            }
            if !isConversationActive { isConversationActive = true }
            withAnimation(.spring()) { isConversationVisible = true }
            if !client.isUserSpeaking && !client.isAssistantSpeaking {
                assistantState = .thinking
            }
        case .error:
            withAnimation(.spring()) {
                conversationHistory.append(ChatMessage(content: "❌ Connection error. Please try again.", isUser: false, timestamp: Date()))
            }
            isListening = false
            assistantState = .idle
        case .disconnected:
            isListening = false
            assistantState = .idle
            if !conversationHistory.isEmpty {
                withAnimation(.spring()) {
                    conversationHistory.append(ChatMessage(content: "Connection ended. Tap to reconnect.", isUser: false, timestamp: Date()))
                }
            }
        case .connecting:
            currentTranscription = "Connecting to voice service..."
            assistantState = .thinking
        }
    }

    private func updateAssistantState(userSpeaking: Bool, assistantSpeaking: Bool) {
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

// MARK: - Network Monitor


// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    var onSend: () -> Void

    private let barBackground = Color.appChatBar // #2C2C2C
    private let sendGreen = Color.appChatSend     // #4CAF50
    private let placeholderColor = Color.appPlaceholderGray // #B0B0B0

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text("Type a message...").foregroundColor(placeholderColor))
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.themeWhite)
                .padding(.leading, 12)
                .padding(.vertical, 12)

            Button(action: handleSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.alabaster)
                    .frame(width: 40, height: 40)
                    .background(Color.emerald)
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            .accessibilityLabel("Send")
        }
        .frame(height: 50)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(barBackground)
        )
        .shadow(color: Color.themeBlack.opacity(0.35), radius: 8, x: 0, y: 2)
        .submitLabel(.send)
        .onSubmit(handleSend)
    }

    private func handleSend() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
    }
}

// MARK: - Conversation Bubble View
struct ConversationBubbleView: View {
    let message: String
    let isUser: Bool
    let isLive: Bool
    
    init(message: String, isUser: Bool, isLive: Bool = false) {
        self.message = message
        self.isUser = isUser
        self.isLive = isLive
    }
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                isUser ?
                                LinearGradient(
                                    colors: [Color.appChatUserBubble, Color.darkGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.themeWhite.opacity(0.08), Color.themeWhite.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.themeWhite.opacity(0.15), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .shadow(
                        color: isUser ? Color.appChatUserBubble.opacity(0.3) : Color.themeBlack.opacity(0.2),
                        radius: 6,
                        x: 0,
                        y: 2
                    )
                
                if isLive {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.appChatUserBubble)
                                .frame(width: 4, height: 4)
                                .scaleEffect(isLive ? 1.2 : 0.8)
                                .opacity(isLive ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isLive
                                )
                        }
                        
                        Text("Live")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.appChatUserBubble)
                    }
                    .padding(.trailing, isUser ? 0 : 16)
                    .padding(.leading, isUser ? 16 : 0)
                }
            }
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var showMessage = false
    @State private var typingDots = ""
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.isTyping ? "Thinking\(typingDots)" : message.content)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.alabaster)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                message.isUser ?
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.themeWhite.opacity(0.1), Color.themeWhite.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.themeWhite.opacity(0.2), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(
                        color: message.isUser ? Color.purple.opacity(0.3) : Color.themeBlack.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.themeWhite.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
        .opacity(showMessage ? 1 : 0)
        .offset(y: showMessage ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showMessage = true
            }
            
            if message.isTyping {
                startTypingAnimation()
            }
        }
    }
    
    private func startTypingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                if typingDots.count >= 3 {
                    typingDots = ""
                } else {
                    typingDots += "."
                }
            }
            
            // Stop after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                timer.invalidate()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VoiceView()
        .preferredColorScheme(.dark)
}
