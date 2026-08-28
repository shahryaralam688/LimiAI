//
//  DeviceControlLayout.swift
//  Limi
//
//  Shared scroll + sizing for CCT / RGB device control screens (sheet & navigation).
//

import SwiftUI

// MARK: - Metrics

/// Sizes from the real container (sheet height), not `UIScreen.main`.
struct DeviceControlLayoutMetrics {
    let size: CGSize
    let safeBottom: CGFloat

    var previewHeight: CGFloat {
        let byHeight = size.height * 0.28
        let byWidth = size.width * 0.72
        return min(max(min(byHeight, byWidth), 180), 300)
    }

    var webConfiguratorHeight: CGFloat {
        min(max(size.height * 0.34, 220), 380)
    }

    var horizontalPadding: CGFloat { 16 }
    var sectionSpacing: CGFloat { 14 }
    var scrollBottomInset: CGFloat { max(safeBottom, 12) + 16 }
}

// MARK: - Scroll shell

/// Full-height scroll container; content sizes to width, never stretches vertically.
struct DeviceControlScreenLayout<Content: View>: View {
    @ViewBuilder var content: (DeviceControlLayoutMetrics) -> Content

    var body: some View {
        GeometryReader { geo in
            let metrics = DeviceControlLayoutMetrics(
                size: geo.size,
                safeBottom: geo.safeAreaInsets.bottom
            )
            ScrollView(.vertical, showsIndicators: false) {
                content(metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, metrics.scrollBottomInset)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Color.appCanvasPrimary)
    }
}

// MARK: - Reusable blocks

/// Rounded card wrapper used by power / color / picker sections.
struct DeviceControlSectionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurfacePrimary)
            )
    }
}

/// AR preview or web configurator block with gear toggle.
struct DeviceControlPreviewHeader: View {
    let macAddress: String?
    @Binding var selectedTopTab: Int
    @Binding var showToast: Bool
    let isOnline: Bool
    let metrics: DeviceControlLayoutMetrics
    var gearActiveColor: Color = .brandAction
    var gearIdleColor: Color = Color.appTextMuted.opacity(0.4)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if selectedTopTab == 0 {
                    StaticLightARViewContainer(macAddress: macAddress)
                        .frame(height: metrics.previewHeight)
                } else if let token = AuthManager.shared.getToken(),
                          let url = URL(string: AppURLs.Web.configuratorV2(token: token)) {
                    LimiWebViewCon(url: url, macAddress: macAddress)
                        .frame(height: metrics.webConfiguratorHeight)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurfacePrimary)
                        .frame(height: metrics.previewHeight)
                        .overlay {
                            Text("Configurator unavailable")
                                .font(LimiTypography.footnote)
                                .foregroundColor(.appTextSecondary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                if selectedTopTab == 0 {
                    if isOnline { selectedTopTab = 1 } else { showToast = true }
                } else {
                    selectedTopTab = 0
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(selectedTopTab == 1 ? gearActiveColor : gearIdleColor)
                    .clipShape(Circle())
            }
            .padding(12)
        }
    }
}

// MARK: - Transport path badge

struct DeviceControlPathDisplay {
    let deviceId: String
    let preference: TransportMediumPreference

    var effectiveDoor: Door { LimiTransport.shared.door(for: deviceId) }
    var firmwareDoor: Door { LimiTransport.shared.firmwareDoor(for: deviceId) }
    var isManualOverride: Bool { preference != .automatic }

    var iconName: String {
        switch effectiveDoor {
        case .mqtt: return "cloud.fill"
        case .webSocket: return "wifi"
        case .ble: return "antenna.radiowaves.left.and.right"
        case .unreachable: return "exclamationmark.triangle.fill"
        }
    }
}

