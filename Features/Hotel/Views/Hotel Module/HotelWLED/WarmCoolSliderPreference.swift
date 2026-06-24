import Foundation
import SwiftData

@Model
final class WarmCoolSliderPreference {
    var deviceID: String
    var channelPosition: Int
    var isReversed: Bool

    init(deviceID: String, channelPosition: Int, isReversed: Bool) {
        self.deviceID = deviceID
        self.channelPosition = channelPosition
        self.isReversed = isReversed
    }
}

@Model
final class DeviceNamePreference {
    var deviceID: String
    var customName: String

    init(deviceID: String, customName: String) {
        self.deviceID = deviceID
        self.customName = customName
    }
}
