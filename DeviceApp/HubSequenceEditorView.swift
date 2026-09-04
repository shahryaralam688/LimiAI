//
//  HubSequenceEditorView.swift
//  LIMI AI Device
//
//  Home → hold hub → Sequence. Drag to reorder member hubs. Toggle
//  sends MQTT power to that MAC and includes/excludes it from pattern `devices`.
//

import SwiftUI

struct HubSequenceTarget: Identifiable, Equatable {
    let id: String
    let displayName: String
    let memberHardwareIds: [String]
}

struct HubSequenceEditorView: View {
    let target: HubSequenceTarget
    var nameForHardwareId: (String) -> String

    @ObservedObject private var store = VirtualDeviceSequenceStore.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var items: [VirtualDeviceSequenceItem] = []

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }

    var body: some View {
        Group {
            if usesHomeUI1 {
                HomeUI1ControlScreenBackground()
                    .ignoresSafeArea()
                    .overlay { listBody }
            } else {
                listBody
            }
        }
        .navigationTitle("Sequence")
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(usesHomeUI1 ? HomeUI1Color.accentGreen : DeviceTheme.accent)
            }
        }
        .onAppear { reload() }
    }

    private var listBody: some View {
        List {
            Section {
                ForEach($items) { $item in
                    row($item)
                }
                .onMove(perform: move)
            } footer: {
                Text("On/Off sends power to that hub by MAC. Off hubs also stay out of the pattern list.")
                    .foregroundStyle(usesHomeUI1 ? HomeUI1Color.textSecondary : Color.secondary)
            }
        }
        .scrollContentBackground(usesHomeUI1 ? .hidden : .automatic)
        .environment(\.editMode, .constant(.active))
    }

    private func row(_ item: Binding<VirtualDeviceSequenceItem>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(nameForHardwareId(item.wrappedValue.hardwareId))
                    .font(usesHomeUI1 ? HomeUI1Type.body(16) : .body.weight(.medium))
                    .foregroundStyle(usesHomeUI1 ? HomeUI1Color.textPrimary : Color.primary)
                Text(item.wrappedValue.hardwareId)
                    .font(.caption2.monospaced())
                    .foregroundStyle(usesHomeUI1 ? HomeUI1Color.textSecondary : Color.secondary)
            }
            Spacer(minLength: 8)
            Toggle("On", isOn: Binding(
                get: { item.wrappedValue.isEnabled },
                set: { newValue in
                    item.wrappedValue.isEnabled = newValue
                    persist()
                    sendPower(hardwareId: item.wrappedValue.hardwareId, on: newValue)
                }
            ))
                .labelsHidden()
                .tint(usesHomeUI1 ? HomeUI1Color.accentGreen : DeviceTheme.accent)
        }
        .listRowBackground(
            usesHomeUI1 ? HomeUI1Color.surface.opacity(0.72) : Color(uiColor: .secondarySystemGroupedBackground)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nameForHardwareId(item.wrappedValue.hardwareId)), \(item.wrappedValue.isEnabled ? "On" : "Off")")
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persist()
        DeviceAppGuidance.lightImpact()
    }

    private func reload() {
        items = store.orderedItems(
            virtualDeviceId: target.id,
            members: target.memberHardwareIds
        )
    }

    private func persist() {
        store.replaceItems(virtualDeviceId: target.id, items: items)
    }

    /// Same path as Home card power: MQTT `light_controll` for that MAC.
    private func sendPower(hardwareId: String, on: Bool) {
        let mac = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard mac.count == 12, mac.allSatisfy(\.isHexDigit) else { return }

        DevicePowerMemoryStore.shared.setOn(on, for: mac)
        DeviceAppGuidance.lightImpact()
        LightControllingSocket.shared.connect()

        let command: LimiCommand = on
            ? .cct(channel: 1, brightness: 70, ww: 100, cw: 40)
            : .power(channel: 1, on: false)

        Task { @MainActor in
            do {
                try await LimiTransport.shared.sendCommand(command, for: mac)
                DeviceConsole.log(.home, "sequence power \(on ? "ON" : "OFF") → \(mac)")
                DeviceAppGuidance.successNotification()
            } catch {
                if let index = items.firstIndex(where: { $0.hardwareId == mac }) {
                    items[index].isEnabled = !on
                    persist()
                }
                DevicePowerMemoryStore.shared.setOn(!on, for: mac)
                DeviceConsole.log(.home, "sequence power failed \(mac): \(error.localizedDescription)")
                DeviceAppGuidance.warningNotification()
            }
        }
    }
}
