import SwiftUI

struct AIAppStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var perplexityConnected = true
    @State private var claudeConnected = true
    @State private var geminiConnected = false
    
    var body: some View {
        VStack(spacing: 0) {
            // App Bar
            AIAppBar(title: "AI App Store") {
                dismiss()
            }
            .padding(.top, 24)
                .padding(.bottom, 38)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.appSurfaceTertiary)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 40,
                                bottomTrailingRadius: 40,
                                topTrailingRadius: 0
                            )
                        )
                )
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: AIDesignTokens.spacingLG) {
                    // Featured Models Header
                    HStack {
                        Text("Featured Models")
                            .font(AIDesignTokens.h2Font)
                            .foregroundColor(AIDesignTokens.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, AIDesignTokens.spacingLG)
                    
                    // Model Cards
                    VStack(spacing: AIDesignTokens.spacingLG) {
                        // Perplexity Card
                        ModelCard(
                            iconName: "VoiceAi",
                            title: "Perplexity",
                            tags: ["Voice AI"],
                            connectionStatus: "Connected",
                            tokenCount: "1k Tokens left",
                            isConnected: perplexityConnected
                        ) {
                            perplexityConnected.toggle()
                        }
                        
                        // Claude Card
                        ModelCard(
                            iconName: "Claude",
                            title: "Claude",
                            tags: ["Control AI"],
                            connectionStatus: "Connected",
                            tokenCount: "1k Tokens left",
                            isConnected: claudeConnected
                        ) {
                            claudeConnected.toggle()
                        }
                        
                        // Gemini Card
                        ModelCard(
                            iconName: "Gemini",
                            title: "Gemini",
                            tags: ["Search AI"],
                            connectionStatus: "Available",
                            tokenCount: "1k Tokens left",
                            isConnected: geminiConnected
                        ) {
                            geminiConnected.toggle()
                        }
                    }
                    .padding(.horizontal, AIDesignTokens.spacingLG)
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
                .padding(.top, AIDesignTokens.spacingLG)
            }
        }
        .background(AIDesignTokens.bgBase)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview {
    AIAppStoreView()
}
