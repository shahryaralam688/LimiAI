//
//  VoicePendantAudioView.swift
//  Limi
//
//  Audio Sharing screen — send audio from the app to the pendant, playback
//  controls (simulated) and voice note management (record / share / delete).
//

import SwiftUI
import UniformTypeIdentifiers

struct VoicePendantAudioView: View {
    @StateObject private var viewModel: VoicePendantAudioViewModel
    @ObservedObject private var recorder: VoicePendantAudioRecorder
    @State private var showImporter = false

    init(pendant: VoicePendant) {
        let vm = VoicePendantAudioViewModel(pendant: pendant)
        _viewModel = StateObject(wrappedValue: vm)
        _recorder = ObservedObject(wrappedValue: vm.recorder)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                recordCard
                nowPlayingCard
                voiceNotesSection
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Audio Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .vpToast($viewModel.toastMessage)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImportResult(result)
        }
        .task {
            if viewModel.voiceNotes.isEmpty { await viewModel.load() }
        }
        .trackScreen("VoicePendantAudioView", metadata: ["pendant": viewModel.pendant.id])
    }

    // MARK: - Record / Import

    private var recordCard: some View {
        VPSectionCard("Send Audio", subtitle: "Record a note or import audio, then send it to the pendant") {
            VStack(spacing: 14) {
                recordRow
                if recorder.isRecording { recordingMeter }
                divider
                importRow
            }
        }
    }

    private var recordRow: some View {
        Button {
            if recorder.isRecording {
                viewModel.stopRecordingAndSave()
            } else {
                Task { await viewModel.startRecording() }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.appDanger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.isRecording ? "Recording…" : "Record new note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text(recorder.isRecording ? timeString(recorder.elapsed) : "Tap to capture a voice message")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                }
                Spacer()
                if recorder.isRecording {
                    Circle()
                        .fill(Color.appDanger)
                        .frame(width: 12, height: 12)
                        .opacity(0.4 + 0.6 * recorder.level)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(Color.appBorderSoft)
                }
            }
            .padding(12)
            .background(Color.appSurfacePrimary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var recordingMeter: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.themeWhite.opacity(0.08))
                    Capsule().fill(Color.appDanger.opacity(0.8))
                        .frame(width: max(6, geo.size.width * recorder.level))
                }
            }
            .frame(height: 8)

            Button {
                viewModel.cancelRecording()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }

    private var importRow: some View {
        Button {
            showImporter = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(.orbGlow4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from Files")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text("Pick audio from storage or another app")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(12)
            .background(Color.appSurfacePrimary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Now Playing

    @ViewBuilder
    private var nowPlayingCard: some View {
        if let activeID = viewModel.playback.activeNoteID,
           let note = viewModel.voiceNotes.first(where: { $0.id == activeID }) {
            VPSectionCard("Now Playing") {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.orbGlow4)
                        Text(note.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.themeWhite)
                        Spacer()
                        Text(note.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    ProgressView(value: viewModel.playbackProgress)
                        .tint(.orbGlow4)

                    HStack(spacing: 28) {
                        Spacer()
                        controlButton("stop.fill", size: 18) { viewModel.stop() }
                        controlButton(viewModel.playback.isPlaying(note.id) ? "pause.circle.fill" : "play.circle.fill",
                                      size: 44) {
                            viewModel.togglePlayback(for: note)
                        }
                        controlButton("paperplane.fill", size: 18) {
                            Task { await viewModel.share(note) }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func controlButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundColor(.themeWhite)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice Notes List

    private var voiceNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voice Notes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.themeWhite)
                Spacer()
                Text("\(viewModel.voiceNotes.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextMuted)
            }

            if viewModel.isLoading && viewModel.voiceNotes.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if viewModel.voiceNotes.isEmpty {
                Text("No voice notes yet. Record one above.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.appTextMuted)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(viewModel.voiceNotes) { note in
                    voiceNoteRow(note)
                }
            }
        }
    }

    private func voiceNoteRow(_ note: VoiceNote) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePlayback(for: note)
            } label: {
                Image(systemName: viewModel.playback.isPlaying(note.id) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.orbGlow4)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.themeWhite)
                HStack(spacing: 8) {
                    Text(note.formattedDuration)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)

                    HStack(spacing: 3) {
                        Image(systemName: note.source.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(note.source.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color.appTextMuted)

                    if note.sharedToPendant {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Shared")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.emerald)
                    }
                }
            }

            Spacer()

            shareButton(note)
        }
        .padding(12)
        .background(Color.appSurfaceSecondaryAlt)
        .cornerRadius(14)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.delete(note) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func shareButton(_ note: VoiceNote) -> some View {
        if viewModel.isSharing(note) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                .frame(width: 36, height: 36)
        } else {
            Button {
                Task { await viewModel.share(note) }
            } label: {
                Image(systemName: note.sharedToPendant ? "arrow.triangle.2.circlepath" : "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.appBorderSoft)
                    .frame(width: 36, height: 36)
                    .background(Color.appSurfacePrimary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.themeWhite.opacity(0.06)).frame(height: 1)
    }
}

#Preview {
    NavigationStack {
        VoicePendantAudioView(
            pendant: VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                                  status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2")
        )
    }
}
