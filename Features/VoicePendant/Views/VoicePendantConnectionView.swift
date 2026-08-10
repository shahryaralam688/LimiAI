//
//  VoicePendantConnectionView.swift
//  Limi
//
//  Device connection screen — shows the link/connection state to a pendant
//  and lets the user (re)connect. Uses the scan service's connect flow.
//

import SwiftUI

struct VoicePendantConnectionView: View {
    let pendant: VoicePendant

    @State private var status: VoicePendantStatus
    @State private var isConnecting = false
    @State private var stepIndex = 0
    @State private var errorMessage: String?

    private let service: VoicePendantServicing = VoicePendantService.current

    private let steps = ["Reaching pendant", "Authenticating", "Opening session", "Connected"]

    init(pendant: VoicePendant) {
        self.pendant = pendant
        _status = State(initialValue: pendant.status)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                connectionHero
                stepsCard
                detailsCard
                actionButton
                if let errorMessage {
                    Text(errorMessage)
                        .font(LimiTypography.footnote)
                        .foregroundColor(.appDanger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Connection")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("VoicePendantConnectionView", metadata: ["pendant": pendant.id])
    }

    // MARK: - Hero

    private var connectionHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ringColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(ringColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 120, height: 120)
                Image(systemName: status == .online ? "link.circle.fill" : "link.circle")
                    .font(LimiTypography.title2)
                    .foregroundColor(ringColor)
            }
            VPStatusPill(status: status)
            Text(status == .online ? "Your pendant is connected and ready."
                                   : "This pendant isn't connected yet.")
                .font(LimiTypography.subheadline)
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var ringColor: Color {
        switch status {
        case .online: return .emerald
        case .pairing: return .orange
        case .offline: return .gray
        }
    }

    // MARK: - Steps

    private var stepsCard: some View {
        VPSectionCard("Connection Steps") {
            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        stepIcon(for: index)
                        Text(step)
                            .font(LimiTypography.callout)
                            .foregroundColor(index <= stepIndex || status == .online ? .themeWhite : Color.appTextMuted)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepIcon(for index: Int) -> some View {
        let done = status == .online || index < stepIndex
        let active = isConnecting && index == stepIndex
        ZStack {
            Circle()
                .fill(done ? Color.brandAction.opacity(0.15) : Color.appSurfacePrimary)
                .frame(width: 28, height: 28)
            if active {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    .scaleEffect(0.7)
            } else {
                Image(systemName: done ? "checkmark" : "circle.fill")
                    .font(.system(size: done ? 12 : 6, weight: .bold))
                    .foregroundColor(done ? .emerald : Color.appTextMuted)
            }
        }
    }

    // MARK: - Details

    private var detailsCard: some View {
        VPSectionCard("Network") {
            VStack(spacing: 0) {
                detailRow("Pendant ID", pendant.id)
                divider
                detailRow("Signal", pendant.signalStrength.map { "\($0)/4 bars" } ?? "Unknown")
                divider
                detailRow("Firmware", pendant.firmwareVersion.map { "v\($0)" } ?? "Unknown")
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(LimiTypography.subheadline)
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(Color.appGlassFillMedium).frame(height: 1)
    }

    // MARK: - Action

    @ViewBuilder
    private var actionButton: some View {
        if status == .online {
            LimiPrimaryButton(title: isConnecting ? "Reconnecting…" : "Reconnect", isLoading: isConnecting) {
                connect()
            }
        } else if status == .pairing {
            LimiPrimaryButton(title: isConnecting ? "Connecting…" : "Connect", isLoading: isConnecting) {
                connect()
            }
        } else {
            Text("Pendant is offline. Power it on to connect.")
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }

    private func connect() {
        guard !isConnecting else { return }
        errorMessage = nil
        isConnecting = true
        stepIndex = 0

        Task {
            // Animate through the visual steps while the request runs.
            let stepTask = Task { @MainActor in
                for index in 0..<(steps.count - 1) {
                    stepIndex = index
                    try? await Task.sleep(nanoseconds: 450_000_000)
                }
            }
            do {
                try await service.connect(to: pendant.id)
                await stepTask.value
                await MainActor.run {
                    stepIndex = steps.count - 1
                    status = .online
                    isConnecting = false
                }
            } catch {
                stepTask.cancel()
                await MainActor.run {
                    errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VoicePendantConnectionView(
            pendant: VoicePendant(id: "pendant-003", name: "Bedroom Pendant", room: "Bedroom",
                                  status: .pairing, batteryLevel: 45, signalStrength: 2, firmwareVersion: "1.3.9")
        )
    }
}
