//
//  AddDeviceVirtualGroupingBridge.swift
//  LIMI AI Device
//
//  Keeps Add Device scan list in sync with virtual-device membership (DeviceApp only).
//

import Combine
import SwiftUI

@MainActor
enum AddDeviceVirtualGroupingBridge {
    static func sync(into scanViewModel: DemoScanDevicesViewModel) {
        scanViewModel.updateVirtualGrouping(
            groups: VirtualDeviceStore.shared.homeGroupingSpecs(
                relevantHardwareIds: configuredHardwareIdsForScanGrouping()
            )
        )
    }

    /// Best-effort configured hub ids without SwiftData (Add Device flow).
    private static func configuredHardwareIdsForScanGrouping() -> Set<String> {
        var ids = Set<String>()
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            let key = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            if !key.isEmpty { ids.insert(key) }
        }
        for member in VirtualDeviceStore.shared.enabledHardwareIds {
            let key = LimiDeviceNaming.normalizedHardwareId(member)
            if !key.isEmpty { ids.insert(key) }
        }
        return ids
    }

    static func observeStore(
        scanViewModel: DemoScanDevicesViewModel,
        store: VirtualDeviceStore = .shared,
        cancellables: inout Set<AnyCancellable>
    ) {
        store.$remoteGroups
            .combineLatest(store.$enabledHardwareIds, store.$virtualDeviceID)
            .receive(on: DispatchQueue.main)
            .sink { _, _, _ in
                scanViewModel.updateVirtualGrouping(
                    groups: store.homeGroupingSpecs(
                        relevantHardwareIds: configuredHardwareIdsForScanGrouping()
                    )
                )
            }
            .store(in: &cancellables)
    }
}
