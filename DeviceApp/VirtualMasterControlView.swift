//
//  VirtualMasterControlView.swift
//  LIMI AI Device
//
//  Master Device control — tab between all hubs (virtual_light_control)
//  and each member hub individually.
//

import SwiftUI

struct VirtualMasterControlView: View {
    let virtualDeviceID: String
    let displayName: String
    let memberHardwareIds: [String]
    let memberChannelTypes: [String]

    @ObservedObject private var socket = LightControllingSocket.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared
    @ObservedObject private var bonjour = BonjourServiceBrowser.shared

    @State private var selectedScope: MasterControlScope = .all
    @State private var presenceTick = 0

    private enum MasterControlScope: Hashable {
        case all
        case member(String)
    }

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }

    private var normalizedMembers: [String] {
        memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
    }

    private var scopes: [MasterControlScope] {
        var items: [MasterControlScope] = [.all]
        items.append(contentsOf: normalizedMembers.map { .member($0) })
        return items
    }

    private var showsMemberTabs: Bool { !normalizedMembers.isEmpty }

    private var onlineCounts: (online: Int, total: Int) {
        _ = presenceTick
        return VirtualMasterPresence.cloudOnlineMemberCount(memberHardwareIds: normalizedMembers)
    }

    init(
        virtualDeviceID: String,
        displayName: String,
        memberHardwareIds: [String] = [],
        memberChannelTypes: [String] = []
    ) {
        self.virtualDeviceID = virtualDeviceID
        self.displayName = displayName
        self.memberHardwareIds = memberHardwareIds
        self.memberChannelTypes = memberChannelTypes
    }

    var body: some View {
        ZStack {
            if usesHomeUI1 {
                HomeUI1ControlScreenBackground()
            }

            VStack(spacing: 0) {
                if socket.connectionStatus != .connected {
                    connectionBanner
                }

                if showsMemberTabs {
                    scopeTabBar
                        .padding(.horizontal, usesHomeUI1 ? 16 : 12)
                        .padding(.top, usesHomeUI1 ? 8 : 10)
                        .padding(.bottom, usesHomeUI1 ? 6 : 8)
                }

                controlContent
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
        .onAppear {
            LightControllingSocket.shared.connect()
        }
        .onReceive(DeviceTransportRegistry.shared.presenceChangePublisher) { _ in
            presenceTick &+= 1
        }
        .onReceive(bonjour.$discoveredWiFiDevices) { _ in
            presenceTick &+= 1
        }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        Group {
            if usesHomeUI1 {
                HomeUI1ControlConnectionBanner()
            } else {
                DeviceConnectionBanner()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .padding(.horizontal, usesHomeUI1 ? 16 : 0)
        .padding(.top, usesHomeUI1 ? 10 : 0)
        .padding(.bottom, usesHomeUI1 ? 8 : 0)
    }

    private var scopeTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scopes, id: \.self) { scope in
                    Button {
                        DeviceAppGuidance.lightImpact()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedScope = scope
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(scopeOnlineColor(scope))
                                .frame(width: 7, height: 7)
                            Text(scopeLabel(scope))
                                .font(usesHomeUI1 ? HomeUI1Type.body(13) : .subheadline.weight(.medium))
                                .foregroundStyle(selectedScope == scope ? selectedTabForeground : secondaryTabForeground)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background {
                            if usesHomeUI1 {
                                Capsule()
                                    .fill(selectedScope == scope ? HomeUI1Color.accentGreen.opacity(0.22) : HomeUI1Color.surface.opacity(0.55))
                            } else {
                                Capsule()
                                    .fill(selectedScope == scope ? DeviceTheme.accent.opacity(0.18) : Color.secondary.opacity(0.12))
                            }
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    selectedScope == scope ? tabBorderSelected : tabBorderIdle,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var controlContent: some View {
        switch selectedScope {
        case .all:
            CCTLEDPreviewView(virtualDeviceID: virtualDeviceID)
                .id("virtual-cct-\(virtualDeviceID)")
        case .member(let hardwareId):
            memberControlView(hardwareId: hardwareId)
                .id("member-cct-\(hardwareId)")
        }
    }

    @ViewBuilder
    private func memberControlView(hardwareId: String) -> some View {
        let channelType = channelType(for: hardwareId)
        let memberName = memberDisplayName(for: hardwareId)
        let normalizedType = channelType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "RGB" ? "RGB" : "CCT"
        let pendantModel = PendantModelCatalog.bundledName(forDeviceId: hardwareId)
        let online = memberIsOnline(hardwareId)

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(online ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                Text(online ? "Online" : "Offline")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(online ? .primary : .secondary)
                Spacer()
                Text(hardwareId)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Group {
                if normalizedType == "RGB" {
                    RGBLEDPreviewView(
                        chennalMac: hardwareId,
                        chennelPosition: 1,
                        bundledName: pendantModel
                    )
                } else {
                    CCTLEDPreviewView(
                        chennalMac: hardwareId,
                        chennelPosition: 1,
                        bundledName: pendantModel
                    )
                }
            }
            .accessibilityLabel("\(memberName) control")
        }
    }

    private func scopeLabel(_ scope: MasterControlScope) -> String {
        switch scope {
        case .all:
            let counts = onlineCounts
            if counts.total == 0 { return "Master" }
            if counts.online == 0 { return "Master · Offline" }
            if counts.online == counts.total { return "Master · Online" }
            return "Master · \(counts.online)/\(counts.total)"
        case .member(let hardwareId):
            let name = memberDisplayName(for: hardwareId)
            return memberIsOnline(hardwareId) ? "\(name) · Online" : "\(name) · Offline"
        }
    }

    private func scopeOnlineColor(_ scope: MasterControlScope) -> Color {
        switch scope {
        case .all:
            let counts = onlineCounts
            if counts.online == 0 { return Color.secondary.opacity(0.45) }
            if counts.online == counts.total { return .green }
            return .orange
        case .member(let hardwareId):
            return memberIsOnline(hardwareId) ? .green : Color.secondary.opacity(0.45)
        }
    }

    private func memberIsOnline(_ hardwareId: String) -> Bool {
        _ = presenceTick
        return VirtualMasterPresence.isMemberCloudOnline(hardwareId: hardwareId)
    }

    private func memberDisplayName(for hardwareId: String) -> String {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        if let match = bonjour.discoveredWiFiDevices.first(where: {
            $0.resolvedHardwareId() == hw
        }), !match.name.isEmpty {
            return match.name
        }
        if let index = normalizedMembers.firstIndex(of: hw) {
            return normalizedMembers.count > 1 ? "Hub \(index + 1)" : "Hub"
        }
        return "Hub"
    }

    private func channelType(for hardwareId: String) -> String {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard let index = normalizedMembers.firstIndex(of: hw) else { return "CCT" }
        if index < memberChannelTypes.count {
            let type = memberChannelTypes[index]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return type == "RGB" ? "RGB" : "CCT"
        }
        return "CCT"
    }

    private var selectedTabForeground: Color {
        usesHomeUI1 ? HomeUI1Color.textPrimary : .primary
    }

    private var secondaryTabForeground: Color {
        usesHomeUI1 ? HomeUI1Color.textSecondary : .secondary
    }

    private var tabBorderSelected: Color {
        usesHomeUI1 ? HomeUI1Color.accentGreen.opacity(0.55) : DeviceTheme.accent.opacity(0.45)
    }

    private var tabBorderIdle: Color {
        usesHomeUI1 ? HomeUI1Color.textSecondary.opacity(0.18) : Color.secondary.opacity(0.2)
    }
}
