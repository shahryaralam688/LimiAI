//
//  WiFiProvisioningCoordinator.swift
//  Limi
//
//  Two-phase Wi-Fi provisioning aligned with common IoT practice:
//    1. BLE credential transfer
//    2. Confirmation via local Bonjour/mDNS OR backend MQTT presence (device_status)
//

import Combine
import Foundation

enum WiFiProvisioningFailure: Equatable, Error {
    case credentialTransferFailed(String)
    case networkJoinTimeout
    case cancelled

    var userMessage: String {
        switch self {
        case .credentialTransferFailed(let detail):
            return detail.isEmpty
                ? "Could not send credentials to the device. Make sure Bluetooth is connected and try again."
                : detail
        case .networkJoinTimeout:
            return "The device did not come online in time. Check your Wi-Fi password and that your phone has internet access, then try again."
        case .cancelled:
            return "Setup was cancelled."
        }
    }
}

struct WiFiProvisioningOutcome: Equatable {
    let deviceName: String
    let deviceId: String
    let wifiDevice: BLEDevice
}

/// Orchestrates BLE credential delivery and post-reboot online confirmation.
@MainActor
final class WiFiProvisioningCoordinator {
    static let shared = WiFiProvisioningCoordinator()

    /// ESP-class devices typically need 20–40 s to reboot, join Wi-Fi, and publish presence.
    static let defaultNetworkJoinTimeout: TimeInterval = 60

