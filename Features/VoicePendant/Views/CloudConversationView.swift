//
//  CloudConversationView.swift
//  Limi
//
//  Backend-connected Cloud AI Chat thread for the Voice Pendant module.
//  Shows a chronological conversation (user right / Limi left), a typing
//  indicator while the cloud request is in flight, a text composer, and a
//  voice button that opens the existing voice-first experience.
//

import SwiftUI

struct CloudConversationView: View {
    @StateObject private var viewModel: CloudConversationViewModel
    @State private var showVoiceAI = false
    @FocusState private var inputFocused: Bool

    init(pendant: VoicePendant) {
        _viewModel = StateObject(wrappedValue: CloudConversationViewModel(pendant: pendant))
    }

    var body: some View {
        VStack(spacing: 0) {
            thread
            composer
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Chat with Limi")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showVoiceAI) { VoiceView() }
        .trackScreen("CloudConversationView")
    }

    // MARK: - Thread

    @ViewBuilder
    private var thread: some View {
        if viewModel.messages.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isAwaitingReply) { _, _ in
                    scrollToBottom(proxy)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: PendantChatMessage) -> some View {
        let isUser = message.role == .user
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.isPending {
                    TypingIndicatorView()
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.appSurfaceSecondaryAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(message.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isUser ? Color.appCanvasPrimary : .themeWhite)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(isUser ? Color.orbGlow4 : Color.appSurfaceSecondaryAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .textSelection(.enabled)

                    Text(timeString(message.createdAt))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color.appTextMuted)
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.orbGlow4)
            Text("Start a conversation")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.themeWhite)
            Text("Ask Limi anything — type below or tap the mic to talk. Your conversation continues across messages.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.appTextMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") { viewModel.retryLast() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                Button {
                    inputFocused = false
                    showVoiceAI = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                        .frame(width: 40, height: 40)
                        .background(Color.orbGlow4.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Talk to Limi")

                HStack(spacing: 8) {
                    TextField("Message Limi…", text: $viewModel.draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundColor(.themeWhite)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .onSubmit { viewModel.sendDraft() }

                    Button {
                        viewModel.sendDraft()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(viewModel.canSend ? .orbGlow4 : Color.appTextMuted)
                    }
                    .disabled(!viewModel.canSend)
                    .accessibilityLabel("Send")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.appSurfaceSecondaryAlt)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Color.appCanvasPrimary)
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.appTextMuted)
                    .frame(width: 7, height: 7)
                    .opacity(phase == index ? 1.0 : 0.35)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: false)) {
                // Driven by timer below for discrete steps.
            }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("Limi is thinking")
    }
}

#Preview {
    NavigationStack {
        CloudConversationView(
            pendant: VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                                  status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2")
        )
    }
    .preferredColorScheme(.dark)
}
