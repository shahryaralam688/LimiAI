//
//  HubChannelPatternBar.swift
//  LIMI AI Device
//
//  Channel effect patterns — only on the Hub (All) control tab.
//  Collapsible: tap header to minimize / maximize.
//  Individual member control screens must not show this.
//

import SwiftUI

struct HubChannelPatternBar: View {
    let virtualDeviceID: String
    let memberHardwareIds: [String]
    let pendantCount: Int
    var usesHomeUI1: Bool = true

    @ObservedObject private var sequenceStore = VirtualDeviceSequenceStore.shared
    @State private var isExpanded = false
    @State private var selectedName: ChannelEffectPatternName?

    private var patterns: [ChannelEffectPattern] {
        ChannelEffectPatternCatalog.masterDefaults(hubCount: max(pendantCount, 1))
    }

    private var headerTitle: String {
        if let selectedName {
            return "Patterns · \(selectedName.displayTitle)"
        }
        return "Patterns"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            Button {
                DeviceAppGuidance.lightImpact()
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(headerTitle)
                        .font(usesHomeUI1 ? HomeUI1Type.body(13) : .subheadline.weight(.semibold))
                        .foregroundStyle(usesHomeUI1 ? HomeUI1Color.textSecondary : Color.secondary)

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(usesHomeUI1 ? HomeUI1Color.textSecondary : Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide patterns" : "Show patterns")
            .accessibilityHint("Double tap to \(isExpanded ? "minimize" : "maximize") pattern list")

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(patterns, id: \.name) { pattern in
                            patternChip(pattern)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, usesHomeUI1 ? 16 : 12)
        .padding(.vertical, 10)
    }

    private func patternChip(_ pattern: ChannelEffectPattern) -> some View {
        let isSelected = selectedName == pattern.name
        return Button {
            DeviceAppGuidance.lightImpact()
            selectedName = pattern.name
            send(pattern)
        } label: {
            Text(pattern.name.displayTitle)
                .font(usesHomeUI1 ? HomeUI1Type.body(13) : .subheadline.weight(.medium))
                .foregroundStyle(
                    isSelected
                        ? (usesHomeUI1 ? HomeUI1Color.textPrimary : Color.primary)
                        : (usesHomeUI1 ? HomeUI1Color.textSecondary : Color.secondary)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    if usesHomeUI1 {
                        Capsule()
                            .fill(
                                isSelected
                                    ? HomeUI1Color.accentGreen.opacity(0.22)
                                    : HomeUI1Color.surface.opacity(0.55)
                            )
                    } else {
                        Capsule()
                            .fill(
                                isSelected
                                    ? DeviceTheme.accent.opacity(0.18)
                                    : Color.secondary.opacity(0.12)
                            )
                    }
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? (usesHomeUI1
                                    ? HomeUI1Color.accentGreen.opacity(0.55)
                                    : DeviceTheme.accent.opacity(0.45))
                                : (usesHomeUI1
                                    ? HomeUI1Color.textSecondary.opacity(0.18)
                                    : Color.secondary.opacity(0.2)),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pattern \(pattern.name.displayTitle)")
    }

    private func send(_ pattern: ChannelEffectPattern) {
        let deviceIds = sequenceStore.patternDeviceIds(
            virtualDeviceId: virtualDeviceID,
            members: memberHardwareIds
        )
        DeviceConsole.log(
            .socket,
            "hub pattern → \(pattern.name.rawValue) vd=\(virtualDeviceID) seq=\(deviceIds.joined(separator: ","))"
        )
        LightControllingSocket.shared.connect()
        LightControllingSocket.shared.sendHubPatternControl(
            virtualDeviceId: virtualDeviceID,
            patternName: pattern.name.rawValue,
            deviceIds: deviceIds
        )
    }
}
