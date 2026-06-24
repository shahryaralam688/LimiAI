import SwiftUI

struct IntegrateNewAIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var voiceIntegrationEnabled = true
    @State private var knowledgeAccessEnabled = true
    @State private var appeared = false

    var body: some View {
        ZStack {
            DeepSpaceBackground(showParticles: false)

            VStack(spacing: 0) {
                AIAppBar(title: "Limi Assistant") {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // AI Service Header
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orbGlow1.opacity(0.15), .orbGlow4.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)

                                Image("humbleicons_ai")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.orbGlow4)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Limi assistant")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.appTextPrimary)
                                Text("Built for your space")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.appTextSecondary)
                            }
                            Spacer()
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                        // About Section
                        VStack(alignment: .leading, spacing: 10) {
                            LimiSectionHeader(title: "About")
                            Text("Limi helps you adjust your environment, answer questions about your setup, and keep briefings relevant to you — without sending you to another product.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.appTextSecondary)
                                .lineSpacing(5)
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                        // Integration Options
                        VStack(alignment: .leading, spacing: 12) {
                            LimiSectionHeader(title: "Integration")

                            IntegrationOption(
                                title: "Voice Integration",
                                subtitle: "Talk to Limi naturally.",
                                isEnabled: $voiceIntegrationEnabled
                            )
                            IntegrationOption(
                                title: "Knowledge Access",
                                subtitle: "Summarize your itinerary or travel plans.",
                                isEnabled: $knowledgeAccessEnabled
                            )
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                        AIButton(title: "Confirm", style: .primary) {
                            dismiss()
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

#Preview {
    IntegrateNewAIView()
}
