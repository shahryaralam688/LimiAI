//
//  SessionRememberedDeviceWipe.swift
//  LIMI AI Device
//
//  Remembered hubs live in SwiftData (phone-global). Home is often not
//  mounted during logout (Profile tab), so deletion must not depend on Home.
//

import SwiftData

enum SessionRememberedDeviceWipe {
    @MainActor
    static func deleteAll(in context: ModelContext) {
        let descriptor = FetchDescriptor<RememberedLimiDevice>()
        guard let rows = try? context.fetch(descriptor), !rows.isEmpty else { return }
        for row in rows {
            context.delete(row)
        }
        try? context.save()
        DeviceConsole.log(.config, "cleared \(rows.count) remembered device(s) (session change)")
    }
}
