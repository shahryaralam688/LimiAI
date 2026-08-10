//
//  VoicePendantControlView.swift
//  Limi
//
//  Per-pendant control sheet. Sends commands (voice package / play song /
//  stop) through the backend, which relays them to the hardware.
//

import SwiftUI

struct VoicePendantControlView: View {
    let pendant: VoicePendant
    @ObservedObject var viewModel: VoicePendantScanViewModel
    @Environment(\.dismiss) private var dismiss

    /// Demo catalogue of songs the backend could play on the hardware.
    private let demoTracks: [(id: String, title: String, artist: String)] = [
        ("track-101", "Calm Morning", "Limi Ambient"),
        ("track-102", "Focus Flow", "Limi Ambient"),
        ("track-103", "Evening Wind Down", "Limi Ambient")
    ]

    /// Demo recorded voice packages.
    private let demoVoicePackages: [(id: String, label: String)] = [
        ("vp-welcome", "Welcome Home greeting"),
        ("vp-reminder", "Reminder announcement"),
        ("vp-goodnight", "Goodnight message")
    ]

    private var isBusy: Bool { viewModel.isSendingCommand(pendant) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    summaryCard
                    voicePackagesSection
                    songsSection
                    stopSection
                }
                .padding(16)
            }
            .background(Color.appCanvasPrimary.ignoresSafeArea())
            .limiModalNavigationBar(title: pendant.name, onClose: { dismiss() })
        }
        .trackScreen("VoicePendantControlView", metadata: ["pendant": pendant.id])
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(LimiTypography.title2)
                .foregroundColor(.appTextPrimary)
            VStack(alignment: .leading, spacing: 4) {
                Text(pendant.name)
                    .font(LimiTypography.button)
                    .foregroundColor(.appTextPrimary)
                Text(pendant.room)
                    .font(LimiTypography.footnote)
                    .foregroundColor(Color.appTextTertiary)
            }
            Spacer()
            if isBusy {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .limiPanel(cornerRadius: 16)
    }

    // MARK: - Voice Packages

    private var voicePackagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Voice Packages", subtitle: "Stream a recorded voice clip to this pendant")
            ForEach(demoVoicePackages, id: \.id) { package in
                commandRow(
                    icon: "mic.fill",
                    title: package.label,
                    subtitle: package.id
                ) {
                    Task {
                        await viewModel.send(.voicePackage(packageID: package.id), to: pendant)
                    }
                }
            }
        }
    }

    // MARK: - Songs

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Play a Song", subtitle: "Backend relays playback to the hardware")
            ForEach(demoTracks, id: \.id) { track in
                commandRow(
                    icon: "music.note",
                    title: track.title,
                    subtitle: track.artist
                ) {
                    Task {
                        await viewModel.send(.playSong(trackID: track.id, title: track.title), to: pendant)
                    }
                }
            }
        }
    }

    // MARK: - Stop

    private var stopSection: some View {
        Button {
            Task { await viewModel.send(.stop, to: pendant) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stop.fill")
                Text("Stop Playback")
                    .font(LimiTypography.callout)
            }
            .foregroundColor(.appTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appSurfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appBorderSecondary, lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .disabled(isBusy)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
            Text(subtitle)
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
        }
    }

    private func commandRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.themeBlack.opacity(0.25))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextPrimary)
                    Text(subtitle)
                        .font(LimiTypography.caption)
                        .foregroundColor(Color.appTextTertiary)
                }

                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(LimiTypography.callout)
                    .foregroundColor(Color.appBorderSoft)
            }
            .padding(14)
            .limiPanel(cornerRadius: 16)
        }
        .disabled(isBusy)
    }
}

#Preview {
    VoicePendantControlView(
        pendant: VoicePendant(
            id: "pendant-001",
            name: "Living Room Pendant",
            room: "Living Room",
            status: .online,
            batteryLevel: 92,
            signalStrength: 4,
            firmwareVersion: "1.4.2"
        ),
        viewModel: VoicePendantScanViewModel()
    )
}
