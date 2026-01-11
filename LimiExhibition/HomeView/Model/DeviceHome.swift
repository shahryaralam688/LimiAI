//
//  DeviceHome.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//

import SwiftUI
// MARK: - Device Models
struct DeviceHome: Identifiable, Codable {
    let id: String
    var name: String
    var deviceID: String
    var isOn: Bool
}

struct APIResponseHome: Codable {
    let success: Bool
    let devices: DeviceData
}

struct DeviceData: Codable {
    let username: String
    let devices: [DeviceListHome]
}

struct DeviceListHome: Codable {
    let device_name: String
    let device_id: String
}
