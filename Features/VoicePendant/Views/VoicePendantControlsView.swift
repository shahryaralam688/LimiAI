//
//  VoicePendantControlsView.swift
//  Limi
//
//  Device controls screen — volume management, live status monitoring,
//  AI model selection and device configuration.
//

import SwiftUI

struct VoicePendantControlsView: View {
    @ObservedObject var viewModel: VoicePendantDetailViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                statusMonitorCard
                if let binding = settingsBinding {
                    volumeCard(binding)
                    configurationCard(binding)
                }
                aiModelCard
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Device Controls")
        .navigationBarTitleDisplayMode(.inline)
        .vpToast($viewModel.toastMessage)
        .task { await viewModel.loadAll() }
        .trackScreen("VoicePendantControlsView", metadata: ["pendant": viewModel.pendant.id])
    }

    private var settingsBinding: Binding<VoicePendantSettings>? {
        guard viewModel.settings != nil else { return nil }
        return Binding(
            get: { viewModel.settings ?? Self.placeholder },
            set: { viewModel.settings = $0 }
        )
    }

    // MARK: - Status Monitoring

    private var statusMonitorCard: some View {
        VPSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Status Monitoring")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Spacer()
                    Button {
                        Task { await viewModel.refreshStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.appBorderSoft)
                            .rotationEffect(.degrees(viewModel.isLoadingStatus ? 360 : 0))
                            .animation(viewModel.isLoadingStatus ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                       value: viewModel.isLoadingStatus)
                    }
                }

                if let status = viewModel.status {
                    HStack(spacing: 12) {
                        VPMetricChip(icon: status.isCharging ? "battery.100.bolt" : "battery.75",
                                     value: "\(status.batteryLevel)%", label: status.isCharging ? "Charging" : "Battery")
                        VPMetricChip(icon: "wifi", value: "\(status.signalStrength)/4", label: "Signal")
                        VPMetricChip(icon: "thermometer.medium", value: "\(Int(status.temperatureC))°", label: "Temp")
                    }

                    VStack(spacing: 0) {
                        infoRow("Activity", status.activity)
                        divider
                        infoRow("Uptime", "\(status.uptimeHours)h")
                        divider
                        infoRow("Firmware", "v\(status.firmwareVersion)")
                        divider
                        storageRow(status)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
        }
    }

    private func storageRow(_ status: VoicePendantStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Storage")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
                Text("\(status.storageUsedMB) / \(status.storageTotalMB) MB")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.themeWhite)
            }
            ProgressView(value: status.storageUsedFraction)
                .tint(.orbGlow4)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Volume

    private func volumeCard(_ s: Binding<VoicePendantSettings>) -> some View {
        VPSectionCard("Volume & Audio") {
            VStack(spacing: 18) {
                sliderRow(icon: "speaker.wave.3.fill", title: "Volume",
                          value: s.volume, tint: .orbGlow4)
                divider
                sliderRow(icon: "mic.fill", title: "Mic sensitivity",
                          value: s.micSensitivity, tint: .emerald)
                divider
                sliderRow(icon: "light.max", title: "LED brightness",
                          value: s.ledBrightness, tint: .orange)
            }
        }
    }

    private func sliderRow(icon: String, title: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeWhite)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
            }
            Slider(value: value, in: 0...1) { editing in
                if !editing { Task { await viewModel.save() } }
            }
            .tint(tint)
        }
    }

    // MARK: - Configuration

    private func configurationCard(_ s: Binding<VoicePendantSettings>) -> some View {
        VPSectionCard("Configuration") {
            Toggle(isOn: s.wakeWordEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wake word")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.themeWhite)
                    Text("Respond to “Hey Limi”")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                }
            }
            .tint(.emerald)
            .onChange(of: s.wrappedValue.wakeWordEnabled) { _, _ in
                Task { await viewModel.save() }
            }
        }
    }

    // MARK: - AI Model Selection

    private var aiModelCard: some View {
        VPSectionCard("AI Model", subtitle: "Choose the model powering this pendant") {
            VStack(spacing: 10) {
                if viewModel.aiModels.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(viewModel.aiModels) { model in
                        modelRow(model)
                    }
                }
            }
        }
    }

    private func modelRow(_ model: AIModelOption) -> some View {
        let isSelected = viewModel.settings?.aiModelID == model.id
        return Button {
            viewModel.selectModel(model)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(isSelected ? .emerald : Color.appTextMuted)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.themeWhite)
                        Text(model.tier)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orbGlow4)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orbGlow4.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(model.detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.appTextTertiary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.orbGlow4.opacity(0.08) : Color.appSurfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orbGlow4.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeWhite)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(Color.themeWhite.opacity(0.06)).frame(height: 1)
    }

    private static let placeholder = VoicePendantSettings(
        displayName: "", room: "", volume: 0.5, micSensitivity: 0.5,
        wakeWordEnabled: true, aiModelID: "", language: "en-US",
        ledBrightness: 0.5, privacyMute: false
    )
}
