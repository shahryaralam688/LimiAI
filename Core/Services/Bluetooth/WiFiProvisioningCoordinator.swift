//
//  WiFiProvisioningCoordinator.swift
//  Limi
//
//  Two-phase Wi-Fi provisioning:
//    1. BLE credential transfer — success when the device accepts credentials.
//    2. MQTT/Bonjour presence continues in the background (does not block setup UI).
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

/// Thread-safe gate so Bonjour (nonisolated) can skip ghost-purge during active provision.
enum WiFiProvisioningActivityGate {
    private static let lock = NSLock()
    private static var _isActive = false

    static var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isActive
    }

    static func setActive(_ active: Bool) {
        lock.lock()
        _isActive = active
        lock.unlock()
    }
}

/// Thread-safe gate while Add Device scan / Wi‑Fi list is open (blocks cloud-miss BLE reconnect).
enum AddDeviceFlowActivityGate {
    private static let lock = NSLock()
    private static var _isActive = false

    static var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isActive
    }

    static func setActive(_ active: Bool) {
        lock.lock()
        _isActive = active
        lock.unlock()
    }
}

struct WiFiProvisioningOutcome: Equatable {
    let deviceName: String
    let deviceId: String
    let blePeripheralUUID: String
    let wifiDevice: BLEDevice
}

/// Orchestrates BLE credential delivery and post-reboot online confirmation.
@MainActor
final class WiFiProvisioningCoordinator {
    static let shared = WiFiProvisioningCoordinator()

    /// ESP-class devices typically need 20–40 s to reboot, join Wi-Fi, and publish presence.
    static let defaultNetworkJoinTimeout: TimeInterval = 60
    /// Master sequential flow: two hubs reboot back-to-back need extra headroom.
    static let masterNetworkJoinTimeout: TimeInterval = 90

    private var cancellables = Set<AnyCancellable>()
    private var presenceHandlerToken: UUID?
    private var timeoutTask: Task<Void, Never>?
    private var isRunning = false
    /// Bumps each wait so a stale Socket.IO presence handler cannot complete a newer provision.
    private var waitGeneration = 0
    /// Live online IDs to ignore while waiting; IDs are removed if they go offline (re-provision reboot).
    private var waitingSkipOnlineIds: Set<String> = []
    /// Throttle noisy Bonjour candidate dumps while waiting.
    private var lastCandidateDumpAt: Date = .distantPast

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
        if isRunning {
            DeviceConsole.log(
                .provision,
                "BLOCKED — already provisioning another device. Finish/cancel first. requested=\(deviceName) ble=\(bleDeviceId)"
            )
            completion(.failure(.cancelled))
            return
        }
        isRunning = true
        WiFiProvisioningActivityGate.setActive(true)

        DeviceConsole.log(
            .provision,
            "target name=\(deviceName) bleUUID=\(bleDeviceId) SSID=\(ssid) passwordLen=\(password.count)"
        )
        DeviceConsole.banner("PROVISION START (single hub)")
        DeviceConsole.dumpConfiguredStore(reason: "before provision")
        DeviceConsole.dumpBonjourOnline(reason: "before provision")
        DeviceConsole.log(
            .provision,
            "BLE snapshot liveConnected=\(BluetoothManager.shared.isLiveConnected(forPeripheralUUID: bleDeviceId)) isConnected=\(BluetoothManager.shared.isConnected) current=\(BluetoothManager.shared.connectedPeripheral?.identifier.uuidString ?? "nil")"
        )

        BonjourServiceBrowser.shared.startBrowsing()
        LightControllingSocket.shared.connect()

        let knownBonjourKeys = Self.siblingOnlineKeysToSkip(whileProvisioningBleUUID: bleDeviceId)
        DeviceConsole.log(
            .provision,
            "sibling skip keys at start (\(knownBonjourKeys.count)): \(knownBonjourKeys.sorted().joined(separator: ", "))"
        )

        // Ensure THIS hub is the connected peripheral before writing credentials.
        // After device #1 joins Wi‑Fi, auto-reconnect can leave us with nil / wrong peripheral.
        Task { @MainActor in
            onPhaseUpdate("Connecting over Bluetooth…")
            let prepared = await self.prepareSingleHubBLE(
                name: deviceName,
                bleUUID: bleDeviceId,
                onPhaseUpdate: onPhaseUpdate
            )
            guard prepared else {
                DeviceConsole.log(.provision, "credential transfer FAIL — could not prepare BLE for \(bleDeviceId)")
                DeviceConsole.banner("PROVISION FAIL — BLE not ready")
                self.finishRunning()
                completion(.failure(.credentialTransferFailed("No connected peripheral")))
                return
            }

            onPhaseUpdate("Sending Wi-Fi credentials…")
            BluetoothManager.shared.provisionWifi(
                ssid: ssid,
                password: password,
                expectedPeripheralUUID: bleDeviceId
            ) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }

                    if result.status == "error" {
                        DeviceConsole.log(.provision, "credential transfer FAIL \(result.message)")
                        DeviceConsole.banner("PROVISION FAIL — credentials")
                        self.finishRunning()
                        completion(.failure(.credentialTransferFailed(result.message)))
                        return
                    }

                    DeviceConsole.log(
                        .provision,
                        "credentials confirmed status=\(result.status) msg=\(result.message) — completing without MQTT wait"
                    )
                    BluetoothManager.shared.disconnectPeripheral(
                        uuidString: bleDeviceId,
                        suppressReconnect: true
                    )

