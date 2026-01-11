import SwiftUI

struct AIMainView: View {
    @State private var selectedScreen: AIScreen = .appStore
    
    enum AIScreen: CaseIterable {
        case appStore
        case connections
        case integrate
        
        var title: String {
            switch self {
            case .appStore: return "AI App Store"
            case .connections: return "AI Connections"
            case .integrate: return "Integrate New AI"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Screen Selector (for demo purposes)
                VStack(spacing: AIDesignTokens.spacingMD) {
                    Text("AI Screens Demo")
                        .font(AIDesignTokens.h1Font)
                        .foregroundColor(AIDesignTokens.textPrimary)
                        .padding(.top, 20)
                    
                    HStack(spacing: AIDesignTokens.spacingSM) {
                        ForEach(AIScreen.allCases, id: \.self) { screen in
                            Button(action: {
                                selectedScreen = screen
                            }) {
                                Text(screen.title)
                                    .font(AIDesignTokens.captionFont)
                                    .foregroundColor(selectedScreen == screen ? AIDesignTokens.textPrimary : AIDesignTokens.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: AIDesignTokens.radiusPill)
                                            .fill(selectedScreen == screen ? AIDesignTokens.brandEmerald : AIDesignTokens.bgCard)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .padding(.bottom, AIDesignTokens.spacingLG)
                .background(AIDesignTokens.bgBase)
                
                // Selected Screen
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
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: selectedScreen)
            }
        }
        .navigationBarHidden(true)
        .background(AIDesignTokens.bgBase)
    }
}

#Preview {
    AIMainView()
}
