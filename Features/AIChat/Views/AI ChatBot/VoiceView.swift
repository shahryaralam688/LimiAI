import SwiftUI
import Network

// MARK: - Voice View (Living AI Presence)

struct VoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.limiBackendBaseURL) private var backendBaseURL

    var body: some View {
        VoiceViewContent(backendBaseURL: backendBaseURL, onDismiss: { dismiss() })
    }
}

private struct VoiceViewContent: View {
    @StateObject private var viewModel: VoiceViewModel
    @StateObject private var networkMonitor = NetworkMonitor()

    @State private var appeared = false
    @State private var ambientPhase: CGFloat = 0
    @State private var statusOpacity: Double = 1

    private let onDismiss: () -> Void

    init(backendBaseURL: URL, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: VoiceViewModel(backendBaseURL: backendBaseURL))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack {
                    if networkMonitor.isConnected {
                        ambientBackground

                        if viewModel.isChatMode {
                            VoiceChatModeLayout(viewModel: viewModel)
                        } else {
                            VoicePresenceLayout(
                                viewModel: viewModel,
                                appeared: appeared,
                                ambientPhase: ambientPhase,
                                statusOpacity: statusOpacity,
                                onShowAIConnection: { viewModel.showAIConnection = true }
                            )
                        }
                    } else {
                        VoiceOfflineView()
                    }
                }
            }
            .limiModalNavigationBar(
                title: viewModel.isChatMode ? "Limi" : "",
                showsCloseButton: !viewModel.isChatMode,
                onClose: onDismiss
            )
        }
        .ignoresSafeArea(.all)
        .trackScreen("VoiceView")
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appeared = true }
            startAmbientLoop()
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.showAIConnection) { AIAppStoreView() }
        .alert("Limi", isPresented: Binding(
            get: { viewModel.lastUserVisibleError != nil },
            set: { if !$0 { viewModel.clearUserVisibleError() } }
        )) {
            Button("OK", role: .cancel) { viewModel.clearUserVisibleError() }
        } message: {
            Text(viewModel.lastUserVisibleError ?? "")
        }
    }

    private var ambientBackground: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()

            RadialGradient(
                colors: [
                    viewModel.orbGlowColor(for: viewModel.assistantState).opacity(0.12 + ambientPhase * 0.06),
                    viewModel.orbGlowColor(for: viewModel.assistantState).opacity(0.04),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.38),
                startRadius: 40,
                endRadius: 300
            )
            .ignoresSafeArea()
            .blur(radius: 40)

            AmbientParticlesView(count: 15)
                .ignoresSafeArea()
                .opacity(0.6)
        }
    }

    private func startAmbientLoop() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            ambientPhase = 1.0
        }
    }
}

#Preview {
    VoiceView()
        .preferredColorScheme(.dark)
}
