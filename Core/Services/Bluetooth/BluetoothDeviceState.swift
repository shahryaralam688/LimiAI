//
//  BluetoothDeviceState.swift
//  Limi
//

import SwiftUI
import Combine

struct DeviceInfo: Equatable {
    let name: String
    let id: String
    var receivedBytes: [UInt8] = []
    
    var isNormalMode: Bool {
        return receivedBytes.first == 91
    }
    
    var isDeveloperMode: Bool {
        return receivedBytes.first == 90
    }
}

// MARK: - Global Selected Devices storage (name + uuid), persisted to UserDefaults
struct SelectedDevice: Codable, Equatable, Identifiable {
    var id: String { uuid }
    let name: String
    let uuid: String
}

class SelectedDevicesStorage: ObservableObject {
    static let shared = SelectedDevicesStorage()
    // Expose keys so views can use @AppStorage
    static let listKey = "selected_devices_list"
    static let lastNameKey = "selected_device_last_name"
    static let lastUUIDKey = "selected_device_last_uuid"
    private let listKey = SelectedDevicesStorage.listKey
    private let lastNameKey = SelectedDevicesStorage.lastNameKey
    private let lastUUIDKey = SelectedDevicesStorage.lastUUIDKey

    @Published var items: [SelectedDevice] = []

    private init() {
        load()
    }

    func addOrUpdate(name: String, uuid: String) {
        let new = SelectedDevice(name: name, uuid: uuid)
        if let idx = items.firstIndex(where: { $0.uuid == uuid }) {
            items[idx] = new
        } else {
            items.append(new)
        }
        save()
        // Also store last selected for quick access anywhere
        UserDefaults.standard.set(name, forKey: lastNameKey)
        UserDefaults.standard.set(uuid, forKey: lastUUIDKey)
    }

    func lastSelected() -> SelectedDevice? {
        if let uuid = UserDefaults.standard.string(forKey: lastUUIDKey),
           let name = UserDefaults.standard.string(forKey: lastNameKey) {
            return SelectedDevice(name: name, uuid: uuid)
        }
        return nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: listKey),
              let decoded = try? JSONDecoder().decode([SelectedDevice].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }
}
    

class SharedDevice: ObservableObject {
    static let shared = SharedDevice()
    
    @Published var connectedDevice: DeviceInfo?
    @Published var lastReceivedFF02Value: String?
    @Published var lastReceivedBytes: [UInt8] = [] {
        didSet {
            if lastReceivedBytes.count == 2 {
                let mode = lastReceivedBytes[0]
                let flags = lastReceivedBytes[1]
                print("📊 Received Mode: \(mode == 91 ? "Normal" : mode == 90 ? "Developer" : "Unknown")")
                print("📊 Flags Byte: \(String(format: "%08b", flags))")
            }
        }
    }
    
    var isNormalMode: Bool {
        return lastReceivedBytes.first == 91
    }
    
    var isDeveloperMode: Bool {
        return lastReceivedBytes.first == 90
    }
    
    private init() {}
}
