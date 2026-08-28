//
//  HomeViewModel.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//
import SwiftUI

struct PendingBLEDevice: Equatable {
    let name: String
    let id: String
}

enum HomeModuleDestination {
    case connectedDevices
    case configurator
    case arView
    case roomScan
    case voicePendantScan
}

extension HomeModuleDestination {
    init?(_ route: HomeRoute) {
        switch route {
        case .connectedDevices: self = .connectedDevices
        case .configurator: self = .configurator
        case .arView: self = .arView
        case .roomScan: self = .roomScan
        case .voicePendantScan: self = .voicePendantScan
        default: return nil
        }
    }
}

protocol HomeDeviceAllocating {
    func allocateDevice(deviceId: String)
}

protocol HomeLocationProviding {
    func currentAddress() -> String?
}

protocol HomeAuthProviding {
    func token() -> String?
}

protocol HomeNetworkPerforming {
    func perform(_ request: URLRequest)
}

struct DefaultHomeDeviceAllocator: HomeDeviceAllocating {
    func allocateDevice(deviceId: String) {
        DeviceAllocationService.shared.allocateDevice(deviceId: deviceId)
    }
}

struct DefaultHomeLocationProvider: HomeLocationProviding {
    func currentAddress() -> String? {
        LocationHelper.getCurrentAddress()
    }
}

struct DefaultHomeAuthProvider: HomeAuthProviding {
    func token() -> String? {
        AuthManager.shared.getToken()
    }
}

struct DefaultHomeNetworkPerformer: HomeNetworkPerforming {
    func perform(_ request: URLRequest) {
        LimiHTTPClient.perform(request) { _, _, _ in }
    }
}

