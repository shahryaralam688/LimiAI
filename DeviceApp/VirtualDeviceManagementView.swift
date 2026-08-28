//
//  VirtualDeviceManagementView.swift
//  LIMI AI Device
//
//  Soft UI view for cloud virtual device groups and local device toggles.
//

import SwiftUI
import UIKit

struct VirtualDeviceManagementView: View {
    @ObservedObject private var store = VirtualDeviceStore.shared
    let items: [DeviceHomeUIPreviewItem]
    var onToggle: (String) -> Void
    var onDismiss: (() -> Void)? = nil

    private var hasCloudGroups: Bool { !store.remoteGroups.isEmpty }

    private var relevantCloudGroups: [VirtualDeviceRemotePayload] {
        let configured = Set(
            items.map { LimiDeviceNaming.normalizedHardwareId($0.id) }.filter { !$0.isEmpty }
        )
        guard !configured.isEmpty else { return [] }
        return store.remoteGroups.filter { group in
            group.mac_addresses.contains {
                configured.contains(LimiDeviceNaming.normalizedHardwareIdFromMAC($0))
            }
        }
    }

    private var hasLocalState: Bool {
        !store.virtualDeviceID.isEmpty || !store.enabledHardwareIds.isEmpty
    }

    var body: some View {
        DeviceNeumorphicScreen {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Virtual Devices",
                        subtitle: "Cloud groups and local enable toggles"
                    )
                    .padding(.top, 8)

                    if !hasCloudGroups && !hasLocalState {
                        DeviceNeumorphicStatusCard(
                            title: "No Virtual Devices Yet",
                            message: "Sign in and pull to refresh, or enable a LIMI device from Connected Devices to create a local group.",
                            systemImage: "link.circle"
                        )
                    } else {
                        syncCard
                        if hasCloudGroups {
                            cloudGroupsCard
                        }
                        if !items.isEmpty {
                            localDevicesCard
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await store.refreshFromBackend(force: true)
            }
        }
        .navigationTitle("Virtual Devices")
        .navigationBarTitleDisplayMode(.inline)
        .deviceNeumorphicNavigationChrome()
        .task {
            await store.refreshFromBackend(force: false)
        }
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .foregroundStyle(HomeUI1Color.accentGreen)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if let firstId = store.remoteGroups.first?.virtual_device_id, !firstId.isEmpty {
                        Button {
                            UIPasteboard.general.string = firstId
                            DeviceAppGuidance.successNotification()
                        } label: {
                            Label("Copy Cloud ID", systemImage: "doc.on.doc")
                        }
                    }
                    Button {
                        Task { await store.syncNow() }
                    } label: {
                        Label("Reload From Cloud", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(HomeUI1Color.accentGreen)
                }
                .accessibilityLabel("Virtual device actions")
            }
        }
    }

    private var syncCard: some View {
        HomeUI1ControlSectionCard(
            title: "Cloud Sync",
            footer: "Pull down to load this account’s virtual devices from the cloud."
        ) {
            if store.isSyncing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(HomeUI1Color.accentGreen)
                    Text("Syncing…")
                        .font(HomeUI1Type.caption(13))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
            } else {
                if let synced = store.lastSyncedAt {
                    Text("Last synced \(synced.formatted(.relative(presentation: .named)))")
                        .font(HomeUI1Type.caption(13))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
                if let message = store.lastSyncMessage {
                    Text(message)
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
            }
        }
    }

    private var cloudGroupsCard: some View {
        HomeUI1ControlSectionCard(
            title: "\(store.remoteGroups.count) virtual device(s)",
            footer: relevantCloudGroups.isEmpty
                ? "None of these cloud groups include a hub configured on this phone yet."
                : "\(relevantCloudGroups.count) include a hub configured on this phone."
        ) {
            VStack(spacing: 10) {
                ForEach(store.remoteGroups, id: \.virtual_device_id) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.virtual_device_id)
                            .font(HomeUI1Type.caption(12))
                            .foregroundStyle(HomeUI1Color.accentGreen)
                            .monospaced()
                        Text("\(group.mac_addresses.count) hub(s)")
                            .font(HomeUI1Type.caption(12))
                            .foregroundStyle(HomeUI1Color.textSecondary)
                        Text(
                            group.mac_addresses.prefix(3).joined(separator: ", ")
                                + (group.mac_addresses.count > 3 ? "…" : "")
                        )
                        .font(HomeUI1Type.caption(11))
                        .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.8))
                        .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.canvas)
                }
            }
        }
    }

    private var localDevicesCard: some View {
        HomeUI1ControlSectionCard(
            title: "This phone",
            footer: "\(items.filter(\.isPowerOn).count) enabled. Toggle On → POST to cloud with Bearer token."
        ) {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(HomeUI1Type.body(15))
                                .foregroundStyle(HomeUI1Color.textPrimary)
                            Text(item.subtitle.isEmpty ? "Offline" : item.subtitle)
                                .font(HomeUI1Type.caption(12))
                                .foregroundStyle(HomeUI1Color.textSecondary)
                        }
                        Spacer()
                        Toggle(
                            item.isPowerOn ? "Enabled" : "Disabled",
                            isOn: Binding(
                                get: { item.isPowerOn },
                                set: { _ in
                                    DeviceAppGuidance.lightImpact()
                                    onToggle(item.id)
                                }
                            )
                        )
                        .labelsHidden()
                        .tint(HomeUI1Color.accentGreen)
                    }
                    .padding(12)
                    .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.surfaceRaised)
                }
            }
        }
    }
}
