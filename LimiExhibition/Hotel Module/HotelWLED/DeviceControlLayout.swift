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
    var gearActiveColor: Color = .orbGlow4
    var gearIdleColor: Color = Color.gray.opacity(0.4)

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
                                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                    .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 10, weight: .semibold))
                Text(display.effectiveDoor.description)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 10, weight: .regular, design: .rounded))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                    Text("Control path")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }

                Picker("Control path", selection: $store.preference) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        Text(medium.pickerTitle).tag(medium)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.orbGlow4)

                Text(store.preference == .automatic
                     ? "App picks MQTT, LAN, or BLE automatically."
                     : "Testing mode — commands always use \(store.preference.shortTitle).")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.appTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.orbGlow4)
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
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
