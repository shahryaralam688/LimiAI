//
//  VoicePendantSettingsView.swift
//  Limi
//
//  Device settings screen — name, room, language, wake word and privacy.
//  Shares `VoicePendantDetailViewModel` with the detail hub + controls.
//

import SwiftUI

struct VoicePendantSettingsView: View {
    @ObservedObject var viewModel: VoicePendantDetailViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let binding = settingsBinding {
                VStack(spacing: 20) {
                    identityCard(binding)
                    voiceCard(binding)
                    privacyCard(binding)
                    saveButton
                }
                .padding(16)
                .padding(.bottom, 32)
            } else {
                loadingState
            }
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .vpToast($viewModel.toastMessage)
        .task {
            if viewModel.settings == nil { await viewModel.loadSettings() }
        }
        .trackScreen("VoicePendantSettingsView", metadata: ["pendant": viewModel.pendant.id])
    }

    private var settingsBinding: Binding<VoicePendantSettings>? {
        guard viewModel.settings != nil else { return nil }
        return Binding(
            get: { viewModel.settings ?? Self.placeholder },
            set: { viewModel.settings = $0 }
        )
    }

    // MARK: - Cards

    private func identityCard(_ s: Binding<VoicePendantSettings>) -> some View {
        VPSectionCard("Identity", subtitle: "How this pendant appears in your home") {
            VStack(spacing: 14) {
                labeledField("Name") {
                    TextField("Pendant name", text: s.displayName)
                        .textFieldStyle(.plain)
                        .foregroundColor(.themeWhite)
                }
                divider
                labeledField("Room") {
                    TextField("Room", text: s.room)
                        .textFieldStyle(.plain)
                        .foregroundColor(.themeWhite)
                }
            }
        }
    }

    private func voiceCard(_ s: Binding<VoicePendantSettings>) -> some View {
        VPSectionCard("Voice & Language") {
            VStack(spacing: 16) {
                Toggle(isOn: s.wakeWordEnabled) {
                    settingLabel("Wake word", "Respond to “Hey Limi”")
                }
                .tint(.emerald)

                divider

                VStack(alignment: .leading, spacing: 8) {
                    settingLabel("Language", "Conversation language")
                    Picker("Language", selection: s.language) {
                        ForEach(VoicePendantSettings.supportedLanguages, id: \.tag) { lang in
                            Text(lang.label).tag(lang.tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.orbGlow4)
                }
            }
        }
    }

    private func privacyCard(_ s: Binding<VoicePendantSettings>) -> some View {
        VPSectionCard("Privacy") {
            Toggle(isOn: s.privacyMute) {
                settingLabel("Privacy mute", "Disable the microphone entirely")
            }
            .tint(.appDanger)
        }
    }

    private var saveButton: some View {
        LimiPrimaryButton(title: "Save Settings", isLoading: viewModel.isSaving) {
            Task { await viewModel.save() }
        }
    }

    // MARK: - Helpers

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            content()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200, alignment: .trailing)
        }
    }

    private func settingLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.themeWhite)
            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.appTextTertiary)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.themeWhite.opacity(0.06)).frame(height: 1)
    }

    private var loadingState: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private static let placeholder = VoicePendantSettings(
        displayName: "", room: "", volume: 0.5, micSensitivity: 0.5,
        wakeWordEnabled: true, aiModelID: "", language: "en-US",
        ledBrightness: 0.5, privacyMute: false
    )
}