                    onPhaseUpdate("Credentials confirmed")
                    self.finishRunning()
                    completion(.success(Self.credentialConfirmedOutcome(
                        deviceName: deviceName,
                        blePeripheralUUID: bleDeviceId
                    )))
                }
            }
        }
    }

    /// Connect + wait for FB02/FB03 on one hub (does not change virtual-master group flow).
    private func prepareSingleHubBLE(
        name: String,
        bleUUID: String,
        onPhaseUpdate: @escaping (String) -> Void
    ) async -> Bool {
        let ble = BluetoothManager.shared
        DeviceConsole.log(
            .provision,
            "prepareSingleHubBLE start name=\(name) uuid=\(bleUUID) live=\(ble.isLiveConnected(forPeripheralUUID: bleUUID))"
        )

        // Drop any other live GATT link so we do not write credentials to the wrong hub.
        for (uuid, entry) in ble.connectedDevices where entry.peripheral.state == .connected {
            if uuid.uuidString.caseInsensitiveCompare(bleUUID) != .orderedSame {
                DeviceConsole.log(
                    .provision,
                    "prepareSingleHubBLE — disconnect other hub \(uuid.uuidString) before target"
                )
                ble.disconnectPeripheral(uuidString: uuid.uuidString, suppressReconnect: true)
            }
        }
        if let current = ble.connectedPeripheral,
           current.identifier.uuidString.caseInsensitiveCompare(bleUUID) != .orderedSame {
            ble.disconnectPeripheral(
                uuidString: current.identifier.uuidString,
                suppressReconnect: true
            )
        }

        ble.clearProvisioningCharacteristics()
        try? await Task.sleep(nanoseconds: 400_000_000)

        onPhaseUpdate("Connecting over Bluetooth…")
        let connected = await Self.waitForBLEConnection(name: name, uuid: bleUUID, timeout: 25)
        guard connected else {
            DeviceConsole.log(.provision, "prepareSingleHubBLE FAIL — connect timeout uuid=\(bleUUID)")
            return false
        }

        onPhaseUpdate("Preparing Bluetooth…")
        let ready = await ble.waitForProvisioningReady(peripheralUUID: bleUUID, timeout: 25)
        if !ready {
            DeviceConsole.log(.provision, "prepareSingleHubBLE FAIL — FB02/FB03 timeout uuid=\(bleUUID)")
        } else {
            DeviceConsole.log(.provision, "prepareSingleHubBLE OK uuid=\(bleUUID)")
        }
        return ready
    }

    func cancel() {
        DeviceConsole.log(.provision, "cancel() called isRunning=\(isRunning)")
        finishRunning()
    }

    private func finishRunning() {
        if let token = presenceHandlerToken {
            LightControllingSocket.shared.unregisterPresenceHandler(token)
            presenceHandlerToken = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        cancellables.removeAll()
        waitingSkipOnlineIds.removeAll()
        isRunning = false
        WiFiProvisioningActivityGate.setActive(false)
        waitGeneration += 1
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
        waitingSkipOnlineIds = knownBonjourKeys

        if let match = Self.findNewOnlineBonjourDevice(
            in: browser.discoveredWiFiDevices,
            bleAdvertisedName: bleAdvertisedName,
            bleDeviceId: bleDeviceId,
            knownBefore: waitingSkipOnlineIds,
            since: since
        ) {
            let resolvedId = match.txtRecord?["deviceId"] ?? match.uuid
            DeviceConsole.log(
                .provision,
                "already online on Bonjour id=\(resolvedId) name=\(match.name) (matched before wait)"
            )
            DeviceConsole.banner("PROVISION SUCCESS — Bonjour immediate")
            finishRunning()
            completion(.success(Self.outcome(from: match, fallbackName: bleAdvertisedName, blePeripheralUUID: bleDeviceId)))
            return
        }

        onPhaseUpdate("Waiting for device to come online (this can take up to a minute)…")
        DeviceConsole.log(
            .provision,
            "waiting up to \(Int(timeout))s for NEW online device (target BLE name=\(bleAdvertisedName) uuid=\(bleDeviceId))"
        )

        waitGeneration += 1
        let generation = waitGeneration

        let completeSuccess: (BLEDevice, String, String) -> Void = { [weak self] device, resolvedId, path in
            guard let self, self.isRunning, self.waitGeneration == generation else {
                DeviceConsole.log(
                    .provision,
                    "ignore late success path=\(path) id=\(resolvedId) — not running or stale generation"
                )
                return
            }
            let normalizedResolved = LimiDeviceNaming.normalizedHardwareId(resolvedId)
            guard !Self.isKnownOnlineId(normalizedResolved, in: self.waitingSkipOnlineIds) else {
                DeviceConsole.log(
                    .provision,
                    "ignore success path=\(path) id=\(normalizedResolved) — already online sibling hub"
                )
                return
            }
            DeviceConsole.log(
                .provision,
                "SUCCESS via \(path) id=\(normalizedResolved) name=\(device.name) ip=\(device.ipAddress ?? "-") targetBLE=\(bleDeviceId)"
            )
            DeviceConsole.banner("PROVISION SUCCESS — \(path)")
            DeviceConsole.dumpBonjourOnline(reason: "at success")
            self.finishRunning()
            completion(.success(WiFiProvisioningOutcome(
                deviceName: device.name,
                deviceId: normalizedResolved,
                blePeripheralUUID: bleDeviceId,
                wifiDevice: device
            )))
        }

        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled, self.isRunning else { return }
            DeviceConsole.dumpBonjourOnline(reason: "at TIMEOUT")
            DeviceConsole.dumpConfiguredStore(reason: "at TIMEOUT")
            DeviceConsole.log(
                .provision,
                "TIMEOUT — target ble=\(bleDeviceId) name=\(bleAdvertisedName) did not come online in \(Int(timeout))s"
            )
            DeviceConsole.banner("PROVISION FAIL — timeout")
            self.finishRunning()
            completion(.failure(.networkJoinTimeout))
        }

        browser.$discoveredWiFiDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self, self.isRunning, self.waitGeneration == generation else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastCandidateDumpAt) >= 2.0 {
                    self.lastCandidateDumpAt = now
                    Self.logBonjourCandidates(
                        devices: devices,
                        knownBefore: self.waitingSkipOnlineIds,
                        since: since,
                        targetName: bleAdvertisedName,
                        targetBLE: bleDeviceId
                    )
                }
                if let match = Self.findNewOnlineBonjourDevice(
                    in: devices,
                    bleAdvertisedName: bleAdvertisedName,
                    bleDeviceId: bleDeviceId,
                    knownBefore: self.waitingSkipOnlineIds,
                    since: since
                ) {
                    let resolvedId = match.txtRecord?["deviceId"] ?? match.uuid
                    DeviceConsole.log(.provision, "confirmed via Bonjour id=\(resolvedId) name=\(match.name)")
                    completeSuccess(match, resolvedId, "Bonjour")
                }
            }
            .store(in: &cancellables)

        SocketIOMQTTBridge.shared.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, self.isRunning, self.waitGeneration == generation else { return }
                let deviceId = LimiDeviceNaming.normalizedHardwareId(update.deviceId)
                if !update.connected {
                    if !deviceId.isEmpty, Self.isKnownOnlineId(deviceId, in: self.waitingSkipOnlineIds) {
                        Self.removeKnownOnlineId(deviceId, from: &self.waitingSkipOnlineIds)
                        DeviceConsole.log(
                            .provision,
                            "MQTT offline — allow id=\(deviceId) to count as NEW if it returns"
                        )
                    }
                    return
                }
                let knownSkip = Self.isKnownOnlineId(deviceId, in: self.waitingSkipOnlineIds)
                DeviceConsole.log(
                    .provision,
                    "MQTT presence event id=\(update.deviceId) connected=true knownSkip=\(knownSkip)"
                )
                guard !deviceId.isEmpty, !knownSkip else {
                    if knownSkip {
                        DeviceConsole.log(.provision, "MQTT skip — sibling still online id=\(deviceId)")
                    }
                    return
                }
                DeviceConsole.log(.provision, "confirmed via MQTT presence id=\(deviceId)")

                let synthetic = BLEDevice(
                    name: bleAdvertisedName,
                    uuid: deviceId,
                    deviceType: .wifi,
                    txtRecord: ["deviceId": deviceId],
                    reachability: .online,
                    lastSeen: Date()
                )
                completeSuccess(synthetic, deviceId, "MQTT")
            }
            .store(in: &cancellables)

        let handler: (String, String) -> Void = { [weak self] deviceId, status in
            Task { @MainActor in
                guard let self, self.isRunning, self.waitGeneration == generation else { return }
                DeviceConsole.log(.provision, "socket presenceHandler id=\(deviceId) status=\(status)")
                let normalizedId = LimiDeviceNaming.normalizedHardwareId(deviceId)
                if !LimiDeviceNaming.isOnlinePresenceStatus(status) {
                    if LimiDeviceNaming.isDefinitePresenceStatus(status),
                       !normalizedId.isEmpty,
                       Self.isKnownOnlineId(normalizedId, in: self.waitingSkipOnlineIds) {
                        Self.removeKnownOnlineId(normalizedId, from: &self.waitingSkipOnlineIds)
                        DeviceConsole.log(
                            .provision,
                            "socket offline — allow id=\(normalizedId) to count as NEW if it returns"
                        )
                    } else {
                        DeviceConsole.log(.provision, "socket presence ignored — not online status=\(status)")
                    }
                    return
                }
                guard !normalizedId.isEmpty else { return }
                guard !Self.isKnownOnlineId(normalizedId, in: self.waitingSkipOnlineIds) else {
                    DeviceConsole.log(.provision, "socket presence skip — sibling still online id=\(normalizedId)")
                    return
                }

                let synthetic = BLEDevice(
                    name: bleAdvertisedName,
                    uuid: normalizedId,
                    deviceType: .wifi,
                    txtRecord: ["deviceId": normalizedId],
                    reachability: .online,
                    lastSeen: Date()
                )
                completeSuccess(synthetic, normalizedId, "SocketPresence")
            }
        }
        presenceHandlerToken = LightControllingSocket.shared.registerPresenceHandler(handler)

        // Device may already be MQTT/Bonjour online from a prior attempt (no new event fires).
        // Accept that immediately when it is not a configured sibling hub.
        if let existing = Self.findAcceptableAlreadyOnlineConfirmation(
            bleAdvertisedName: bleAdvertisedName,
            bleDeviceId: bleDeviceId,
            skipIds: waitingSkipOnlineIds
        ) {
            DeviceConsole.log(
                .provision,
                "already online after credentials id=\(existing.id) path=\(existing.path) — confirming without waiting for a new event"
            )
            completeSuccess(existing.device, existing.id, existing.path)
        }
    }

    // MARK: - Matching helpers

    private static func onlineBonjourKeys(_ devices: [BLEDevice]) -> Set<String> {
        var keys = Set<String>()
        for device in devices where device.deviceType == .wifi && device.reachability == .online {
            let uuidKey = LimiDeviceNaming.normalizedHardwareId(device.uuid)
            if !uuidKey.isEmpty { keys.insert(uuidKey) }
            keys.insert(device.uuid.uppercased())
            if let deviceId = device.txtRecord?["deviceId"], !deviceId.isEmpty {
                let normalized = LimiDeviceNaming.normalizedHardwareId(deviceId)
                if !normalized.isEmpty { keys.insert(normalized) }
                keys.insert(deviceId.uppercased())
            }
        }
        return keys
    }

    /// Only skip hubs that are already configured on a *different* BLE peripheral.
    /// Do NOT skip every live MQTT/Bonjour id — that caused "Couldn't Connect" when the
    /// hub being provisioned was already online (2nd attempt / no app kill).
    private static func siblingOnlineKeysToSkip(whileProvisioningBleUUID: String) -> Set<String> {
        var siblingIds = Set<String>()
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            if record.blePeripheralUUID.caseInsensitiveCompare(whileProvisioningBleUUID) == .orderedSame {
                continue
            }
            let hw = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            guard !hw.isEmpty else { continue }
            siblingIds.insert(hw)
            DeviceConsole.log(
                .provision,
                "skip sibling hub id=\(hw) ble=\(record.blePeripheralUUID) (not target \(whileProvisioningBleUUID))"
            )
        }
        return siblingIds
    }

    /// Snapshot of MQTT/Bonjour that can confirm THIS provision right now.
    private static func findAcceptableAlreadyOnlineConfirmation(
        bleAdvertisedName: String,
        bleDeviceId: String,
        skipIds: Set<String>
    ) -> (device: BLEDevice, id: String, path: String)? {
        // Prefer the hardware id already remembered for this BLE peripheral (re-provision).
        for record in ConfiguredBLEDeviceStore.shared.allRecords
            where record.blePeripheralUUID.caseInsensitiveCompare(bleDeviceId) == .orderedSame
        {
            let hw = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            guard !hw.isEmpty else { continue }
            if DeviceTransportRegistry.shared.state(for: hw).mqttConnected {
                let synthetic = BLEDevice(
                    name: record.displayName.isEmpty ? bleAdvertisedName : record.displayName,
                    uuid: hw,
                    deviceType: .wifi,
                    txtRecord: ["deviceId": hw],
                    reachability: .online,
                    lastSeen: Date()
                )
                return (synthetic, hw, "MQTT-mapped")
            }
            if let bonjour = BonjourServiceBrowser.shared.discoveredWiFiDevices.first(where: {
                $0.deviceType == .wifi
                    && $0.reachability == .online
                    && LimiDeviceNaming.normalizedHardwareId($0.txtRecord?["deviceId"] ?? $0.uuid) == hw
            }) {
                return (bonjour, hw, "Bonjour-mapped")
            }
        }

        // Non-sibling live MQTT (e.g. 2nd hub already online after failed UI confirm).
        for state in DeviceTransportRegistry.shared.allStates where state.mqttConnected {
            let hw = LimiDeviceNaming.normalizedHardwareId(state.deviceId)
            guard !hw.isEmpty, !isKnownOnlineId(hw, in: skipIds) else { continue }
            let synthetic = BLEDevice(
                name: bleAdvertisedName,
                uuid: hw,
                deviceType: .wifi,
                txtRecord: ["deviceId": hw],
                reachability: .online,
                lastSeen: Date()
            )
            return (synthetic, hw, "MQTT-already")
        }

        for device in BonjourServiceBrowser.shared.discoveredWiFiDevices
            where device.deviceType == .wifi && device.reachability == .online
        {
            guard LimiDeviceNaming.isAllowedDeviceName(device.name) else { continue }
            let resolved = LimiDeviceNaming.normalizedHardwareId(
                device.txtRecord?["deviceId"] ?? device.uuid
            )
            guard !resolved.isEmpty, !isKnownOnlineId(resolved, in: skipIds) else { continue }
            return (device, resolved, "Bonjour-already")
        }
        return nil
    }

    private static func isKnownOnlineId(_ deviceId: String, in known: Set<String>) -> Bool {
        let normalized = LimiDeviceNaming.normalizedHardwareId(deviceId)
        if !normalized.isEmpty, known.contains(normalized) { return true }
        let upper = deviceId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if known.contains(upper) { return true }
        for key in known {
            if LimiDeviceNaming.normalizedHardwareId(key) == normalized, !normalized.isEmpty {
                return true
            }
        }
        return false
    }

    private static func removeKnownOnlineId(_ deviceId: String, from known: inout Set<String>) {
        let normalized = LimiDeviceNaming.normalizedHardwareId(deviceId)
        known = known.filter { key in
            let keyNorm = LimiDeviceNaming.normalizedHardwareId(key)
            if !normalized.isEmpty, keyNorm == normalized { return false }
            if key.caseInsensitiveCompare(deviceId) == .orderedSame { return false }
            return true
        }
    }

    /// Explain why each Bonjour row is accepted/rejected while waiting for device 2+.
    private static func logBonjourCandidates(
        devices: [BLEDevice],
        knownBefore: Set<String>,
        since: Date,
        targetName: String,
        targetBLE: String
    ) {
        let wifi = devices.filter { $0.deviceType == .wifi }
        DeviceConsole.log(
            .provision,
            "Bonjour tick wifiRows=\(wifi.count) targetName=\(targetName) targetBLE=\(targetBLE)"
        )
        for device in wifi {
            let txtId = (device.txtRecord?["deviceId"] ?? "").uppercased()
            let alreadyKnown =
                Self.isKnownOnlineId(device.uuid, in: knownBefore)
                || (!txtId.isEmpty && Self.isKnownOnlineId(txtId, in: knownBefore))
            let nameOK = LimiDeviceNaming.isAllowedDeviceName(device.name)
            let lastSeenOK: Bool = {
                guard let lastSeen = device.lastSeen else { return true }
                return lastSeen >= since.addingTimeInterval(-5)
            }()
            let wouldMatch =
                device.reachability == .online
                && nameOK
                && !alreadyKnown
                && lastSeenOK
            DeviceConsole.log(
                .provision,
                "  candidate name=\(device.name) uuid=\(device.uuid) deviceId=\(txtId.isEmpty ? "-" : txtId) reach=\(device.reachability.rawValue) nameOK=\(nameOK) alreadyKnown=\(alreadyKnown) lastSeenOK=\(lastSeenOK) → \(wouldMatch ? "MATCH" : "skip")"
            )
        }
    }

    private static func findNewOnlineBonjourDevice(
        in devices: [BLEDevice],
        bleAdvertisedName: String,
        bleDeviceId: String,
        knownBefore: Set<String>,
        since: Date
    ) -> BLEDevice? {
        // Prefer a name match with the BLE target when multiple NEW boards appear.
        let candidates = devices.filter { device in
            guard device.deviceType == .wifi, device.reachability == .online else { return false }
            guard LimiDeviceNaming.isAllowedDeviceName(device.name) else { return false }

            let txtId = (device.txtRecord?["deviceId"] ?? "").uppercased()
            if Self.isKnownOnlineId(device.uuid, in: knownBefore) { return false }
            if !txtId.isEmpty, Self.isKnownOnlineId(txtId, in: knownBefore) { return false }

            if let lastSeen = device.lastSeen {
                return lastSeen >= since.addingTimeInterval(-5)
            }
            return true
        }

        if candidates.isEmpty { return nil }

        if let named = candidates.first(where: {
            $0.name.caseInsensitiveCompare(bleAdvertisedName) == .orderedSame
        }) {
            DeviceConsole.log(
                .provision,
                "pick Bonjour by BLE name match name=\(named.name) (bleTarget=\(bleAdvertisedName) bleUUID=\(bleDeviceId))"
            )
            return named
        }

        let first = candidates[0]
        DeviceConsole.log(
            .provision,
            "pick Bonjour FIRST new online name=\(first.name) id=\(first.txtRecord?["deviceId"] ?? first.uuid) — no exact name match for bleTarget=\(bleAdvertisedName) (candidates=\(candidates.count))"
        )
        return first
    }

    private static func outcome(
        from device: BLEDevice,
        fallbackName: String,
        blePeripheralUUID: String
    ) -> WiFiProvisioningOutcome {
        let resolvedId = LimiDeviceNaming.normalizedHardwareId(
            device.txtRecord?["deviceId"] ?? device.uuid
        )
        return WiFiProvisioningOutcome(
            deviceName: device.name.isEmpty ? fallbackName : device.name,
            deviceId: resolvedId,
            blePeripheralUUID: blePeripheralUUID,
            wifiDevice: device
        )
    }

    // MARK: - Master device (sequential multi-hub provisioning)

    /// Provisions each member hub in a virtual master group over BLE, one at a time.
    func provisionMasterGroup(
        master: VirtualMasterScanMetadata,
        ssid: String,
        password: String,
        skipAlreadyOnline: Bool = false,
        networkJoinTimeout: TimeInterval = defaultNetworkJoinTimeout,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<[WiFiProvisioningOutcome], WiFiProvisioningFailure>) -> Void
    ) {
        if isRunning {
            completion(.failure(.cancelled))
            return
        }

        let hardwareIds = master.memberHardwareIds.map { LimiDeviceNaming.normalizedHardwareId($0) }
        guard !hardwareIds.isEmpty else {
            completion(.failure(.credentialTransferFailed("No master hubs available to configure.")))
            return
        }

        isRunning = true
        WiFiProvisioningActivityGate.setActive(true)
        Task { @MainActor in
            BLECloudFallbackService.shared.cancelAllPreparing()
            BluetoothManager.shared.disconnectCurrentDevice(suppressReconnect: true)
        }
        BonjourServiceBrowser.shared.startBrowsing()
        LightControllingSocket.shared.connect()
        BluetoothManager.shared.refreshScan()

        DeviceConsole.banner("MASTER PROVISION START hubs=\(hardwareIds.count) skipOnline=\(skipAlreadyOnline)")

        Task { @MainActor in
            // Let Bonjour + MQTT settle so already-online hubs are skipped (not re-provisioned).
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard self.isRunning else {
                completion(.failure(.cancelled))
                return
            }

            await self.runMasterProvisionFlow(
                master: master,
                hardwareIds: hardwareIds,
                ssid: ssid,
                password: password,
                skipAlreadyOnline: skipAlreadyOnline,
                networkJoinTimeout: networkJoinTimeout,
                onPhaseUpdate: onPhaseUpdate,
                completion: completion
            )
        }
    }

    /// Simple master flow: skip LAN-online members → BLE Wi‑Fi each remaining hub → wait for ALL members online.
    private func runMasterProvisionFlow(
        master: VirtualMasterScanMetadata,
        hardwareIds: [String],
        ssid: String,
        password: String,
        skipAlreadyOnline: Bool,
        networkJoinTimeout: TimeInterval,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<[WiFiProvisioningOutcome], WiFiProvisioningFailure>) -> Void
    ) async {
        guard isRunning else {
            completion(.failure(.cancelled))
            return
        }

        Self.logMasterMemberStatuses(hardwareIds, label: "after settle")

        if skipAlreadyOnline {
            try? await Task.sleep(nanoseconds: 500_000_000)
            Self.logMasterMemberStatuses(hardwareIds, label: "after preflight")
        }

        let alreadyOnline = Set(hardwareIds.filter { skipAlreadyOnline && Self.isMasterMemberAlreadyOnline($0) })
        let needsBLE = hardwareIds.filter { !alreadyOnline.contains($0) }

        if needsBLE.isEmpty {
            DeviceConsole.log(.provision, "MASTER plan — all members already provisioned, skip BLE")
            onPhaseUpdate("Credentials confirmed")
            let outcomes = hardwareIds.compactMap { Self.skippedMemberOutcome(hardwareId: $0) }
            DeviceConsole.banner("MASTER PROVISION SUCCESS count=\(outcomes.count) (skip BLE)")
            finishRunning()
            completion(.success(outcomes))
            return
        }

        DeviceConsole.log(
            .provision,
            "MASTER plan total=\(hardwareIds.count) alreadyOnline=\(alreadyOnline.sorted().joined(separator: ",")) needsBLE=\(needsBLE.joined(separator: ","))"
        )

        var usedBleUUIDs = Set<String>()

        for (index, memberId) in needsBLE.enumerated() {
            guard isRunning else {
                completion(.failure(.cancelled))
                return
            }

            let step = index + 1
            let label = "Hub \(step) of \(needsBLE.count)"
            onPhaseUpdate("\(label): Checking…")
            BluetoothManager.shared.refreshScan()
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            guard isRunning else {
                completion(.failure(.cancelled))
                return
            }

            guard let target = Self.resolveMasterBLETarget(
                hardwareId: memberId,
                master: master,
                usedBleUUIDs: usedBleUUIDs
            ) else {
                DeviceConsole.log(.provision, "MASTER FAIL — no BLE for \(label) member=\(memberId)")
                finishRunning()
                completion(.failure(.credentialTransferFailed(
                    "Could not find \(label) over Bluetooth. Stay near the hub and try again."
                )))
                return
            }

            DeviceConsole.log(
                .provision,
                "MASTER \(label) BLE member=\(memberId) uuid=\(target.bleUUID) name=\(target.bleName)"
            )

            onPhaseUpdate("\(label): Connecting over Bluetooth…")
            BluetoothManager.shared.clearProvisioningCharacteristics()
            BluetoothManager.shared.disconnectCurrentDevice(suppressReconnect: true)
            BluetoothManager.shared.refreshScan()
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            let connected = await Self.waitForMasterBLEConnect(
                name: target.bleName,
                uuid: target.bleUUID,
                timeout: 35
            )
            guard connected else {
                DeviceConsole.log(.provision, "MASTER FAIL — BLE timeout \(label) ble=\(target.bleUUID)")
                finishRunning()
                completion(.failure(.credentialTransferFailed("Could not connect to \(label) over Bluetooth.")))
                return
            }

            onPhaseUpdate("\(label): Preparing Bluetooth…")
            let ready = await BluetoothManager.shared.waitForProvisioningReady(
                peripheralUUID: target.bleUUID,
                timeout: 25
            )
            guard ready else {
                finishRunning()
                completion(.failure(.credentialTransferFailed("Could not prepare \(label) for Wi‑Fi setup.")))
                return
            }

            onPhaseUpdate("\(label): Sending Wi‑Fi name and password…")
            let sent = await Self.sendMasterWifiCredentials(
                ssid: ssid,
                password: password,
                peripheralUUID: target.bleUUID
            )
            guard sent else {
                finishRunning()
                completion(.failure(.credentialTransferFailed("Could not send Wi‑Fi credentials to \(label).")))
                return
            }

            BluetoothManager.shared.disconnectPeripheral(
                uuidString: target.bleUUID,
                suppressReconnect: true
            )
            usedBleUUIDs.insert(target.bleUUID)
            ConfiguredBLEDeviceStore.shared.remember(
                hardwareId: memberId,
                blePeripheralUUID: target.bleUUID,
                displayName: target.displayName
            )
            DeviceConsole.log(.provision, "MASTER \(label) credentials confirmed member=\(memberId) ble=\(target.bleUUID)")
            onPhaseUpdate("\(label): Credentials confirmed")
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        onPhaseUpdate("Credentials confirmed")
        let outcomes = hardwareIds.compactMap { Self.skippedMemberOutcome(hardwareId: $0) }
        DeviceConsole.banner("MASTER PROVISION SUCCESS count=\(outcomes.count)")
        finishRunning()
        completion(.success(outcomes))
    }

    private static func logMasterMemberStatuses(_ hardwareIds: [String], label: String) {
        for id in hardwareIds {
            let mqtt = DeviceTransportRegistry.shared.state(for: id).mqttConnected
            let lan = VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: id)
            let online = isMasterMemberAlreadyOnline(id)
            DeviceConsole.log(
                .provision,
                "MASTER \(label) member=\(id) online=\(online) mqtt=\(mqtt) lan=\(lan)"
            )
        }
    }

    private static func sendMasterWifiCredentials(
        ssid: String,
        password: String,
        peripheralUUID: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false
            BluetoothManager.shared.provisionWifi(
                ssid: ssid,
                password: password,
                expectedPeripheralUUID: peripheralUUID
            ) { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: result.status != "error")
            }
        }
    }

    private static func waitForMasterBLEConnect(name: String, uuid: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if BluetoothManager.shared.isLiveConnected(forPeripheralUUID: uuid) {
                return true
            }
            if BluetoothManager.shared.hasRecentAdvertisement(forPeripheralUUID: uuid, within: 12) {
                BluetoothManager.shared.selectAndConnect(name: name, uuidString: uuid)
            } else {
                BluetoothManager.shared.refreshScan()
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        return BluetoothManager.shared.isLiveConnected(forPeripheralUUID: uuid)
    }

    /// After all BLE credentials are sent, require every master member MAC to be online (MQTT or LAN).
    private func waitForAllMasterMembersOnline(
        memberIds: [String],
        timeout: TimeInterval,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<Void, WiFiProvisioningFailure>) -> Void
    ) {
        let required = memberIds.map { LimiDeviceNaming.normalizedHardwareId($0) }.filter { !$0.isEmpty }
        let browser = BonjourServiceBrowser.shared
        var finished = false
        var pollTask: Task<Void, Never>?

        func allOnline() -> Bool {
            required.allSatisfy { Self.isMasterMemberAlreadyOnline($0) }
        }

        func finish(_ result: Result<Void, WiFiProvisioningFailure>) {
            guard !finished else { return }
            finished = true
            timeoutTask?.cancel()
            pollTask?.cancel()
            completion(result)
        }

        if allOnline() {
            DeviceConsole.log(.provision, "MASTER all members already online")
            finish(.success(()))
            return
        }

        let pending = required.filter { !Self.isMasterMemberAlreadyOnline($0) }
        onPhaseUpdate("Waiting for all hubs (\(pending.count) remaining)…")
        DeviceConsole.log(
            .provision,
            "MASTER final wait up to \(Int(timeout))s for all members pending=\(pending.joined(separator: ","))"
        )

        pollTask = Task { @MainActor in
            while !Task.isCancelled, self.isRunning, !finished {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, self.isRunning, !finished else { return }
                if allOnline() {
                    DeviceConsole.log(.provision, "MASTER final wait — all members online (poll)")
                    finish(.success(()))
                    return
                }
            }
        }

        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled, self.isRunning, !finished else { return }
            let stillPending = required.filter { !Self.isMasterMemberAlreadyOnline($0) }
            DeviceConsole.log(.provision, "MASTER final wait TIMEOUT still=\(stillPending.joined(separator: ","))")
            finish(.failure(.networkJoinTimeout))
        }

        var bonjourSink: AnyCancellable?
        bonjourSink = browser.$discoveredWiFiDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isRunning, !finished else { return }
                if allOnline() {
                    DeviceConsole.log(.provision, "MASTER final wait — all members online (Bonjour)")
                    bonjourSink?.cancel()
                    finish(.success(()))
                }
            }

        var mqttSink: AnyCancellable?
        mqttSink = SocketIOMQTTBridge.shared.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, self.isRunning, !finished else { return }
                guard update.connected else { return }
                let id = LimiDeviceNaming.normalizedHardwareId(update.deviceId)
                guard required.contains(id) else { return }
                if allOnline() {
                    DeviceConsole.log(.provision, "MASTER final wait — all members online (MQTT)")
                    mqttSink?.cancel()
                    bonjourSink?.cancel()
                    finish(.success(()))
                }
            }

        var registrySink: AnyCancellable?
        registrySink = DeviceTransportRegistry.shared.presenceChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, self.isRunning, !finished else { return }
                guard update.connected else { return }
                let id = LimiDeviceNaming.normalizedHardwareId(update.deviceId)
                guard required.contains(id) else { return }
                if allOnline() {
                    DeviceConsole.log(.provision, "MASTER final wait — all members online (registry)")
                    registrySink?.cancel()
                    finish(.success(()))
                }
            }

        let handler: (String, String) -> Void = { [weak self] deviceId, status in
            Task { @MainActor in
                guard let self, self.isRunning, !finished else { return }
                let id = LimiDeviceNaming.normalizedHardwareId(deviceId)
                guard required.contains(id) else { return }
                let online = LimiDeviceNaming.isOnlinePresenceStatus(status)
                Self.applyMemberPresenceUpdate(deviceId: id, mqttConnected: online)
                guard online else { return }
                if allOnline() {
                    DeviceConsole.log(.provision, "MASTER final wait — all members online (SocketPresence)")
                    finish(.success(()))
                }
            }
        }
        if let token = presenceHandlerToken {
            LightControllingSocket.shared.unregisterPresenceHandler(token)
        }
        presenceHandlerToken = LightControllingSocket.shared.registerPresenceHandler(handler)

        if let bonjourSink { cancellables.insert(bonjourSink) }
        if let mqttSink { cancellables.insert(mqttSink) }
        if let registrySink { cancellables.insert(registrySink) }
    }

    private static func applyMemberPresenceUpdate(deviceId: String, mqttConnected: Bool) {
        let hw = LimiDeviceNaming.normalizedHardwareId(deviceId)
        guard !hw.isEmpty else { return }
        DeviceTransportRegistry.shared.state(for: hw).updateMQTTPresence(connected: mqttConnected)
        CloudPresenceMemory.shared.record(deviceId: hw, connected: mqttConnected)
        PresenceSnapshotStore.shared.record(
            deviceId: hw,
            isOnline: mqttConnected,
            path: mqttConnected ? .cloud : .offline
        )
    }

    private static func resolveHardwareIdForBLE(deviceName: String, blePeripheralUUID: String) -> String {
        let fromName = LimiDeviceNaming.normalizedHardwareId(deviceName)
        if fromName.count == 12, fromName.allSatisfy(\.isHexDigit) {
            return fromName
        }
        if let record = ConfiguredBLEDeviceStore.shared.allRecords.first(where: {
            $0.blePeripheralUUID.caseInsensitiveCompare(blePeripheralUUID) == .orderedSame
        }) {
            return record.hardwareId
        }
        for entry in BluetoothManager.shared.discoveredDevices {
            guard entry.id.caseInsensitiveCompare(blePeripheralUUID) == .orderedSame else {
                continue
            }
            let hw = LimiDeviceNaming.normalizedHardwareId(entry.name)
            if hw.count == 12, hw.allSatisfy(\.isHexDigit) {
                return hw
            }
        }
        return ""
    }

    private static func credentialConfirmedOutcome(
        deviceName: String,
        blePeripheralUUID: String,
        hardwareId: String? = nil
    ) -> WiFiProvisioningOutcome {
        let resolvedHardwareId: String = {
            if let hardwareId {
                let normalized = LimiDeviceNaming.normalizedHardwareId(hardwareId)
                if !normalized.isEmpty { return normalized }
            }
            return resolveHardwareIdForBLE(deviceName: deviceName, blePeripheralUUID: blePeripheralUUID)
        }()
        let displayName = deviceName.isEmpty ? "LIMI Device" : deviceName
        let wifiDevice = BLEDevice(
            name: displayName,
            uuid: resolvedHardwareId.isEmpty ? blePeripheralUUID : resolvedHardwareId,
            deviceType: .wifi,
            txtRecord: resolvedHardwareId.isEmpty ? nil : ["deviceId": "limi1ch-\(resolvedHardwareId)"],
            reachability: .offline,
            lastSeen: nil
        )
        return WiFiProvisioningOutcome(
            deviceName: displayName,
            deviceId: resolvedHardwareId,
            blePeripheralUUID: blePeripheralUUID,
            wifiDevice: wifiDevice
        )
    }

    private static func skippedMemberOutcome(hardwareId: String) -> WiFiProvisioningOutcome? {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return nil }
        let bleUUID = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: hw) ?? ""
        let displayName = ConfiguredBLEDeviceStore.shared.record(for: hw)?.displayName ?? "LIMI Device"
        let wifiRow = BonjourServiceBrowser.shared.discoveredWiFiDevices.first {
            $0.deviceType == .wifi
                && $0.resolvedHardwareId() == hw
                && (
                    $0.reachability == .online
                        || !($0.ipAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                )
        }
        let wifiDevice = wifiRow ?? BLEDevice(
            name: displayName,
            uuid: hw,
            deviceType: .wifi,
            txtRecord: ["deviceId": "limi1ch-\(hw)"],
            reachability: .offline,
            lastSeen: nil
        )
        return WiFiProvisioningOutcome(
            deviceName: wifiDevice.name.isEmpty ? displayName : wifiDevice.name,
            deviceId: hw,
            blePeripheralUUID: bleUUID,
            wifiDevice: wifiDevice
        )
    }

    private func waitForHardwareOnline(
        hardwareId: String,
        knownBonjourKeys: Set<String>,
        since: Date,
        timeout: TimeInterval,
        onPhaseUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<BLEDevice, WiFiProvisioningFailure>) -> Void
    ) {
        let normalized = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        let browser = BonjourServiceBrowser.shared
        var finished = false

        func finish(_ result: Result<BLEDevice, WiFiProvisioningFailure>) {
            guard !finished else { return }
            finished = true
            timeoutTask?.cancel()
            completion(result)
        }

        func syntheticOnline(name: String = "LIMI Device") -> BLEDevice {
            BLEDevice(
                name: name,
                uuid: normalized,
                deviceType: .wifi,
                txtRecord: ["deviceId": "limi1ch-\(normalized)"],
                reachability: .online,
                lastSeen: Date()
            )
        }

        if let match = Self.findOnlineDevice(withHardwareId: normalized, in: browser.discoveredWiFiDevices) {
            DeviceConsole.log(.provision, "MASTER wait — already on Bonjour id=\(normalized)")
            finish(.success(match))
            return
        }
        // Target-specific wait: accept live MQTT even if the id was briefly seen earlier.
        if DeviceTransportRegistry.shared.state(for: normalized).mqttConnected {
            DeviceConsole.log(.provision, "MASTER wait — already MQTT online id=\(normalized)")
            finish(.success(syntheticOnline()))
            return
        }

        onPhaseUpdate("Waiting for hub to come online…")
        DeviceConsole.log(
            .provision,
            "MASTER wait up to \(Int(timeout))s for hardwareId=\(normalized) (siblingSkip=\(knownBonjourKeys.count))"
        )
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled, self.isRunning, !finished else { return }
            DeviceConsole.dumpBonjourOnline(reason: "MASTER wait TIMEOUT")
            DeviceConsole.log(.provision, "MASTER wait TIMEOUT id=\(normalized)")
            self.finishRunning()
            finish(.failure(.networkJoinTimeout))
        }

        var bonjourSink: AnyCancellable?
        bonjourSink = browser.$discoveredWiFiDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self, self.isRunning, !finished else { return }
                if let match = Self.findOnlineDevice(withHardwareId: normalized, in: devices) {
                    DeviceConsole.log(.provision, "MASTER wait confirmed Bonjour id=\(normalized)")
                    bonjourSink?.cancel()
                    finish(.success(match))
                }
            }

        var mqttSink: AnyCancellable?
        mqttSink = SocketIOMQTTBridge.shared.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, self.isRunning, !finished else { return }
                let id = LimiDeviceNaming.normalizedHardwareId(update.deviceId)
                DeviceConsole.log(
                    .provision,
                    "MASTER wait MQTT event id=\(update.deviceId) connected=\(update.connected) want=\(normalized)"
                )
                guard update.connected, id == normalized else { return }
                DeviceConsole.log(.provision, "MASTER wait confirmed MQTT id=\(normalized)")
                mqttSink?.cancel()
                bonjourSink?.cancel()
                finish(.success(syntheticOnline()))
            }

        // Socket.IO presence can arrive without republishing on the Combine bridge.
        let handler: (String, String) -> Void = { [weak self] deviceId, status in
            Task { @MainActor in
                guard let self, self.isRunning, !finished else { return }
                let id = LimiDeviceNaming.normalizedHardwareId(deviceId)
                guard id == normalized else { return }
                DeviceConsole.log(.provision, "MASTER wait socket presence id=\(id) status=\(status)")
                guard LimiDeviceNaming.isOnlinePresenceStatus(status) else { return }
                DeviceConsole.log(.provision, "MASTER wait confirmed SocketPresence id=\(normalized)")
                finish(.success(syntheticOnline()))
            }
        }
        if let token = presenceHandlerToken {
            LightControllingSocket.shared.unregisterPresenceHandler(token)
        }
        presenceHandlerToken = LightControllingSocket.shared.registerPresenceHandler(handler)

        if let bonjourSink { cancellables.insert(bonjourSink) }
        if let mqttSink { cancellables.insert(mqttSink) }
    }

    private static func findOnlineDevice(withHardwareId hardwareId: String, in devices: [BLEDevice]) -> BLEDevice? {
        devices.first { device in
            device.deviceType == .wifi
                && device.reachability == .online
                && device.resolvedHardwareId() == hardwareId
        }
    }

    private static func waitForBLEConnection(name: String, uuid: String, timeout: TimeInterval) async -> Bool {
        BluetoothManager.shared.selectAndConnect(name: name, uuidString: uuid)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if BluetoothManager.shared.isLiveConnected(forPeripheralUUID: uuid) {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return BluetoothManager.shared.isLiveConnected(forPeripheralUUID: uuid)
    }

    private struct MasterProvisionTarget {
        let hardwareId: String
        let displayName: String
        let bleName: String
        let bleUUID: String
    }

    /// First pending master member + BLE peripheral for Add Device Wi‑Fi list (same rules as provisioning).
    static func preferredMasterBLETarget(
        master: VirtualMasterScanMetadata,
        usedBleUUIDs: Set<String> = []
    ) -> (hardwareId: String, bleName: String, bleUUID: String)? {
        let pending = master.memberHardwareIds
            .map { LimiDeviceNaming.normalizedHardwareId($0) }
            .filter { !$0.isEmpty }
            .filter { !isMasterMemberAlreadyOnline($0) }
        for hw in pending {
            if let target = resolveMasterBLETarget(
                hardwareId: hw,
                master: master,
                usedBleUUIDs: usedBleUUIDs
            ) {
                return (target.hardwareId, target.bleName, target.bleUUID)
            }
        }
        return nil
    }

    private static func isMasterMemberAlreadyOnline(_ hardwareId: String) -> Bool {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        guard !hw.isEmpty else { return false }

        // A hub whose cloud link is NOT live (no fresh heartbeat) but which is present over
        // BLE (advertising / connected) has dropped Wi‑Fi and is a provisioning candidate.
        // Never let a *stale* cloud cache (raw mqttConnected / lastPresence snapshot that the
        // Add Device flow can't clear while it holds the radio) filter it out — that made the
        // Wi‑Fi list refuse to load after a live Wi‑Fi→BLE switch on the Add Device screen.
        if !VirtualMasterPresence.isLiveCloudOnline(hardwareId: hw),
           BLECloudFallbackService.shared.presenceKind(for: hw) != .unreachable {
            return false
        }

        if DeviceTransportRegistry.shared.state(for: hw).mqttConnected { return true }

        if VirtualMasterPresence.effectiveCloudOnline(hardwareId: hw) { return true }

        if DeviceTransportRegistry.shared.presenceSnapshot().contains(where: {
            LimiDeviceNaming.normalizedHardwareId($0.deviceId) == hw && $0.connected
        }) {
            return true
        }

        if VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw) { return true }

        if VirtualMasterPresence.isMemberAdvertisedOnLAN(hardwareId: hw) { return true }

        if let snap = PresenceSnapshotStore.shared.snapshot(for: hw),
           snap.isOnline,
           snap.age <= PresenceSnapshotStore.staleOnlineTTL {
            switch snap.path {
            case .cloud, .local:
                return true
            default:
                break
            }
        }

        return false
    }

    private static func bleUUIDsReservedForOtherMembers(
        hardwareId: String,
        memberHardwareIds: [String]
    ) -> Set<String> {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        var reserved = Set<String>()
        for member in memberHardwareIds {
            let memberHw = LimiDeviceNaming.normalizedHardwareId(member)
            guard memberHw != hw else { continue }
            if let uuid = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: memberHw) {
                reserved.insert(uuid)
            }
        }
        return reserved
    }

    private static func hardwareIdForStoredBLE(uuid: String) -> String? {
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            guard ConfiguredBLEDeviceStore.isUsablePeripheralUUID(
                record.blePeripheralUUID,
                forHardwareId: record.hardwareId
            ) else { continue }
            if record.blePeripheralUUID.caseInsensitiveCompare(uuid) == .orderedSame {
                return LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            }
        }
        return nil
    }

    private static func isBLEUUIDAvailableForMember(
        uuid: String,
        hardwareId: String,
        memberHardwareIds: [String],
        usedBleUUIDs: Set<String>
    ) -> Bool {
        guard LimiDeviceNaming.isValidPeripheralUUID(uuid) else { return false }
        guard !usedBleUUIDs.contains(uuid) else { return false }
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        if let owner = hardwareIdForStoredBLE(uuid: uuid) {
            return owner == hw
        }
        let reserved = bleUUIDsReservedForOtherMembers(
            hardwareId: hw,
            memberHardwareIds: memberHardwareIds
        )
        return !reserved.contains(uuid)
    }

    /// Live BLE peripherals for one master member — unmapped hubs first; never another member's stored UUID.
    private static func liveMasterBLECandidates(
        forHardwareId hardwareId: String,
        master: VirtualMasterScanMetadata,
        excluding usedBleUUIDs: Set<String>
    ) -> [(name: String, uuid: String)] {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        var raw: [(name: String, uuid: String)] = []
        var seen = Set<String>()

        func consider(name: String, uuid: String) {
            guard isBLEUUIDAvailableForMember(
                uuid: uuid,
                hardwareId: hw,
                memberHardwareIds: master.memberHardwareIds,
                usedBleUUIDs: usedBleUUIDs
            ) else { return }
            guard seen.insert(uuid).inserted else { return }
            raw.append((name, uuid))
        }

        for ble in master.memberDevices where ble.deviceType == .bluetooth {
            consider(name: ble.name, uuid: ble.uuid)
        }
        for entry in BluetoothManager.shared.discoveredDevices {
            guard LimiDeviceNaming.isBLEProvisioningHubName(entry.name) else { continue }
            consider(name: entry.name, uuid: entry.id)
        }
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            guard ConfiguredBLEDeviceStore.isUsablePeripheralUUID(
                record.blePeripheralUUID,
                forHardwareId: record.hardwareId
            ) else { continue }
            consider(name: record.displayName, uuid: record.blePeripheralUUID)
        }

        let ranked = raw.map { item -> (name: String, uuid: String, rank: Int) in
            let rank: Int
            if let owner = hardwareIdForStoredBLE(uuid: item.uuid) {
                rank = owner == hw ? 1 : 2
            } else {
                rank = 0
            }
            return (item.name, item.uuid, rank)
        }
        return ranked
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.uuid < rhs.uuid
            }
            .map { ($0.name, $0.uuid) }
    }

    /// Resolves BLE name/UUID for one master member — never reuse another member's peripheral.
    private static func resolveMasterBLETarget(
        hardwareId: String,
        master: VirtualMasterScanMetadata,
        usedBleUUIDs: Set<String>
    ) -> MasterProvisionTarget? {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        let memberRow = master.memberDevices.first { $0.resolvedHardwareId() == hw }
        let displayName = memberRow?.name.isEmpty == false ? memberRow!.name : "LIMI Device"
        let reservedOther = bleUUIDsReservedForOtherMembers(
            hardwareId: hw,
            memberHardwareIds: master.memberHardwareIds
        )

        if let stored = ConfiguredBLEDeviceStore.shared.blePeripheralUUID(for: hw),
           isBLEUUIDAvailableForMember(
               uuid: stored,
               hardwareId: hw,
               memberHardwareIds: master.memberHardwareIds,
               usedBleUUIDs: usedBleUUIDs
           ) {
            DeviceConsole.log(.provision, "MASTER resolve store id=\(hw) ble=\(stored)")
            return MasterProvisionTarget(
                hardwareId: hw,
                displayName: displayName,
                bleName: ConfiguredBLEDeviceStore.shared.record(for: hw)?.displayName ?? displayName,
                bleUUID: stored
            )
        }

        if let ble = memberRow, ble.deviceType == .bluetooth,
           isBLEUUIDAvailableForMember(
               uuid: ble.uuid,
               hardwareId: hw,
               memberHardwareIds: master.memberHardwareIds,
               usedBleUUIDs: usedBleUUIDs
           ) {
            DeviceConsole.log(.provision, "MASTER resolve member scan id=\(hw) ble=\(ble.uuid)")
            return MasterProvisionTarget(
                hardwareId: hw,
                displayName: displayName,
                bleName: ble.name,
                bleUUID: ble.uuid
            )
        }

        if let live = liveMasterBLECandidates(
            forHardwareId: hw,
            master: master,
            excluding: usedBleUUIDs
        ).first {
            DeviceConsole.log(
                .provision,
                "MASTER resolve live scan id=\(hw) ble=\(live.uuid) name=\(live.name) reservedOther=\(reservedOther.sorted().joined(separator: ","))"
            )
            return MasterProvisionTarget(
                hardwareId: hw,
                displayName: live.name,
                bleName: live.name,
                bleUUID: live.uuid
            )
        }

        DeviceConsole.log(
            .provision,
            "MASTER resolve FAIL — no live BLE for hardwareId=\(hw) used=\(usedBleUUIDs.count) reservedOther=\(reservedOther.sorted().joined(separator: ","))"
        )
        return nil
    }
}
