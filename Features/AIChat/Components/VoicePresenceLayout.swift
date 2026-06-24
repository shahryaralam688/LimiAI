import SwiftUI

struct VoicePresenceLayout: View {
    @ObservedObject var viewModel: VoiceViewModel
    var appeared: Bool
    var ambientPhase: CGFloat
    var statusOpacity: Double
    var onShowAIConnection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            presenceHeader
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: appeared)

            Spacer()

            FirstOrbView(
                hue: viewModel.orbHue(for: viewModel.assistantState),
                hoverIntensity: viewModel.orbHoverIntensity(for: viewModel.assistantState),
                rotateOnHover: viewModel.orbRotateOnHover(for: viewModel.assistantState),
                forceHoverState: viewModel.orbForceHover(for: viewModel.assistantState)
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.spring(response: 1.2, dampingFraction: 0.7), value: appeared)

            presenceStatus
                .padding(.top, 12)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

            if !viewModel.currentTranscription.isEmpty {
                liveTranscriptionBubble
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.top, 16)
            }

            Spacer()

            presenceBottom
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)
        }
    }

    private var presenceHeader: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.connectionColor(for: viewModel.connectionState))
                    .frame(width: 6, height: 6)
                Text(viewModel.connectionLabel(for: viewModel.connectionState))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appTextMuted)
            }
            .opacity(0.7)

            Spacer()

            Button(action: onShowAIConnection) {
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

    private var presenceStatus: some View {
        VStack(spacing: 6) {
            Text(viewModel.statusTitle(for: viewModel.assistantState))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .opacity(statusOpacity)
                .animation(.easeInOut(duration: 0.6), value: viewModel.assistantState)

            Text(viewModel.statusSubtitle(for: viewModel.assistantState))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.appTextSecondary)
                .opacity(statusOpacity * 0.8)
                .animation(.easeInOut(duration: 0.6).delay(0.1), value: viewModel.assistantState)
        }
    }

    private var liveTranscriptionBubble: some View {
        Text(viewModel.currentTranscription)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.appTextPrimary.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 20, strokeOpacity: 0.06, fillOpacity: 0.06)
            .padding(.horizontal, 40)
            .lineLimit(3)
            .multilineTextAlignment(.center)
    }

    private var presenceBottom: some View {
        HStack {
            Spacer()
            Button(action: { viewModel.enterChatMode() }) {
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
}

struct VoiceOfflineView: View {
    var body: some View {
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
}