struct DeviceControlPathStatusView: View {
    let display: DeviceControlPathDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: display.iconName)
                    .font(LimiTypography.caption2)
                Text(display.effectiveDoor.description)
                    .font(LimiTypography.caption2)
            }
            .foregroundColor(.appTextPrimary.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.appSurfaceSecondaryAlt.opacity(0.9))
            )

            if display.isManualOverride {
                Text("Manual: \(display.preference.shortTitle) · Auto would: \(display.firmwareDoor.description)")
                    .font(LimiTypography.caption2)
                    .foregroundColor(.appTextPrimary.opacity(0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Control path picker (Connected Devices list)

struct ControlPathPickerCard: View {
    @ObservedObject var store: TransportMediumPreferenceStore

    var body: some View {
        DeviceControlSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(LimiTypography.callout)
                        .foregroundColor(.brandAction)
                    Text("Control path")
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }

                Picker("Control path", selection: $store.preference) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        Text(medium.pickerTitle).tag(medium)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.brandAction)

                Text(store.preference == .automatic
                     ? "App picks MQTT, LAN, or BLE automatically."
                     : "Testing mode — commands always use \(store.preference.shortTitle).")
                    .font(LimiTypography.caption2)
                    .foregroundColor(.appTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Offline / unavailable overlay

/// Shown when a provisioned device is powered off or unreachable while the user is on a control screen.
struct DeviceControlUnavailableOverlay: View {
    var title: String = "Device Unavailable"
    var message: String = "This device is off or not reachable. Turn it on and wait a moment."

    var body: some View {
        ZStack {
            Color.appOverlayScrimLight
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "power.circle")
                    .font(.system(size: LimiIconSize.section, weight: .regular))
                    .foregroundColor(.appTextSecondary)

                Text(title)
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)

                Text(message)
                    .font(LimiTypography.subheadline)
                    .foregroundColor(.appTextMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .glassCard(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.appGlassStrokeLight, lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

private struct DeviceControlAvailabilityModifier: ViewModifier {
    @ObservedObject var transportState: DeviceTransportState
    @ObservedObject private var socket = LightControllingSocket.shared
    @Binding var didShowOfflineNotice: Bool

    private var shouldShowUnavailable: Bool {
        if transportState.isAvailableForControl { return false }
        // Wi‑Fi provisioned hubs always use cloud MQTT — don't block while reconnecting.
        if transportState.activeDoor == .mqtt { return false }
        if socket.connectionStatus == .connecting { return false }
        return true
    }

    func body(content: Content) -> some View {
        content
            .disabled(shouldShowUnavailable)
            .opacity(shouldShowUnavailable ? 0.45 : 1)
            .overlay {
                if shouldShowUnavailable {
                    DeviceControlUnavailableOverlay()
                }
            }
            .animation(.easeInOut(duration: 0.22), value: shouldShowUnavailable)
            .onChange(of: shouldShowUnavailable) { _, unavailable in
                guard unavailable, !didShowOfflineNotice else { return }
                didShowOfflineNotice = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .onAppear {
                if shouldShowUnavailable {
                    didShowOfflineNotice = true
                }
            }
    }
}

extension View {
    /// Dims controls and shows a light popup when the device is off or unreachable.
    func deviceControlAvailability(
        transportState: DeviceTransportState,
        didShowOfflineNotice: Binding<Bool>
    ) -> some View {
        modifier(DeviceControlAvailabilityModifier(
            transportState: transportState,
            didShowOfflineNotice: didShowOfflineNotice
        ))
    }
}

// MARK: - Sheet chrome

/// Navigation + sheet chrome for device control from Connected Devices.
struct DeviceControlNavigationShell<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.appCanvasPrimary)
                .navigationTitle(subtitle == nil ? title : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                            .font(LimiTypography.headline)
                            .foregroundColor(.brandAction)
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(title)
                                .font(LimiTypography.headline)
                            if let subtitle {
                                Text(subtitle)
                                    .font(LimiTypography.caption2)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                    }
                }
                .toolbarBackground(Color.appCanvasPrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.appCanvasPrimary)
    }
}

extension View {
    /// Standard sheet sizing for multi-channel / advanced flows.
    func deviceControlSheetStyle() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .presentationBackground(Color.appCanvasPrimary)
    }
}
