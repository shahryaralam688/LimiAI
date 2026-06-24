import SwiftUI

final class AddDeviceViewModel: ObservableObject {
    enum Screen {
        case addDevices
        case starter
    }

    @Published var currentScreen: Screen = .addDevices
    @Published private(set) var showBackButton = true

    func handleOptionSelected(_ option: ConnectionOption) {
        guard option == .nearby else { return }
        withAnimation {
            currentScreen = .starter
            updateBackButtonVisibility()
        }
    }

    func syncNavigationState() {
        updateBackButtonVisibility()
    }

    private func updateBackButtonVisibility() {
        showBackButton = currentScreen == .addDevices
    }
}
