//
//  HomeUI4HomeView.swift
//  LIMI AI Device — Home UI 4 2-column grid
//

import SwiftUI

struct DeviceHomeUIVariantFourView: View {
    let userName: String
    let items: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onAdd: () -> Void
    var onConnectedDevices: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Home UI 4")
                            .font(HomeUI4Type.title)
                            .foregroundStyle(HomeUI4Color.text)
                        Text("Hi \(userName) · Grid layout")
                            .font(HomeUI4Type.caption)
                            .foregroundStyle(HomeUI4Color.secondary)
                    }
                    Spacer()
                    if onConnectedDevices != nil {
                        Button {
                            DeviceAppGuidance.lightImpact()
                            onConnectedDevices?()
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(HomeUI4Color.accent)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(HomeUI4Color.card))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Connected Devices")
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(HomeUI4Color.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: item.isOnline ? "lightbulb.led.fill" : "poweroff")
                                    .foregroundStyle(item.isOnline ? HomeUI4Color.accent : HomeUI4Color.secondary)
                                Spacer()
                                Text(item.isOnline ? "Online" : "Offline")
                                    .font(HomeUI4Type.caption)
                                    .foregroundStyle(item.isOnline ? HomeUI4Color.accent : HomeUI4Color.secondary)
                            }
                            Text(item.name)
                                .font(HomeUI4Type.cardTitle)
                                .foregroundStyle(HomeUI4Color.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if item.isOnline {
                                Toggle(item.isPowerOn ? "On" : "Off", isOn: Binding(
                                    get: { item.isPowerOn },
                                    set: { _ in onToggle(item.id) }
                                ))
                                .tint(HomeUI4Color.accent)
                            } else {
                                Text("Powered off")
                                    .font(HomeUI4Type.caption)
                                    .foregroundStyle(HomeUI4Color.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background {
                            RoundedRectangle(cornerRadius: HomeUI4Radius.card, style: .continuous)
                                .fill(HomeUI4Color.card)
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: HomeUI4Radius.card, style: .continuous))
                        .onTapGesture {
                            onOpen(item.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(HomeUI4Color.canvas.ignoresSafeArea(edges: .top))
    }
}
