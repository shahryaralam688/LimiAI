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
    /// Create a brand-new virtual device from the given item ids (online, not yet grouped).
    var onCreateVirtualDevice: (([String]) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var showCreateSheet = false

    private var hasCloudGroups: Bool { !store.remoteGroups.isEmpty }

    /// Online devices on this phone that are not already part of a virtual device.
    private var creatableItems: [DeviceHomeUIPreviewItem] {
        items.filter { $0.isOnline && !$0.isPowerOn }
    }

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
                        if onCreateVirtualDevice != nil {
                            createNewCard
                        }
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
        .sheet(isPresented: $showCreateSheet) {
            CreateVirtualDeviceSheet(
                candidates: creatableItems,
                onCreate: { selectedIds in
                    onCreateVirtualDevice?(selectedIds)
                    showCreateSheet = false
                },
                onCancel: { showCreateSheet = false }
            )
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

    private var createNewCard: some View {
        HomeUI1ControlSectionCard(
            title: "Create New Virtual Device",
            footer: creatableItems.isEmpty
                ? "No online devices available to group. Only online devices that aren’t already in a virtual device can be added."
                : "\(creatableItems.count) online device(s) can be grouped into a new virtual device."
        ) {
            Button {
                DeviceAppGuidance.lightImpact()
                showCreateSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Create New Virtual Device")
                        .font(HomeUI1Type.body(15))
                    Spacer()
                }
                .foregroundStyle(
                    creatableItems.isEmpty ? HomeUI1Color.textSecondary : HomeUI1Color.accentGreen
                )
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.surface)
            }
            .buttonStyle(.plain)
            .disabled(creatableItems.isEmpty)
            .opacity(creatableItems.isEmpty ? 0.55 : 1)
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

// MARK: - Create new virtual device (pick online, ungrouped devices)

private struct CreateVirtualDeviceSheet: View {
    let candidates: [DeviceHomeUIPreviewItem]
    var onCreate: ([String]) -> Void
    var onCancel: () -> Void

    @State private var selectedIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Devices Available",
                        systemImage: "link.badge.plus",
                        description: Text("Only online devices that aren’t already in a virtual device can be grouped.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(candidates) { item in
                                Button {
                                    toggle(item.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIds.contains(item.id) ? Color.green : Color.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .foregroundStyle(.primary)
                                            Text(item.subtitle.isEmpty ? "Online" : item.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Online devices")
                        } footer: {
                            Text("Select the devices to combine into one new virtual device.")
                        }
                    }
                }
            }
            .navigationTitle("New Virtual Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(Array(selectedIds))
                    }
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}
