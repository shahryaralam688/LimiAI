import SwiftUI

@MainActor
final class WLEDDeviceControlViewModel: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var brightness: Double = 128
    @Published var isOn = false
    @Published var selectedColor = Color.red

    let device: WLEDDevice
    private let controller: WLEDDeviceController

    init(device: WLEDDevice, controller: WLEDDeviceController? = nil) {
        self.device = device
        self.controller = controller ?? WLEDDeviceController(device: device)
    }

    func loadState() async {
        await controller.fetchState()
        isConnected = controller.isConnected
        isLoading = controller.isLoading
        errorMessage = controller.errorMessage
        if let state = controller.deviceState {
            isOn = state.on
            brightness = Double(state.bri)
        }
    }

    func setPower(_ enabled: Bool) async {
        await controller.setPower(enabled)
        await loadState()
    }

    func setBrightness(_ value: Int) async {
        await controller.setBrightness(value)
        await loadState()
    }

    func setColor(red: Int, green: Int, blue: Int) async {
        await controller.setColor(red: red, green: green, blue: blue)
        await loadState()
    }
}
