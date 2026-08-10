import SwiftUI

struct AIMainView: View {
    @State private var selectedScreen: AIScreen = .appStore
    @State private var showVoiceAssistant = false

    enum AIScreen: CaseIterable {
        case appStore
        case connections
        case integrate

        var title: String {
            switch self {
            case .appStore: return "Intelligence"
            case .connections: return "Connections"
            case .integrate: return "Assistant"
            }
        }

        var icon: String {
            switch self {
            case .appStore: return "cpu"
            case .connections: return "link"
            case .integrate: return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DeepSpaceBackground(showParticles: false)

                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Text("Limi AI")
                            .font(LimiTypography.largeTitle)
                            .foregroundColor(.appTextPrimary)
                            .padding(.top, 20)

                        HStack(spacing: 8) {
                            ForEach(AIScreen.allCases, id: \.self) { screen in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedScreen = screen
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: screen.icon)
                                            .font(LimiTypography.caption)
                                        Text(screen.title)
                                            .font(LimiTypography.footnote)
                                    }
                                    .foregroundColor(selectedScreen == screen ? .appCanvasPrimary : .appTextSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedScreen == screen
                                                ? AnyShapeStyle(LimiGradients.cta)
                                                : AnyShapeStyle(Color.appGlassFill)
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.appGlassFillMedium.opacity(selectedScreen == screen ? 0 : 1), lineWidth: 0.5)
                                    )
                                }
                                .tapScale()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Group {
                        switch selectedScreen {
                        case .appStore:
                            AIAppStoreView()
                        case .connections:
                            AIConnectionsView()
                        case .integrate:
                            IntegrateNewAIView()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.easeInOut(duration: 0.3), value: selectedScreen)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: selectedScreen) { _, newValue in
            if newValue == .integrate {
                showVoiceAssistant = true
                selectedScreen = .appStore
            }
        }
        .fullScreenCover(isPresented: $showVoiceAssistant) {
            VoiceView()
        }
    }
}

#Preview {
    AIMainView()
}
