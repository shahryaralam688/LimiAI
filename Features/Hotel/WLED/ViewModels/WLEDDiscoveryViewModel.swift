import SwiftUI
import Combine
import Combine

@MainActor
final class WLEDDiscoveryViewModel: ObservableObject {
    @Published private(set) var discoveredDevices: [WLEDDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDevice: WLEDDevice?

    private let discovery: SSDPDiscoveryManager
    private var cancellables: Set<AnyCancellable> = []

    init(discovery: SSDPDiscoveryManager = SSDPDiscoveryManager()) {
        self.discovery = discovery
        wireObservers()
    }

    func startDiscovery() {
        discovery.startDiscovery()
    }

    func stopDiscovery() {
        discovery.stopDiscovery()
    }

    func selectDevice(_ device: WLEDDevice) {
        selectedDevice = device
    }

    private func wireObservers() {
        discovery.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredDevices)

        discovery.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        discovery.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
}
