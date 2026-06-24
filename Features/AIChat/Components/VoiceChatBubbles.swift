import SwiftUI

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
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
