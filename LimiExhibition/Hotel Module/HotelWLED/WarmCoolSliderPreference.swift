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
