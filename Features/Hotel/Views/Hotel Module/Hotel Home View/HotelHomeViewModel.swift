import SwiftUI

enum HotelBottomTab: String, CaseIterable {
    case home = "Home"
    case requests = "Requests"
    case system = "Device"
    case profile = "Profile"
}

protocol HotelSocketControlling: AnyObject {
    var onOrderUpdate: ((String) -> Void)? { get set }
    func connect()
}

protocol HotelLocationStarting: AnyObject {
    func ensurePermissionAndStart()
}

extension SocketIOExample: HotelSocketControlling {}
extension LocationManager: HotelLocationStarting {}

@MainActor
final class HotelHomeViewModel: ObservableObject {
    @Published var selectedTab: HotelBottomTab = .home
    @Published var showVoiceView = false
    @Published var showAddDeviceFlow = false
    @Published var isSidebarOpen = false

    private var hasStarted = false

    func handleAppear(
        socketClient: HotelSocketControlling?,
        bluetoothManager: BluetoothManager,
        locationManager: HotelLocationStarting
    ) {
        guard !hasStarted else { return }
        hasStarted = true

        socketClient?.onOrderUpdate = { action in
            bluetoothManager.BLESend(message: action)
        }
        socketClient?.connect()
        locationManager.ensurePermissionAndStart()
    }
}
