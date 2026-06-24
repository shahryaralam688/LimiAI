//
//  VoicePendantDetailView.swift
//  Limi
//
//  Device detail hub. Shows an overview of the pendant + live status and
//  routes to Connection, Controls, Settings, Memory and Audio Sharing.
//
//  Pushed onto the scan screen's NavigationStack, so sub-screens use plain
//  NavigationLinks for a natural drill-down.
//

import SwiftUI

struct VoicePendantDetailView: View {
    @StateObject private var viewModel: VoicePendantDetailViewModel
    @State private var showVoiceAI = false

    init(pendant: VoicePendant) {
        _viewModel = StateObject(wrappedValue: VoicePendantDetailViewModel(pendant: pendant))
    }

    private var pendant: VoicePendant { viewModel.pendant }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                overviewCard
                talkToLimiButton
                statusStrip
                managementSection
                intelligenceSection
                audioSection
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle(pendant.name)
        .navigationBarTitleDisplayMode(.inline)
        .vpToast($viewModel.toastMessage)
        .task { await viewModel.loadAll() }
        .fullScreenCover(isPresented: $showVoiceAI) {
            VoiceView()
        }
        .trackScreen("VoicePendantDetailView", metadata: ["pendant": pendant.id])
    }

    // MARK: - AI Voice

    private var talkToLimiButton: some View {
        Button {
            showVoiceAI = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orbGlow4)
                    .frame(width: 40, height: 40)
                    .background(Color.orbGlow4.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Talk to Limi")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text("Start a voice conversation with your AI assistant")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.orbGlow4)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.appSurfaceSecondaryAlt)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orbGlow4.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Talk to Limi AI assistant")
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundColor(.themeWhite)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pendant.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text(pendant.room)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                }
                Spacer()
                VPStatusPill(status: pendant.status)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurfaceSecondaryAlt)
        .cornerRadius(16)
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        HStack(spacing: 12) {
            if let status = viewModel.status {
                VPMetricChip(icon: status.isCharging ? "battery.100.bolt" : "battery.75",
                             value: "\(status.batteryLevel)%", label: status.isCharging ? "Charging" : "Battery")
                VPMetricChip(icon: "wifi", value: "\(status.signalStrength)/4", label: "Signal")
                VPMetricChip(icon: "dot.radiowaves.left.and.right", value: status.activity, label: "Activity")
            } else if viewModel.isLoadingStatus {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VPMetricChip(icon: "battery.75", value: pendant.batteryLevel.map { "\($0)%" } ?? "—", label: "Battery")
                VPMetricChip(icon: "wifi", value: pendant.signalStrength.map { "\($0)/4" } ?? "—", label: "Signal")
                VPMetricChip(icon: "cpu", value: "v\(pendant.firmwareVersion ?? "—")", label: "Firmware")
            }
        }
    }

    // MARK: - Sections

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Device Management")
            NavigationLink {
                VoicePendantConnectionView(pendant: pendant)
            } label: {
                VPNavRow(icon: "link", title: "Connection",
                         subtitle: "Link status, network and re-pairing")
            }
            .buttonStyle(.plain)

            NavigationLink {
                VoicePendantSettingsView(viewModel: viewModel)
            } label: {
                VPNavRow(icon: "gearshape.fill", title: "Settings",
                         subtitle: "Name, language, wake word and privacy")
            }
            .buttonStyle(.plain)
        }
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Controls & Intelligence")
            NavigationLink {
                VoicePendantControlsView(viewModel: viewModel)
            } label: {
                VPNavRow(icon: "slider.horizontal.3", title: "Device Controls",
                         subtitle: "Volume, status, AI model and configuration",
                         accent: .orbGlow4)
            }
            .buttonStyle(.plain)

            NavigationLink {
                VoicePendantMemoryView(pendant: pendant)
            } label: {
                VPNavRow(icon: "brain.head.profile", title: "Summary & Memory",
                         subtitle: "Conversations, summaries, notes and timeline",
                         accent: .orbGlow4)
            }
            .buttonStyle(.plain)
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Audio Sharing")
            NavigationLink {
                VoicePendantAudioView(pendant: pendant)
            } label: {
                VPNavRow(icon: "waveform", title: "Audio Sharing",
                         subtitle: "Send audio, playback controls and voice notes")
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.themeWhite)
    }
}

#Preview {
    NavigationStack {
        VoicePendantDetailView(
            pendant: VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                                  status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2")
        )
    }
}
