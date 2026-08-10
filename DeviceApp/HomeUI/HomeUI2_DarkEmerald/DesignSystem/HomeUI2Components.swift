//
//  HomeUI2Components.swift
//  LIMI AI Device — Home UI 2
//

import SwiftUI

struct HomeUI2PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HomeUI2Type.body(15))
                .foregroundStyle(HomeUI2Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule(style: .continuous)
                        .fill(HomeUI2Color.primaryDeep)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(HomeUI2Color.focus.opacity(0.35), lineWidth: 1.5)
                }
                .shadow(color: HomeUI2Color.focus.opacity(0.2), radius: 8)
        }
        .buttonStyle(.plain)
    }
}

struct HomeUI2DeviceRow: View {
    let item: DeviceHomeUIPreviewItem
    var onOpen: () -> Void
    var onToggle: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HomeUI2Color.primary.opacity(item.isOnline ? 0.28 : 0.1))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "lightbulb.led.fill")
                            .foregroundStyle(HomeUI2Color.focus)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(HomeUI2Type.body(16))
                        .foregroundStyle(HomeUI2Color.textPrimary)
                    Text(item.subtitle)
                        .font(HomeUI2Type.caption())
                        .foregroundStyle(HomeUI2Color.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { item.isPowerOn },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(HomeUI2Color.primary)
                .disabled(!item.isOnline)
            }
            .padding(16)
            .homeUI2Raised(cornerRadius: HomeUI2Radius.lg, fill: HomeUI2Color.surfaceRaised)
        }
        .buttonStyle(.plain)
        .opacity(item.isOnline ? 1 : 0.55)
    }
}