    private var cancellables = Set<AnyCancellable>()
    private var presenceHandler: ((String, String) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private var isRunning = false

    private init() {}

    func provisionAndVerify(
        deviceName: String,
        bleDeviceId: String,
        ssid: String,
        password: String,
        networkJoinTimeout: TimeInterval = defaultNetworkJoinTimeout,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<WiFiProvisioningOutcome, WiFiProvisioningFailure>) -> Void
    ) {
        guard !isRunning else { return }
        isRunning = true

        let provisionStartedAt = Date()
        onPhaseUpdate("Sending Wi-Fi credentials…")

        BonjourServiceBrowser.shared.startBrowsing()
        LightControllingSocket.shared.connect()

        let knownBonjourKeys = Self.onlineBonjourKeys(BonjourServiceBrowser.shared.discoveredWiFiDevices)

        BluetoothManager.shared.provisionWifi(ssid: ssid, password: password) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                if result.status == "error" {
                    self.finishRunning()
                    completion(.failure(.credentialTransferFailed(result.message)))
                    return
                }

                onPhaseUpdate("Device is joining \"\(ssid)\" on your network…")
                self.waitForDeviceOnline(
                    bleAdvertisedName: deviceName,
                    bleDeviceId: bleDeviceId,
                    knownBonjourKeys: knownBonjourKeys,
                    since: provisionStartedAt,
                    timeout: networkJoinTimeout,
                    onPhaseUpdate: onPhaseUpdate,
                    completion: completion
                )
            }
        }
    }

    func cancel() {
        if let presenceHandler {
            // Handlers are append-only today; clear our reference so we ignore stale callbacks.
            self.presenceHandler = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        cancellables.removeAll()
        isRunning = false
    }

    private func finishRunning() {
        presenceHandler = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cancellables.removeAll()
        isRunning = false
    }

    private func waitForDeviceOnline(
        bleAdvertisedName: String,
        bleDeviceId: String,
        knownBonjourKeys: Set<String>,
        since: Date,
        timeout: TimeInterval,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<WiFiProvisioningOutcome, WiFiProvisioningFailure>) -> Void
    ) {
        let browser = BonjourServiceBrowser.shared

        if let match = Self.findNewOnlineBonjourDevice(
            in: browser.discoveredWiFiDevices,
            bleAdvertisedName: bleAdvertisedName,
            bleDeviceId: bleDeviceId,
            knownBefore: knownBonjourKeys,
            since: since
        ) {
            finishRunning()
            completion(.success(Self.outcome(from: match, fallbackName: bleAdvertisedName)))
            return
        }

        onPhaseUpdate("Waiting for device to come online (this can take up to a minute)…")

        let completeSuccess: (BLEDevice, String) -> Void = { [weak self] device, resolvedId in
            guard let self, self.isRunning else { return }
            self.finishRunning()
            completion(.success(WiFiProvisioningOutcome(
                deviceName: device.name,
                deviceId: resolvedId,
                wifiDevice: device
            )))
        }

        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled, self.isRunning else { return }
            self.finishRunning()
            completion(.failure(.networkJoinTimeout))
        }

        browser.$discoveredWiFiDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self, self.isRunning else { return }
                if let match = Self.findNewOnlineBonjourDevice(
                    in: devices,
                    bleAdvertisedName: bleAdvertisedName,
                    bleDeviceId: bleDeviceId,
                    knownBefore: knownBonjourKeys,
                    since: since
                ) {
                    let resolvedId = match.txtRecord?["deviceId"] ?? match.uuid
                    completeSuccess(match, resolvedId)
                }
            }
            .store(in: &cancellables)

        // Backend MQTT presence via Socket.IO `device_status` (status = "on").
        SocketIOMQTTBridge.shared.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, self.isRunning, update.connected else { return }
                let deviceId = update.deviceId.uppercased()
                guard !knownBonjourKeys.contains(deviceId) else { return }

                let synthetic = BLEDevice(
                    name: bleAdvertisedName,
                    uuid: deviceId,
                    deviceType: .wifi,
                    txtRecord: ["deviceId": deviceId],
                    reachability: .online,
                    lastSeen: Date()
                )
                completeSuccess(synthetic, deviceId)
            }
            .store(in: &cancellables)

        let handler: (String, String) -> Void = { [weak self] deviceId, status in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                guard LimiDeviceNaming.isOnlinePresenceStatus(status) else { return }
                let normalizedId = deviceId.uppercased()
                guard !knownBonjourKeys.contains(normalizedId) else { return }

                let synthetic = BLEDevice(
                    name: bleAdvertisedName,
                    uuid: normalizedId,
                    deviceType: .wifi,
                    txtRecord: ["deviceId": normalizedId],
                    reachability: .online,
                    lastSeen: Date()
                )
                completeSuccess(synthetic, normalizedId)
            }
        }
        presenceHandler = handler
        LightControllingSocket.shared.registerPresenceHandler(handler)
    }

    // MARK: - Matching helpers

    private static func onlineBonjourKeys(_ devices: [BLEDevice]) -> Set<String> {
        var keys = Set<String>()
        for device in devices where device.deviceType == .wifi && device.reachability == .online {
            keys.insert(device.uuid)
            if let deviceId = device.txtRecord?["deviceId"], !deviceId.isEmpty {
                keys.insert(deviceId.uppercased())
            }
        }
        return keys
    }

    private static func findNewOnlineBonjourDevice(
        in devices: [BLEDevice],
        bleAdvertisedName: String,
        bleDeviceId: String,
        knownBefore: Set<String>,
        since: Date
    ) -> BLEDevice? {
        devices.first { device in
            guard device.deviceType == .wifi, device.reachability == .online else { return false }
            guard LimiDeviceNaming.isAllowedDeviceName(device.name) else { return false }

            let txtId = (device.txtRecord?["deviceId"] ?? "").uppercased()
            var keys = [device.uuid]
            if !txtId.isEmpty { keys.append(txtId) }
            guard keys.allSatisfy({ !knownBefore.contains($0) }) else { return false }

            if let lastSeen = device.lastSeen {
                return lastSeen >= since.addingTimeInterval(-5)
            }
            return true
        }
    }

    private static func outcome(from device: BLEDevice, fallbackName: String) -> WiFiProvisioningOutcome {
        let resolvedId = (device.txtRecord?["deviceId"] ?? device.uuid).uppercased()
        return WiFiProvisioningOutcome(
            deviceName: device.name.isEmpty ? fallbackName : device.name,
            deviceId: resolvedId,
            wifiDevice: device
        )
    }
}
