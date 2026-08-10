//
//  ChannelSelectionView.swift
//  Limi
//
//  Created for multi-channel device control
//

import SwiftUI

struct ChannelSelectionView: View {
    let device: WifiDevice
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pendantTypeStore = DevicePendantTypeStore.shared
    @State private var selectedChannel: ChannelInfo? = nil
    
    struct ChannelInfo: Identifiable {
        let id: String
        let type: String
        let position: Int
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Device info header
                VStack(spacing: 8) {
                    Text("Channel " + String(device.chennalCount))
                        .font(LimiTypography.title3)
                        .foregroundColor(.appTextPrimary)
                    
                    Text("Select a channel to control")
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextSecondary)
                    
                    HStack(spacing: 4) {
                        Text("Device ID:")
                            .font(LimiTypography.caption)
                            .foregroundColor(.appTextPrimary.opacity(0.5))
                        Text(device.chennalMac)
                            .font(LimiTypography.caption)
                            .foregroundColor(.appTextPrimary.opacity(0.7))
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Channel list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<device.channelTypes.count, id: \.self) { index in
                            let channelType = device.channelTypes[index]
                            Button(action: {
                                selectedChannel = ChannelInfo(
                                    id: "\(device.chennalMac)-\(channelType)-\(index + 1)",
                                    type: channelType,
                                    position: index + 1
                                )
                            }) {
                                HStack(spacing: 16) {
                                    // Channel number indicator
                                    ZStack {
                                        Circle()
                                            .fill(channelType == "CCT" ? Color.appOrange.opacity(0.3) : Color.appPurple.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                        
                                        Text("\(index + 1)")
                                            .font(LimiTypography.button)
                                            .foregroundColor(.appTextPrimary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Channel \(index + 1)")
                                            .font(LimiTypography.headline)
                                            .foregroundColor(.appTextPrimary)
                                        
                                        Text(channelType == "CCT" ? "Warm/Cool White" : "RGB Color")
                                            .font(LimiTypography.caption)
                                            .foregroundColor(channelType == "CCT" ? Color.appOrange : Color.appPurple)
                                    }
                                    
                                    Spacer()
                                    
                                    // Channel type indicator
                                    HStack(spacing: 4) {
                                        Image(systemName: channelType == "CCT" ? "lightbulb.fill" : "paintpalette.fill")
                                            .font(LimiTypography.subheadline)
                                        Text(channelType)
                                            .font(LimiTypography.caption)
                                    }
                                    .foregroundColor(channelType == "CCT" ? Color.appOrange : Color.appPurple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(channelType == "CCT" ? Color.appOrange.opacity(0.2) : Color.appPurple.opacity(0.2))
                                    )
                                    
                                    Image(systemName: "chevron.right")
                                        .font(LimiTypography.callout)
                                        .foregroundColor(.appTextPrimary.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.appSurfaceSecondaryAlt)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appGlassFillStrong, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .background(Color.appSurfaceDeep.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LimiCloseToolbarButton { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    Text("Device Channels")
                        .font(LimiTypography.button)
                        .foregroundColor(.appTextPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Advanced")
                            .font(LimiTypography.callout)
                            .foregroundColor(.brandAction)
                    }
                }
            }
            .sheet(item: $selectedChannel) { channel in
                DeviceControlNavigationShell(
                    title: "Channel \(channel.position)",
                    subtitle: channel.type,
                    onClose: { selectedChannel = nil }
                ) {
                    let pendantModel = PendantModelCatalog.bundledName(forDeviceId: device.chennalMac)
                    let _ = pendantTypeStore.pendantTypesByDeviceId
                    if channel.type == "CCT" {
                        CCTLEDPreviewView(
                            chennalMac: device.chennalMac,
                            chennelPosition: channel.position,
                            bundledName: pendantModel
                        )
                        .id("cct-\(device.chennalMac)-\(channel.position)-\(pendantModel)")
                    } else {
                        RGBLEDPreviewView(
                            chennalMac: device.chennalMac,
                            chennelPosition: channel.position,
                            bundledName: pendantModel
                        )
                        .id("rgb-\(device.chennalMac)-\(channel.position)-\(pendantModel)")
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ChannelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChannelSelectionView(
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
