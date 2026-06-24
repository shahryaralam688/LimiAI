import SwiftUI

/// WLED full-screen control state (wraps `WLEDAPIManager` for `WLEDView`).
@MainActor
final class WLEDControlViewModel: ObservableObject {
    private let apiManager: WLEDAPIManager

    var isConnected: Bool { apiManager.isConnected }
    var isLoading: Bool { apiManager.isLoading }
    var errorMessage: String? { apiManager.errorMessage }
    var currentState: WLEDAPIManager.WLEDState? { apiManager.currentState }
    var effects: [WLEDAPIManager.WLEDEffect] { apiManager.effects }

    init(apiManager: WLEDAPIManager? = nil) {
        self.apiManager = apiManager ?? WLEDAPIManager()
    }

    func initializeOnAppear() async {
        await apiManager.initializeFullSegment()
        await apiManager.fetchEffects()
        await apiManager.fetchState()
    }

    func setColor(red: Int, green: Int, blue: Int) async {
        await apiManager.setColor(red: red, green: green, blue: blue)
    }

    func setBrightness(_ value: Int) async {
        await apiManager.setBrightness(value)
    }

    func setPower(_ isOn: Bool) async {
        await apiManager.setPower(isOn)
    }

    func setEffect(_ effectId: Int) async {
        await apiManager.setEffect(effectId)
    }
}
