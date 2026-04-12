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
    @State private var selectedChannel: ChannelInfo? = nil
    
    struct ChannelInfo: Identifiable {
        let id: Int
        let type: String
        let position: Int
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Device info header
                VStack(spacing: 8) {
                    Text("Channel " + String(device.chennalCount))
                        .font(.custom("Poppins-SemiBold", size: 20))
                        .foregroundColor(.themeWhite)
                    
                    Text("Select a channel to control")
                        .font(.custom("Poppins-Regular", size: 14))
                        .foregroundColor(.themeWhite.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Text("Device ID:")
                            .font(.caption)
                            .foregroundColor(.themeWhite.opacity(0.5))
                        Text(device.chennalMac)
                            .font(.caption)
                            .foregroundColor(.themeWhite.opacity(0.7))
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
                                    id: index,
                                    type: channelType,
                                    position: index + 1
                                )
                            }) {
                                HStack(spacing: 16) {
                                    // Channel number indicator
                                    ZStack {
                                        Circle()
                                            .fill(channelType == "CCT" ? Color.orange.opacity(0.3) : Color.purple.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                        
                                        Text("\(index + 1)")
                                            .font(.custom("Poppins-SemiBold", size: 18))
                                            .foregroundColor(.themeWhite)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Channel \(index + 1)")
                                            .font(.custom("Poppins-Medium", size: 16))
                                            .foregroundColor(.themeWhite)
                                        
                                        Text(channelType == "CCT" ? "Warm/Cool White" : "RGB Color")
                                            .font(.custom("Poppins-Regular", size: 12))
                                            .foregroundColor(channelType == "CCT" ? Color.orange : Color.purple)
                                    }
                                    
                                    Spacer()
                                    
                                    // Channel type indicator
                                    HStack(spacing: 4) {
                                        Image(systemName: channelType == "CCT" ? "lightbulb.fill" : "paintpalette.fill")
                                            .font(.system(size: 14))
                                        Text(channelType)
                                            .font(.custom("Poppins-Medium", size: 12))
                                    }
                                    .foregroundColor(channelType == "CCT" ? .orange : .purple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(channelType == "CCT" ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2))
                                    )
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.themeWhite.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.appSurfaceSecondaryAlt)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.themeWhite.opacity(0.1), lineWidth: 1)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Close")
                                .font(.custom("Poppins-Medium", size: 14))
                        }
                        .foregroundColor(.themeWhite)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Device Channels")
                        .font(.custom("Poppins-SemiBold", size: 17))
                        .foregroundColor(.themeWhite)
                }
            }
            .sheet(item: $selectedChannel) { channel in
                if channel.type == "CCT" {
                    CCTLEDView(
                        chennalMac: device.chennalMac,
                        chennelPosition: channel.position
                    )
                } else {
                    WLEDView(
                        chennalMac: device.chennalMac,
                        chennelPosition: channel.position
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
