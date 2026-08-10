//
//  VoicePendantScanView.swift
//  Limi
//
//  Entry screen for the Voice Pendant Scan module. Lists pendants returned by
//  the backend (currently a pseudo/demo call) and lets the user open a pendant
//  to send voice packages or play songs.
//

import SwiftUI

struct VoicePendantScanView: View {
    @Environment(\.dismiss) private var dismiss
    var onBack: () -> Void = {}

    @StateObject private var viewModel: VoicePendantScanViewModel
    @State private var selectedPendant: VoicePendant?
    @State private var showAcknowledgement = false
    @State private var showBluetoothSetup = false

    private let columns = [GridItem(.flexible(), spacing: 16)]

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: VoicePendantScanViewModel())
    }

    @MainActor
    init(viewModel: VoicePendantScanViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    subtitleRow
                    content
                }
            }
            .overlay(alignment: .bottom) { acknowledgementToast }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    return
                }
                #endif
                if viewModel.pendants.isEmpty {
                    await viewModel.scan()
                }
            }
            .onChange(of: viewModel.lastAcknowledgement) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showAcknowledgement = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut) { showAcknowledgement = false }
                    viewModel.lastAcknowledgement = nil
                }
            }
            .navigationDestination(item: $selectedPendant) { pendant in
                VoicePendantDetailView(pendant: pendant)
            }
            .fullScreenCover(isPresented: $showBluetoothSetup) {
                VoicePendantBluetoothConfigView()
            }
            .limiModalNavigationBar(title: "Voice Pendants", onClose: {
                onBack()
                dismiss()
            })
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    addPendantButton
                    rescanButton
                }
            }
        }
        .trackScreen("VoicePendantScanView", metadata: ["surface": "home_modules"])
    }

    // MARK: - Subtitle (single header row — nav bar handles title + close)

    private var subtitleRow: some View {
        LimiModuleSubtitle(text: "Discover pendants on your account")
    }

    private var addPendantButton: some View {
        Button {
            showBluetoothSetup = true
        } label: {
            Image(systemName: "plus")
                .font(LimiTypography.callout)
                .foregroundColor(.brandAction)
        }
        .accessibilityLabel("Set up new pendant")
    }

    private var rescanButton: some View {
        Button {
            Task { await viewModel.scan() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(LimiTypography.callout)
                .foregroundColor(.brandAction)
                .rotationEffect(.degrees(viewModel.isScanning ? 360 : 0))
                .animation(
                    viewModel.isScanning
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: viewModel.isScanning
                )
        }
        .disabled(viewModel.isScanning)
        .accessibilityLabel("Rescan pendants")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning && viewModel.pendants.isEmpty {
            scanningState
        } else if let error = viewModel.errorMessage, viewModel.pendants.isEmpty {
            errorState(error)
        } else if viewModel.pendants.isEmpty {
            emptyState
        } else {
            pendantList
        }
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                .scaleEffect(1.2)
            Text("Scanning for pendants…")
                .font(LimiTypography.callout)
                .foregroundColor(Color.appTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(LimiTypography.title2)
                .foregroundColor(Color.appTextMuted)
            Text(message)
                .font(LimiTypography.callout)
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            LimiPrimaryButton(title: "Try Again") {
                Task { await viewModel.scan() }
            }
            .frame(width: 200)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(LimiTypography.title2)
                .foregroundColor(Color.appTextMuted)
            Text("No pendants found")
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
            Text("Make sure your pendants are powered on and on the same network.")
                .font(LimiTypography.subheadline)
                .foregroundColor(Color.appTextMuted)
                .multilineTextAlignment(.center)
            LimiPrimaryButton(title: "Set Up New Pendant") {
                showBluetoothSetup = true
            }
            .frame(width: 220)
            Button("Scan Again") {
                Task { await viewModel.scan() }
            }
            .font(LimiTypography.callout)
            .foregroundColor(Color.appBorderSoft)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pendantList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    Text("Found \(viewModel.pendants.count) pendant\(viewModel.pendants.count == 1 ? "" : "s")")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.pendants) { pendant in
                        VoicePendantCard(
                            pendant: pendant,
                            isConnecting: viewModel.isConnecting(pendant),
                            onTap: { selectedPendant = pendant },
                            onConnect: {
                                Task { await viewModel.connect(to: pendant) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .limiFloatingOrbClearance()
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var acknowledgementToast: some View {
        if showAcknowledgement, let message = viewModel.lastAcknowledgement {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(LimiTypography.button)
                    .foregroundColor(Color.brandAction)
                Text(message)
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .limiPanel(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appGlassStrokeLight, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .limiFloatingOrbClearance()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Pendant Card

struct VoicePendantCard: View {
    let pendant: VoicePendant
    let isConnecting: Bool
    let onTap: () -> Void
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pendant.name)
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                    Text(pendant.room)
                        .font(LimiTypography.footnote)
                        .foregroundColor(Color.appTextTertiary)
                }

                Spacer(minLength: 8)
                statusBadge
            }

            HStack(spacing: 16) {
                if let battery = pendant.batteryLevel {
                    metric(icon: "battery.100", value: "\(battery)%")
                }
                if let signal = pendant.signalStrength {
                    metric(icon: "wifi", value: "\(signal)/4")
                }
                if let firmware = pendant.firmwareVersion {
                    metric(icon: "cpu", value: "v\(firmware)")
                }
                Spacer()
            }

            actionRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .limiPanel(cornerRadius: 16)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(pendant.status.displayName)
                .font(LimiTypography.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
        .fixedSize()
    }

    private var statusColor: Color {
        switch pendant.status {
        case .online: return .emerald
        case .pairing: return .orange
        case .offline: return .gray
        }
    }

    private func metric(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(LimiTypography.caption2)
            Text(value)
                .font(LimiTypography.caption)
        }
        .foregroundColor(Color.appTextTertiary)
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack {
            Spacer()
            if pendant.status == .online {
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(LimiTypography.callout)
                        Text("Control")
                            .font(LimiTypography.footnote)
                    }
                    .foregroundColor(Color.appBorderSoft)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 360)
                            .stroke(Color.appBorderSoft, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            } else if pendant.status == .pairing {
                Button(action: onConnect) {
                    HStack(spacing: 8) {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link")
                                .font(LimiTypography.callout)
                        }
                        Text(isConnecting ? "Connecting…" : "Connect")
                            .font(LimiTypography.footnote)
                    }
                    .foregroundColor(Color.appBorderSoft)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 360)
                            .stroke(Color.appBorderSoft, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isConnecting)
            } else {
                Text("Unavailable")
                    .font(LimiTypography.footnote)
                    .foregroundColor(Color.appTextMuted)
                    .padding(.vertical, 10)
            }
        }
    }
}

#if DEBUG
#Preview("Voice Pendants — API devices") {
    VoicePendantScanView(
        viewModel: VoicePendantScanViewModel(previewPendants: VoicePendant.previewFromAPI)
    )
}

#Preview("Voice Pendants — scanning") {
    VoicePendantScanView(
        viewModel: VoicePendantScanViewModel(previewPendants: [], isScanning: true)
    )
}

#Preview("Voice Pendant card") {
    ZStack {
        Color.appCanvasPrimary.ignoresSafeArea()
        VoicePendantCard(
            pendant: VoicePendant.previewFromAPI[0],
            isConnecting: false,
            onTap: {},
            onConnect: {}
        )
        .padding(16)
    }
}
#endif