// ViewModel to handle business logic and state management
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isSidebarOpen = false
    @Published var searchText = ""
    @Published var linkedDevices: [DeviceHome] = []
    @Published var isNavigatingToAddDevice = false
    @Published var showARScan = false
    @Published var showCustomer = false
    @Published var showGrouping = false
    @Published var selectedTab = 0
    /// Single presentation route for Home modals (Phase C).
    @Published var activeRoute: HomeRoute?
    @Published var selectedModuleForAction: Module?
    @Published var showModuleActionMenu = false
    
    // Animation states
    @Published var isLoaded = false
    @Published var searchFieldFocused = false
    @Published var headerOffset: CGFloat = -100
    @Published var shimmerAnimation = false  // For shimmer effect
    @Published var pendingBLEDevice: PendingBLEDevice?
    @Published var selectedDeviceName = ""
    @Published var selectedDeviceId = ""
    @Published var selectedWifiSSID: [String] = []
    @Published private(set) var wifiDevices: [WifiDevice] = []
    
    // MARK: - Dependencies
    private let deviceService: DeviceServiceProtocol
    private let deviceAllocator: HomeDeviceAllocating
    private let locationProvider: HomeLocationProviding
    private let authProvider: HomeAuthProviding
    private let networkPerformer: HomeNetworkPerforming
    private var bleAcceptedIds: Set<String> = []
    private var bleRejectedIds: Set<String> = []
    private var knownWifiDevices: [String: WifiDevice] = [:]
    private var allocatedWifiDeviceIds: Set<String> = []
    private var banpurUploadedDeviceIds: Set<String> = []
    
    // MARK: - Initialization
    init(
        deviceService: DeviceServiceProtocol = DeviceService(),
        deviceAllocator: HomeDeviceAllocating = DefaultHomeDeviceAllocator(),
        locationProvider: HomeLocationProviding = DefaultHomeLocationProvider(),
        authProvider: HomeAuthProviding = DefaultHomeAuthProvider(),
        networkPerformer: HomeNetworkPerforming = DefaultHomeNetworkPerformer()
    ) {
        self.deviceService = deviceService
        self.deviceAllocator = deviceAllocator
        self.locationProvider = locationProvider
        self.authProvider = authProvider
        self.networkPerformer = networkPerformer
    }
    
    // MARK: - Methods
    func fetchLinkedDevices() {
        deviceService.fetchLinkedDevices { [weak self] result in
            switch result {
            case .success(let devices):
                DispatchQueue.main.async {
                    self?.linkedDevices = devices
                }
            case .failure:
                break
            }
        }
    }
    
    func setupInitialState() {
        // Trigger animations when view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.headerOffset = 0
                self.isLoaded = true
            }
        }
        self.shimmerAnimation = true
        fetchLinkedDevices()
    }

    func handleDiscoveredBLEDevices(_ devices: [(name: String, id: String)], allowedNames: Set<String>) {
        guard pendingBLEDevice == nil else { return }

        for device in devices {
            let normalizedName = device.name.lowercased()
            let isSupportedDevice = allowedNames.contains(normalizedName) || normalizedName.hasPrefix("limi1ch-")

            guard isSupportedDevice else { continue }
            guard !bleAcceptedIds.contains(device.id), !bleRejectedIds.contains(device.id) else { continue }

            pendingBLEDevice = PendingBLEDevice(name: device.name, id: device.id)
            return
        }
    }

    func acceptPendingBLEDevice() -> PendingBLEDevice? {
        guard let device = pendingBLEDevice else { return nil }
        bleAcceptedIds.insert(device.id)
        pendingBLEDevice = nil
        selectedDeviceName = device.name
        selectedDeviceId = device.id
        return device
    }

    func rejectPendingBLEDevice() {
        guard let device = pendingBLEDevice else { return }
        bleRejectedIds.insert(device.id)
        pendingBLEDevice = nil
    }

    func presentWifiProvisioning(list: [String]) {
        selectedWifiSSID = list
        present(.wifiProvisioning)
    }

    func handleBluetoothStateChanged(isOn: Bool) {
        if !isOn {
            pendingBLEDevice = nil
        }
    }

    func present(_ route: HomeRoute) {
        activeRoute = route
    }

    func dismissActiveRoute() {
        activeRoute = nil
    }

    func routeBinding(_ route: HomeRoute) -> Binding<Bool> {
        Binding(
            get: { self.activeRoute == route },
            set: { newValue in
                if newValue {
                    self.activeRoute = route
                } else if self.activeRoute == route {
                    self.activeRoute = nil
                }
            }
        )
    }

    func presentVoiceView() {
        present(.voice)
    }

    func presentModulesView() {
        present(.moduler)
    }

    func presentModuleActionMenu(for module: Module) {
        selectedModuleForAction = module
        showModuleActionMenu = true
    }

    func dismissModuleActionMenu() {
        selectedModuleForAction = nil
        showModuleActionMenu = false
    }

    func presentDestination(for module: Module) -> HomeModuleDestination? {
        switch module.id {
        case 1:
            present(.connectedDevices)
            return .connectedDevices
        case 2:
            present(.configurator)
            return .configurator
        case 3:
            present(.arView)
            return .arView
        case 4:
            present(.roomScan)
            return .roomScan
        case 5:
            present(.voicePendantScan)
            return .voicePendantScan
        default:
            return nil
        }
    }

    func processBonjourWiFiDevices(_ newDevices: [BLEDevice], allowedNames: Set<String>) {
        let filtered = newDevices.filter { dev in
            let normalizedName = dev.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return allowedNames.contains(normalizedName) || normalizedName.hasPrefix("limi1ch-")
        }

        let currentUUIDs = Set(filtered.map(\.uuid))

        for dev in filtered {
            knownWifiDevices[dev.uuid] = makeWifiDevice(from: dev)

            if dev.reachability == .online,
               let txt = dev.txtRecord,
               let deviceId = txt["deviceId"],
               !allocatedWifiDeviceIds.contains(deviceId) {
                allocatedWifiDeviceIds.insert(deviceId)
                deviceAllocator.allocateDevice(deviceId: deviceId)
            }

            if dev.reachability == .online,
               let txt = dev.txtRecord,
               let deviceId = txt["deviceId"],
               !banpurUploadedDeviceIds.contains(deviceId) {
                let currentAddress = locationProvider.currentAddress()?.lowercased() ?? ""
                if currentAddress.contains("banpur") {
                    let mappedDevice = makeWifiDevice(from: dev)
                    let uploadDevice = WifiDevice(
                        id: deviceId,
                        uuid: mappedDevice.uuid,
                        chennalMac: mappedDevice.chennalMac,
                        chennalCount: mappedDevice.chennalCount,
                        channelTypes: mappedDevice.channelTypes,
                        deviceName: mappedDevice.deviceName,
                        isOnline: mappedDevice.isOnline
                    )
                    sendDeviceToBackend(device: uploadDevice)
                    banpurUploadedDeviceIds.insert(deviceId)
                }
            }
        }

        for (uuid, device) in knownWifiDevices where !currentUUIDs.contains(uuid) && device.isOnline {
            var offlineCopy = device
            offlineCopy.isOnline = false
            knownWifiDevices[uuid] = offlineCopy
        }

        wifiDevices = Array(knownWifiDevices.values)
            .sorted { $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending }
    }

    private func makeWifiDevice(from dev: BLEDevice) -> WifiDevice {
        var channelCount = 1
        var channelTypes: [String] = ["CCT"]
        var mac = dev.uuid

        if let txt = dev.txtRecord {
            if let value = txt["channelCount"], let count = Int(value) {
                channelCount = count
            }
            if let channelPayload = txt["channelTypes"] {
                let types = channelPayload
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                    .filter { $0 == "CCT" || $0 == "RGB" }
                if !types.isEmpty {
                    channelTypes = types
                }
            }
            if let deviceId = txt["deviceId"] {
                mac = deviceId
            }
        }

        return WifiDevice(
            id: dev.uuid,
            uuid: dev.uuid,
            chennalMac: mac,
            chennalCount: channelCount,
            channelTypes: channelTypes,
            deviceName: dev.name,
            isOnline: dev.reachability == .online
        )
    }

    private func sendDeviceToBackend(device: WifiDevice) {
        guard authProvider.token() != nil else { return }

        let body: [String: Any] = [
            "deviceId": device.chennalMac,
            "metadata": [
                "uuid": device.uuid,
                "chennalMac": device.chennalMac,
                "chennalCount": device.chennalCount,
                "channelTypes": device.channelTypes,
                "deviceName": device.deviceName,
                "isOnline": device.isOnline
            ]
        ]

        LimiDeviceAPI.postDeviceUser(body: body, logPrefix: "HomeViewModel")
    }
}
