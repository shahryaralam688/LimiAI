//
//  HomeUI5HomeView.swift
//  LIMI AI Device — Home UI 5 Minimal large tiles
//

import SwiftUI

struct DeviceHomeUIVariantFiveView: View {
    let userName: String
    let greeting: String
    let items: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onAdd: () -> Void
    var onConnectedDevices: (() -> Void)? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(greeting)
                        .font(HomeUI5Type.caption)
                        .foregroundStyle(HomeUI5Color.secondary)
                    Text(userName)
                        .font(HomeUI5Type.hero)
                        .foregroundStyle(HomeUI5Color.text)
                    Text("Home UI 5 · Minimal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HomeUI5Color.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                HStack(spacing: 12) {
                    if onConnectedDevices != nil {
                        Button {
                            DeviceAppGuidance.lightImpact()
                            onConnectedDevices?()
                        } label: {
                            Label("Connected", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(HomeUI5Color.accent)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .stroke(HomeUI5Color.accent, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onAdd) {
                        Label("Add device", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(HomeUI5Color.accent))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(item.name)
                                .font(HomeUI5Type.tileTitle)
                                .foregroundStyle(HomeUI5Color.text)
                            Spacer()
                            if item.isOnline {
                                Toggle("", isOn: Binding(
                                    get: { item.isPowerOn },
                                    set: { _ in onToggle(item.id) }
                                ))
                                .labelsHidden()
                                .tint(HomeUI5Color.accent)
                            } else {
                                Text("Offline")
                                    .font(HomeUI5Type.caption)
                                    .foregroundStyle(HomeUI5Color.secondary)
                            }
                        }
                        Text(item.subtitle)
                            .font(HomeUI5Type.caption)
                            .foregroundStyle(HomeUI5Color.secondary)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(HomeUI5Color.accent.opacity(item.isPowerOn && item.isOnline ? 0.18 : 0.06))
                            .frame(height: 120)
                            .overlay {
                                Image(systemName: item.isOnline ? "lightbulb.max.fill" : "poweroff")
                                    .font(.system(size: 44, weight: .ultraLight))
                                    .foregroundStyle(HomeUI5Color.accent.opacity(item.isOnline ? 1 : 0.45))
                            }
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: HomeUI5Radius.tile, style: .continuous)
                            .fill(HomeUI5Color.tile)
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: HomeUI5Radius.tile, style: .continuous))
                    .onTapGesture {
                        onOpen(item.id)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 24)
            }
        }
        .background(HomeUI5Color.canvas.ignoresSafeArea(edges: .top))
    }
}
