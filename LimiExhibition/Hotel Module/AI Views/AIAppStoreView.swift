import SwiftUI

struct AIAppStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var voiceEnabled = true
    @State private var controlEnabled = true
    @State private var contextEnabled = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            DeepSpaceBackground(showParticles: false)

            VStack(spacing: 0) {
                AIAppBar(title: "Limi intelligence") {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        LimiSectionHeader(title: "Capabilities")
                            .padding(.horizontal, 20)

                        VStack(spacing: 14) {
                            ModelCard(
                                iconName: "VoiceAi",
                                title: "Voice",
                                tags: ["Limi"],
                                connectionStatus: voiceEnabled ? "Active" : "Off",
                                tokenCount: "Included",
                                isConnected: voiceEnabled
                            ) {
                                voiceEnabled.toggle()
                            }
                            .offset(y: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)

                            ModelCard(
                                iconName: "ic_outline-assistant",
                                title: "Space control",
                                tags: ["Limi"],
                                connectionStatus: controlEnabled ? "Active" : "Off",
                                tokenCount: "Included",
                                isConnected: controlEnabled
                            ) {
                                controlEnabled.toggle()
                            }
                            .offset(y: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                            ModelCard(
                                iconName: "humbleicons_ai",
                                title: "Context",
                                tags: ["Limi"],
                                connectionStatus: contextEnabled ? "Active" : "Available",
                                tokenCount: "Included",
                                isConnected: contextEnabled
                            ) {
                                contextEnabled.toggle()
                            }
                            .offset(y: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
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
    AIAppStoreView()
}
