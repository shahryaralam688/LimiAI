//
//  ConfiguredDeviceRemoval.swift
//  LIMI AI Device
//
//  Hides a configured device from the current signed-in account on this phone.
//  Shared phone setup (BLE map, remembered devices) stays intact for other accounts.
//

import Foundation
import SwiftData

/// Per-account hide from Home — does not erase another user's view on the same phone.
@MainActor
enum ConfiguredDeviceRemoval {
    static func removeFromAppStore(
        hardwareId: String,
        blePeripheralUUID: String?,
        modelContext: ModelContext
    ) {
        let key = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !key.isEmpty else { return }

        LocallyRemovedDeviceStore.shared.markRemoved(key)

        if VirtualDeviceStore.shared.isEnabled(hardwareId: key) {
            VirtualDeviceStore.shared.setEnabled(false, hardwareId: key)
        }

        DeviceConsole.log(.config, "hidden for current account id=\(key)")
    }

    /// Master device row — hide every member hub for this account only.
    static func removeVirtualMasterFromAppStore(
        memberHardwareIds: [String],
        modelContext: ModelContext
    ) {
        for raw in memberHardwareIds {
            let key = LimiDeviceNaming.normalizedHardwareId(raw)
            guard !key.isEmpty else { continue }
            removeFromAppStore(
                hardwareId: key,
                blePeripheralUUID: ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: key),
                modelContext: modelContext
            )
        }
    }
}
