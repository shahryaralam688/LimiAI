//
//  DeviceConfiguredConnectedView.swift
//  LIMI AI Device
//
//  Soft UI list of devices this phone has configured that are currently online.
//

import SwiftUI

struct DeviceConfiguredConnectedView: View {
    let items: [DeviceHomeUIPreviewItem]
    let managementItems: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onCreateVirtualDevice: (([String]) -> Void)? = nil
    var onDismiss: () -> Void

    @ObservedObject private var virtualDeviceStore = VirtualDeviceStore.shared

    var body: some View {
        DeviceNeumorphicScreen {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Connected Devices",
                        subtitle: items.isEmpty
                            ? "Only hubs set up on this phone appear here when online"
                            : "\(items.count) connected · Soft UI"
                    )
                    .padding(.top, 8)

                    virtualDeviceCard

                    if items.isEmpty {
                        DeviceNeumorphicStatusCard(
                            title: "No Connected Devices",
                            message: "Only LIMI devices you’ve set up on this phone appear here when they’re online.",
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                configuredDeviceRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await virtualDeviceStore.syncNow()
            }
        }
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
        .deviceNeumorphicNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onDismiss() }
                    .foregroundStyle(HomeUI1Color.accentGreen)
            }
        }
    }

    private var virtualDeviceCard: some View {
        NavigationLink {
            VirtualDeviceManagementView(
                items: managementItems,
                onToggle: onToggle,
                onCreateVirtualDevice: onCreateVirtualDevice
            )
        } label: {
            DeviceNeumorphicListRow(
                title: "Virtual Device",
                subtitle: virtualDeviceSubtitle,
                systemImage: "link.circle.fill",
                isAccent: true,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var virtualDeviceSubtitle: String {
        if virtualDeviceStore.virtualDeviceID.isEmpty {
            return "Enable a hub below to create ID and save to cloud"
        }
        let count = virtualDeviceStore.enabledHardwareIds.count
        return "\(virtualDeviceStore.virtualDeviceID) · \(count) enabled"
    }

    @ViewBuilder
    private func configuredDeviceRow(_ item: DeviceHomeUIPreviewItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                DeviceAppGuidance.lightImpact()
                onOpen(item.id)
            } label: {
                DeviceNeumorphicListRow(
                    title: item.name,
                    subtitle: [
                        item.subtitle.isEmpty ? "Online" : item.subtitle,
                        item.isPowerOn ? "Enabled" : "Disabled"
                    ].joined(separator: " · "),
                    systemImage: item.isPowerOn ? "lightbulb.led.fill" : "lightbulb.led",
                    isAccent: item.isPowerOn,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Toggle(
                    item.isPowerOn ? "Enable" : "Disable",
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
                .accessibilityLabel(item.isPowerOn ? "Disable \(item.name)" : "Enable \(item.name)")

                Text(item.isPowerOn ? "On" : "Off")
                    .font(HomeUI1Type.caption(11))
                    .foregroundStyle(
                        item.isPowerOn ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary
                    )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.nav, fill: HomeUI1Color.surface)
        }
    }
}
