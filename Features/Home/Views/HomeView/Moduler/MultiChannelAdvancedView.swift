import SwiftUI

struct MultiChannelAdvancedView: View {
    let device: WifiDevice

    @Environment(\.dismiss) private var dismiss
    @State private var showChannelSelection = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let webHeight = min(max(geo.size.height * 0.42, 280), 480)
                ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(device.deviceName)
                            .font(LimiTypography.title)
                            .foregroundColor(.appTextPrimary)

                        Text("Advanced device control")
                            .font(LimiTypography.callout)
                            .foregroundColor(.appTextSecondary)

                        HStack(spacing: 6) {
                            Text("Device ID:")
                                .font(LimiTypography.caption)
                                .foregroundColor(.appTextPrimary.opacity(0.5))
                            Text(device.chennalMac)
                                .font(LimiTypography.caption)
                                .foregroundColor(.appTextPrimary.opacity(0.75))
                        }
                    }
                    .padding(.top, 12)

                    channelSelectorCard

                    Group {
                        if let token = AuthManager.shared.getToken(),
                           let url = URL(string: AppURLs.Web.configuratorV2(token: token)) {
                            LimiWebViewCon(url: url, macAddress: device.chennalMac)
                                .frame(height: webHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else if let url = URL(string: AppURLs.Web.configuratorV2()) {
                            LimiWebViewCon(url: url, macAddress: device.chennalMac)
                                .frame(height: webHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            unavailableState
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 16) + 12)
            }
            .scrollIndicators(.visible)
            .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.appSurfaceDeep.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appSurfaceDeep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LimiCloseToolbarButton { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    Text("Advanced")
                        .font(LimiTypography.button)
                        .foregroundColor(.appTextPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Channels") {
                        showChannelSelection = true
                    }
                    .font(LimiTypography.callout)
                    .foregroundColor(.brandAction)
                }
            }
            .sheet(isPresented: $showChannelSelection) {
                ChannelSelectionView(device: device)
                    .deviceControlSheetStyle()
            }
        }
    }

    private var channelSelectorCard: some View {
        Button {
            showChannelSelection = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.brandHighlight.opacity(0.2))
                        .frame(width: 46, height: 46)

                    Image(systemName: "slider.horizontal.3")
                        .font(LimiTypography.button)
                        .foregroundColor(.brandAction)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Channels")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)

                    Text("\(device.chennalCount) channels available")
                        .font(LimiTypography.caption)
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appSurfaceSecondaryAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appGlassFillStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(LimiTypography.title2)
                .foregroundColor(.appTextSecondary)

            Text("Advanced view is unavailable right now.")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurfacePrimary)
        )
    }
}

struct MultiChannelAdvancedView_Previews: PreviewProvider {
    static var previews: some View {
        MultiChannelAdvancedView(
            device: WifiDevice(
                id: "test-device",
                uuid: "test-uuid",
                chennalMac: "80B54EE8B228",
                chennalCount: 4,
                channelTypes: ["CCT", "RGB", "CCT", "RGB"],
                deviceName: "4 CH-HUB",
                isOnline: true
            )
        )
    }
}
