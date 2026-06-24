import SwiftUI

struct VoiceChatModeLayout: View {
    @ObservedObject var viewModel: VoiceViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                chatModeHeader
                liveTranscriptionView
                    .frame(maxHeight: .infinity)
                chatModeBottomView(geometry: geometry)
            }
        }
    }

    private var chatModeHeader: some View {
        HStack {
            LimiBackButton {
                viewModel.exitChatMode()
            }
            Spacer()
            Text("Limi")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Spacer()
            Circle()
                .fill(viewModel.connectionColor(for: viewModel.connectionState))
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
                    ForEach(viewModel.conversationHistory) { msg in
                        ConversationBubbleView(message: msg.content, isUser: msg.isUser)
                            .id(msg.id)
                            .transition(.fadeSlideUp)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.conversationHistory.count) { _, _ in
                withAnimation(.easeOut(duration: 0.4)) {
                    if let lastId = viewModel.conversationHistory.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatModeBottomView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if viewModel.isRecordingFromChat {
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
                    TextField(
                        "",
                        text: $viewModel.textInput,
                        prompt: Text("Message Limi...").foregroundColor(.appTextPlaceholder)
                    )
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundColor(.appTextPrimary)
                    .font(.system(size: 16))
                    .glassCard(cornerRadius: 24, fillOpacity: 0.06)
                }

                Button(action: { viewModel.handleChatSendAction() }) {
                    let showMic = viewModel.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Image(systemName: showMic ? (viewModel.isRecordingFromChat ? "stop.fill" : "mic.fill") : "arrow.up")
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
}
