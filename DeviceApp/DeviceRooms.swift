//
//  DeviceRooms.swift
//  LIMI AI Device
//
//  Local room grouping for devices (Apple Home style). Assignments are
//  stored on this phone only, keyed the same way as DeviceNamePreference.
//

import SwiftData

@Model
final class DeviceRoomAssignment {
    /// Same storage key as DeviceNamePreference: chennalMac, or uuid as fallback.
    var deviceID: String
    var roomName: String

    init(deviceID: String, roomName: String) {
        self.deviceID = deviceID
        self.roomName = roomName
    }
}
