import SwiftUI

struct IntegrateNewAIView: View {
    
    
    @Environment(\.dismiss) private var dismiss
    @State private var voiceIntegrationEnabled = true
    @State private var knowledgeAccessEnabled = true
    
    var body: some View {
        VStack(spacing: 0) {
            // App Bar
            AIAppBar(title: "Integrate New AI") {
                dismiss()
            }
            .padding(.top, 24)
                .padding(.bottom, 38)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(hex: "#393C43"))
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
                VStack(spacing: AIDesignTokens.spacingXXL) {
                    // AI Service Header
                    HStack(spacing: AIDesignTokens.spacingMD) {
                        // Gemini Icon
                        Image("Gemini")
                            .font(.system(size: 36))
                            .foregroundColor(AIDesignTokens.textPrimary)
                            .frame(width: 72, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: AIDesignTokens.radiusLG)
                                    .fill(Color.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gemini")
                                .font(AIDesignTokens.h2Font)
                                .foregroundColor(AIDesignTokens.textPrimary)
                            
                            Text("By Google")
                                .font(AIDesignTokens.bodyFont)
                                .foregroundColor(AIDesignTokens.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: AIDesignTokens.spacingSM) {
                        HStack {
                            Text("About")
                                .font(AIDesignTokens.h2Font)
                                .foregroundColor(AIDesignTokens.textPrimary)
                            Spacer()
                        }
                        
                        Text("Gemini enables natural conversation with your devices — ask for room adjustments, personalized recommendations, or daily briefings with ease.")
                            .font(AIDesignTokens.bodyFont)
                            .foregroundColor(Color(hex: "#D1D5DB"))
                            .lineSpacing(4)
                    }
                    
                    // Integration Options Section
                    VStack(alignment: .leading, spacing: AIDesignTokens.spacingMD) {
                        HStack {
                            Text("Integration Options")
                                .font(AIDesignTokens.h2Font)
                                .foregroundColor(AIDesignTokens.textPrimary)
                            Spacer()
                        }
                        
                        VStack(spacing: AIDesignTokens.spacingMD) {
                            IntegrationOption(
                                title: "Voice Integration",
                                subtitle: "Talk to your room assistant naturally.",
                                isEnabled: $voiceIntegrationEnabled
                            )
                            
                            IntegrationOption(
                                title: "Knowledge Access",
                                subtitle: "Summarize your itinerary or travel plans.",
                                isEnabled: $knowledgeAccessEnabled
                            )
                        }
                    }
                    
                    // Confirm Button
                    AIButton(
                        title: "Confirm",
                        style: .primary
                    ) {
                        // Handle confirmation
                        print("Integration confirmed")
                        dismiss()
                    }
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .padding(.top, AIDesignTokens.spacingLG)
            }
        }
        .background(AIDesignTokens.bgBase)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview {
    IntegrateNewAIView()
}
