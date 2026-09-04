import SwiftUI
import Combine

final class DemoScanDevicesViewModel: ObservableObject {
    @Published private(set) var scannedDevices: [BLEDevice] = []
    @Published private(set) var orderedDevices: [BLEDevice] = []
    @Published private(set) var shouldShowContinue = false

    @Published var showAddWifi = false
    /// Signals a unified add-device flow to push the Wi-Fi list step (no nested modal).
    @Published private(set) var wifiProvisioningRequested = false
    @Published var selectedName: String?
    @Published var selectedId: String?
    @Published var selectedChannelMac = ""
    @Published var isShowingPWM2LEDSheet = false
    @Published var isShowingRGBDataSheet = false
    @Published var showLiginSkip = false
    @Published var ssidNameArray: [String] = []
    @Published var isConnectingToBLE = false
    @Published private(set) var isBLEConnected = false
    @Published private(set) var lastDisconnectedBLEDeviceID: String?
    /// Set when BLE connect / Wi‑Fi list read fails so Add Device can leave the Connecting overlay.
    @Published private(set) var bleConnectError: String?
    /// Set when user picks a virtual master row — drives sequential BLE provisioning.
    @Published private(set) var selectedVirtualMaster: VirtualMasterScanMetadata?
    /// True while unconfigured hubs are being identified over BLE (connect → read MAC).
    @Published private(set) var isResolvingIdentities = false
    /// False while identification is still in progress — used to hide not-yet-identified
    /// hubs so an unresolved hub is never shown as an "individual" device prematurely.
    @Published private(set) var identitiesSettled = true

    /// Fired after a new peripheral→MAC mapping is learned so DeviceApp can re-sync
    /// cloud virtual-group specs (kept as a closure to avoid a DeviceApp dependency here).
    var onIdentityResolved: (() -> Void)?

    /// Resolves unconfigured hub MACs over BLE (F001) so scan rows can fold into hubs.
    let identityResolver = BLEIdentityResolver()

    private var virtualGroupingSpecs: [VirtualDeviceGroupingSpec] = []
    private var virtualDeviceIDForGrouping: String = ""

    private let allowedNames: Set<String>
    private let ble: DemoScanBluetoothControlling
    private let bonjour: BonjourWiFiBrowsing
    private var bleMissedCycles: [String: Int] = [:]
    private var bleDisconnectedRecently = Set<String>()
    private var cancellables: Set<AnyCancellable> = []
    private var presenceTimer: AnyCancellable?
    private var scanRefreshTimer: AnyCancellable?
    private var lastScanListLogAt: Date = .distantPast
    private var bleConnectWaitTask: Task<Void, Never>?
    private var isReadingWifiList = false

    private let bleCycleInterval: TimeInterval = 5.0
    private let bleGreyAfterCycles = 2
    private let bleRemoveAfterCycles = 3
    private let bleConnectTimeout: TimeInterval = 25
    private let wifiListReadTimeout: TimeInterval = 20

    init(
        ble: DemoScanBluetoothControlling = DemoScanBluetoothAdapter(),
        bonjour: BonjourWiFiBrowsing = BonjourServiceBrowser.shared,
        allowedNames: Set<String> = LimiDeviceNaming.knownHubNames
    ) {
        self.ble = ble
        self.bonjour = bonjour
        self.allowedNames = allowedNames

        wireLiveObservers()
        wireIdentityResolver()

        $scannedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildDeviceList() }
            .store(in: &cancellables)
    }

    private func wireIdentityResolver() {
        identityResolver.onResolved = { [weak self] in
            guard let self else { return }
            self.rebuildDeviceList()
            self.onIdentityResolved?()
        }
        identityResolver.$isBusy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] busy in
                guard let self else { return }
                self.isResolvingIdentities = busy
                // When resolving settles, refresh so gated hub cards become tappable.
                self.rebuildDeviceList()
            }
            .store(in: &cancellables)
        identityResolver.$isSettled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settled in
                guard let self else { return }
                self.identitiesSettled = settled
                // Reveal / hide not-yet-identified hubs as the settled state flips.
                self.rebuildDeviceList()
            }
            .store(in: &cancellables)
    }

    /// Same rules as Home: exact hub names, `limi1ch-*`, and `LIMI Device` / `LIMI Device-2`.
    private func isAllowedScanName(_ name: String) -> Bool {
        LimiDeviceNaming.isAllowedDeviceName(name) || allowedNames.contains(name)
    }

    /// Do not drop a live Bonjour row when reconnecting BLE to a hub that is already on Wi‑Fi.
    private func shouldSkipBonjourHandoverPurge(bleName: String, bleUUID: String) -> Bool {
        if AddDeviceFlowActivityGate.isActive || WiFiProvisioningActivityGate.isActive {
            DeviceConsole.log(.add, "skip Bonjour purge — Add Device / provision active ble=\(bleUUID)")
            return true
        }
        for record in ConfiguredBLEDeviceStore.shared.allRecords {
            guard record.blePeripheralUUID.caseInsensitiveCompare(bleUUID) == .orderedSame else { continue }
            let hw = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
            if VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw)
                || VirtualMasterPresence.effectiveCloudOnline(hardwareId: hw)
                || VirtualMasterPresence.isMemberAdvertisedOnLAN(hardwareId: hw) {
                DeviceConsole.log(
                    .add,
                    "skip Bonjour purge — hub already reachable hw=\(hw) ble=\(bleUUID)"
                )
                return true
            }
        }
        _ = bleName
        return false
    }

    func onAppear() {
        AddDeviceFlowActivityGate.setActive(true)
        Task { @MainActor in
            BLECloudFallbackService.shared.cancelAllPreparing()
        }
        ble.startScanning { [weak self] devices in
            DispatchQueue.main.async { self?.scannedDevices = devices }
        }
        // Clear stale Offline Bonjour ghosts before listing (factory-reset IP twins).
        if let browser = bonjour as? BonjourServiceBrowser {
            browser.purgeOfflineDevices(reason: "Add Device opened")
            browser.collapseDuplicateDevices(reason: "Add Device opened")
        }
        bonjour.startBrowsing()
        presenceTimer = Timer.publish(every: bleCycleInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateBLEPresence() }
        scanRefreshTimer = Timer.publish(every: 12, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.ble.refreshScan() }
        identityResolver.start()
        rebuildDeviceList()
    }

    private func wireLiveObservers() {
        if let browser = bonjour as? BonjourServiceBrowser {
            browser.$discoveredWiFiDevices
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildDeviceList() }
                .store(in: &cancellables)
        }

        if let adapter = ble as? DemoScanBluetoothAdapter {
            adapter.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    guard let self else { return }
                    self.isBLEConnected = connected
                    self.rebuildDeviceList()
                    if connected && self.isConnectingToBLE {
                        self.handleBLEConnected()
                    }
                }
                .store(in: &cancellables)

            adapter.$lastDisconnectedDeviceID
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.lastDisconnectedBLEDeviceID = $0 }
                .store(in: &cancellables)

            adapter.$isBluetoothOn
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildDeviceList() }
                .store(in: &cancellables)
        }
    }

    func onDisappear() {
        if !WiFiProvisioningActivityGate.isActive {
            AddDeviceFlowActivityGate.setActive(false)
        }
        ble.stopScanning()
        bonjour.stopBrowsing()
        presenceTimer?.cancel()
        presenceTimer = nil
        scanRefreshTimer?.cancel()
        scanRefreshTimer = nil
        identityResolver.stop()
    }

    /// Call from DeviceApp when virtual-device membership changes (Add Device scan grouping).
    func updateVirtualGrouping(groups: [VirtualDeviceGroupingSpec]) {
        virtualGroupingSpecs = groups
        rebuildDeviceList()
    }

    func updateVirtualGrouping(enabledHardwareIds: [String], virtualDeviceID: String) {
        if enabledHardwareIds.isEmpty {
            virtualGroupingSpecs = []
        } else {
            virtualGroupingSpecs = [
                VirtualDeviceGroupingSpec(
                    virtualDeviceID: virtualDeviceID,
                    memberHardwareIds: enabledHardwareIds,
                    displayName: VirtualDeviceGroupingSpec.hubDisplayName(
                        pendantCount: enabledHardwareIds.count
                    )
                )
            ]
        }
        virtualDeviceIDForGrouping = virtualDeviceID
        rebuildDeviceList()
    }

    func clearSelectedVirtualMaster() {
        selectedVirtualMaster = nil
    }

    func handleDisconnectedDeviceID(_ id: String?) {
        guard let id else { return }
        bleDisconnectedRecently.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.bleDisconnectedRecently.remove(id)
        }
    }

    func connectBLEDevice(name: String, id: String, virtualMaster: VirtualMasterScanMetadata? = nil) {
        bleConnectWaitTask?.cancel()
        bleConnectWaitTask = nil
        isReadingWifiList = false
        bleConnectError = nil
        // Free the radio for provisioning — pause background MAC resolution.
        identityResolver.stop()
        selectedVirtualMaster = virtualMaster
        if let virtualMaster {
            selectedName = VirtualDeviceGroupingSpec.hubDisplayName(
                pendantCount: virtualMaster.memberHardwareIds.count
            )
        } else {
            selectedName = name
        }
        selectedId = id
        ssidNameArray = []
        DeviceConsole.log(
            .add,
            "BLE connect request name=\(name) uuid=\(id) master=\(virtualMaster != nil) alreadyConnected=\(ble.isDeviceConnected(uuid: id)) live=\(BluetoothManager.shared.isLiveConnected(forPeripheralUUID: id))"
        )

        // Free the radio so Wi‑Fi list is read from THIS hub (master or single).
        let manager = BluetoothManager.shared
        for (uuid, entry) in manager.connectedDevices where entry.peripheral.state == .connected {
            if uuid.uuidString.caseInsensitiveCompare(id) != .orderedSame {
                DeviceConsole.log(.add, "disconnect other BLE \(uuid.uuidString) before selecting \(id)")
                manager.disconnectPeripheral(uuidString: uuid.uuidString, suppressReconnect: true)
            }
        }

        isConnectingToBLE = true
        if !shouldSkipBonjourHandoverPurge(bleName: name, bleUUID: id) {
            bonjour.removeCompletelyMatching(bleName: name, bleId: id)
        }

        if ble.isDeviceConnected(uuid: id) || manager.isLiveConnected(forPeripheralUUID: id) {
            handleBLEConnected()
            return
        }

        ble.selectAndConnect(name: name, uuidString: id)
        // `isConnected` often stays true across hubs — do not rely on false→true edge alone.
        bleConnectWaitTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(self.bleConnectTimeout)
            while Date() < deadline {
                if Task.isCancelled { return }
                guard self.isConnectingToBLE, self.selectedId == id else { return }
                if self.ble.isDeviceConnected(uuid: id)
                    || BluetoothManager.shared.isLiveConnected(forPeripheralUUID: id)
                {
                    DeviceConsole.log(.add, "BLE target live uuid=\(id) — proceeding to Wi‑Fi list")
                    self.handleBLEConnected()
                    return
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard self.isConnectingToBLE, self.selectedId == id else { return }
            DeviceConsole.log(.add, "BLE connect TIMEOUT uuid=\(id) master=\(virtualMaster != nil)")
            self.failBLEConnect(
                "Could not connect over Bluetooth. Stay near the hub and try again."
            )
        }
    }

    func handleBLEConnected() {
        let targetId = selectedId
        let liveOk: Bool = {
            guard let targetId else { return ble.isConnected }
            return BluetoothManager.shared.isLiveConnected(forPeripheralUUID: targetId)
                || ble.isDeviceConnected(uuid: targetId)
        }()
        guard liveOk, isConnectingToBLE else {
            DeviceConsole.log(
                .add,
                "handleBLEConnected skipped isConnecting=\(isConnectingToBLE) isConnected=\(ble.isConnected) target=\(targetId ?? "nil") live=\(targetId.map { BluetoothManager.shared.isLiveConnected(forPeripheralUUID: $0) } ?? false)"
            )
            return
        }
        guard !isReadingWifiList else {
            DeviceConsole.log(.add, "handleBLEConnected skipped — Wi‑Fi list read already in progress")
            return
        }
        isReadingWifiList = true
        bleConnectWaitTask?.cancel()
        bleConnectWaitTask = nil
        DeviceConsole.log(.add, "BLE connected — reading Wi-Fi list for \(selectedName ?? "?") / \(selectedId ?? "?")")

        let expectedUUID = targetId
        bleConnectWaitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.wifiListReadTimeout ?? 20) * 1_000_000_000)
            guard let self, self.isConnectingToBLE, self.isReadingWifiList else { return }
            DeviceConsole.log(.add, "Wi‑Fi list read TIMEOUT uuid=\(expectedUUID ?? "?")")
            self.failBLEConnect(
                "Connected over Bluetooth, but the Wi‑Fi list did not arrive. Try again."
            )
        }

        ble.readWifiList { [weak self] list in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isConnectingToBLE || self.isReadingWifiList else { return }
                self.bleConnectWaitTask?.cancel()
                self.bleConnectWaitTask = nil
                self.isReadingWifiList = false
                self.ssidNameArray = list
                self.isConnectingToBLE = false
                self.showAddWifi = true
                self.wifiProvisioningRequested = true
                DeviceConsole.log(.add, "Wi-Fi list received count=\(list.count) networks=\(list.joined(separator: " | "))")
            }
        }
    }

    private func failBLEConnect(_ message: String) {
        bleConnectWaitTask?.cancel()
        bleConnectWaitTask = nil
        isReadingWifiList = false
        isConnectingToBLE = false
        bleConnectError = message
        DeviceConsole.log(.add, "BLE connect failed — \(message)")
        // Back on the scan list — resume background MAC resolution.
        if AddDeviceFlowActivityGate.isActive { identityResolver.start() }
    }

    func clearBLEConnectError() {
        bleConnectError = nil
    }

    func acknowledgeWifiProvisioningNavigation() {
        wifiProvisioningRequested = false
    }

    func resetProvisioningSession() {
        bleConnectWaitTask?.cancel()
        bleConnectWaitTask = nil
        isReadingWifiList = false
        isConnectingToBLE = false
        bleConnectError = nil
        wifiProvisioningRequested = false
        showAddWifi = false
        ssidNameArray = []
        selectedVirtualMaster = nil
        // Returning to the scan list — resume background MAC resolution.
        if AddDeviceFlowActivityGate.isActive { identityResolver.start() }
    }

    func connectWiFiDevice(_ device: BLEDevice) {
        guard device.reachability == .online else { return }
        if let txt = device.txtRecord,
           let channelCountStr = txt["channelCount"],
           let channelCount = Int(channelCountStr),
           let channelMac = txt["deviceId"] {
            if channelCount == 1 {
                selectedChannelMac = channelMac
                isShowingPWM2LEDSheet = true
            } else {
                selectedName = device.name
                selectedId = device.uuid
                isShowingRGBDataSheet = true
            }
        } else {
            selectedName = device.name
            selectedId = device.uuid
            showAddWifi = true
            wifiProvisioningRequested = true
        }
    }

    func isDeviceConnected(_ device: BLEDevice) -> Bool {
        if let master = device.virtualMaster {
            let ids = master.memberHardwareIds
                .map { LimiDeviceNaming.normalizedHardwareId($0) }
                .filter { !$0.isEmpty }
            guard !ids.isEmpty else { return false }
            return ids.allSatisfy { VirtualMasterPresence.isMemberCloudOnline(hardwareId: $0) }
        }
        let hw = device.resolvedHardwareId()
        guard !hw.isEmpty else { return false }
        return VirtualMasterPresence.isMemberCloudOnline(hardwareId: hw)
    }

    private func memberIsConnected(_ device: BLEDevice) -> Bool {
        let hw = device.resolvedHardwareId()
        guard !hw.isEmpty else { return false }
        return VirtualMasterPresence.isMemberCloudOnline(hardwareId: hw)
    }

    func isDeviceDisabled(_ device: BLEDevice) -> Bool {
        if device.isVirtualMaster, let master = device.virtualMaster {
            let bleCandidates = master.memberDevices.filter { $0.deviceType == .bluetooth }
            let presence = VirtualMasterPresence.evaluate(
                memberHardwareIds: master.memberHardwareIds,
                isMQTTOnline: VirtualMasterPresence.defaultMQTTCheck,
                isBLEVisible: { hw in
                    VirtualMasterPresence.isBLEVisible(hardwareId: hw, scannedBLEDevices: bleCandidates)
                },
                isWiFiLANOnline: { hw in
                    if let member = master.memberDevices.first(where: { $0.resolvedHardwareId() == hw }) {
                        return member.deviceType == .wifi && member.reachability == .online
                    }
                    return VirtualMasterPresence.defaultWiFiLANCheck(hardwareId: hw)
                }
            )
            return !presence.isOnline
        }
        if device.deviceType == .wifi { return device.reachability == .offline }
        if ble.isDeviceConnected(uuid: device.uuid) { return false }
        return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles
    }

    func shouldRender(_ device: BLEDevice) -> Bool {
        if device.isVirtualMaster { return true }
        // Do not show a not-yet-identified hub as an individual device until
        // identification settles — it may still belong to a virtual device.
        if !identitiesSettled, isUnidentifiedHub(device) {
            return false
        }
        return (device.deviceType == .bluetooth && ble.isBluetoothOn) || device.deviceType == .wifi
    }

    /// A BLE hub advertising a provisioning name whose MAC is not yet known.
    private func isUnidentifiedHub(_ device: BLEDevice) -> Bool {
        device.deviceType == .bluetooth
            && LimiDeviceNaming.isBLEProvisioningHubName(device.name)
            && device.resolvedHardwareId().isEmpty
    }

    /// First live BLE member for Wi‑Fi list — same member-aware pick as master provisioning.
    @MainActor
    func preferredBLEMember(for master: VirtualMasterScanMetadata) -> BLEDevice? {
        guard let target = WiFiProvisioningCoordinator.preferredMasterBLETarget(master: master) else {
            return nil
        }
        return BLEDevice(
            name: target.bleName,
            uuid: target.bleUUID,
            deviceType: .bluetooth,
            reachability: .online
        )
    }

    func deviceOpacity(_ device: BLEDevice) -> Double {
        if device.isVirtualMaster {
            return isDeviceDisabled(device) ? 0.4 : 1.0
        }
        if device.deviceType == .wifi { return 1.0 }
        if ble.isDeviceConnected(uuid: device.uuid) { return 1.0 }
        return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles ? 0.4 : 1.0
    }

    private func rebuildDeviceList() {
        // Add Device only needs reachable LAN boards. Offline Bonjour rows are often
        // stale ghosts (same board after factory reset still showing the old IP).
        // Must match Home via LimiDeviceNaming so "LIMI Device-2" is not dropped.
        let allWifi = bonjour.discoveredWiFiDevices.filter { $0.deviceType == .wifi }
        let wifiOnline = allWifi
            .filter { isAllowedScanName($0.name) && $0.reachability == .online }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // Same MAC / same LAN IP = one physical hub (kills rename ghosts like LIMI Device + LIMI Device-2).
        let wifiUnique = Self.dedupeWifiByHardwareOrIP(wifiOnline)

        let now = Date()
        if now.timeIntervalSince(lastScanListLogAt) >= 10.0 {
            lastScanListLogAt = now
            let rejected = allWifi.filter {
                $0.reachability == .online && !isAllowedScanName($0.name)
            }
            if !rejected.isEmpty {
                DeviceConsole.log(
                    .add,
                    "Add Device scan skipped \(rejected.count) online name(s): \(rejected.map(\.name).joined(separator: ", "))"
                )
            }
            DeviceConsole.log(
                .add,
                "Add Device scan wifi online allowed=\(wifiOnline.count) unique=\(wifiUnique.count) names=\(wifiUnique.map(\.name).joined(separator: " | "))"
            )
        }

        let connected = ble.connectedBLEDevices()
        let allBLEDevices = scannedDevices + connected
        let mergedBLEById = allBLEDevices.reduce(into: [String: BLEDevice]()) { dict, dev in
            dict[dev.uuid] = dev
        }
        let bleDevices = Array(mergedBLEById.values).filter { isAllowedScanName($0.name) }
        let bleFiltered = bleDevices.filter {
            ble.isDeviceConnected(uuid: $0.uuid) || ((bleMissedCycles[$0.uuid] ?? 0) < bleRemoveAfterCycles)
        }

        let bleProvisioningVisible = bleFiltered.contains {
            $0.deviceType == .bluetooth && LimiDeviceNaming.isBLEProvisioningHubName($0.name)
        }
        if let browser = bonjour as? BonjourServiceBrowser {
            browser.purgeWiFiGhostsWithoutLiveMQTT(bleProvisioningVisible: bleProvisioningVisible)
        }

        // Same physical hub must not appear twice (Wi‑Fi + BLE) after reset / re-setup.
        let wifiDeduped = Self.wifiDevicesExcludingBLEDuplicates(
            wifiDevices: wifiUnique,
            bleDevices: bleFiltered
        )
        var combined = wifiDeduped + bleFiltered
        combined = VirtualDeviceScanGrouping.apply(
            devices: combined,
            groups: virtualGroupingSpecs
        )
        orderedDevices = combined

        let hasAllowedBonjour = wifiDeduped.contains { $0.reachability == .online }
        let hasAllowedConnectedBLE = ble.connectedBLEDevices().contains {
            isAllowedScanName($0.name)
        }
        shouldShowContinue = hasAllowedBonjour || hasAllowedConnectedBLE
    }

    /// One row per physical hub: prefer TXT MAC, then collapse same LAN IP.
    static func dedupeWifiByHardwareOrIP(_ devices: [BLEDevice]) -> [BLEDevice] {
        var byHardware: [String: BLEDevice] = [:]
        var withoutHardware: [BLEDevice] = []

        for device in devices {
            let hw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? "")
            if hw.isEmpty {
                withoutHardware.append(device)
            } else if let existing = byHardware[hw] {
                byHardware[hw] = LimiDeviceNaming.preferredWiFiDuplicate(existing, device)
            } else {
                byHardware[hw] = device
            }
        }

        var merged = Array(byHardware.values) + withoutHardware
        var byIP: [String: BLEDevice] = [:]
        var withoutIP: [BLEDevice] = []
        var ipOrder: [String] = []

        for device in merged {
            let ip = (device.ipAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if ip.isEmpty {
                withoutIP.append(device)
            } else if let existing = byIP[ip] {
                let kept = LimiDeviceNaming.preferredWiFiDuplicate(existing, device)
                DeviceConsole.log(
                    .add,
                    "dedupe same IP=\(ip) keep=\(kept.name) drop=\(kept.uuid == existing.uuid ? device.name : existing.name)"
                )
                byIP[ip] = kept
            } else {
                byIP[ip] = device
                ipOrder.append(ip)
            }
        }

        let result = ipOrder.compactMap { byIP[$0] } + withoutIP
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Drops online Bonjour rows that map to a BLE peripheral already in the list
    /// (via ConfiguredBLEDeviceStore hardwareId ↔ peripheral UUID), or stale Wi‑Fi
    /// ghosts after factory reset (BLE hub advertising, no live MQTT on that MAC).
    static func wifiDevicesExcludingBLEDuplicates(
        wifiDevices: [BLEDevice],
        bleDevices: [BLEDevice],
        cloudConnected: Bool = LightControllingSocket.shared.isConnected
    ) -> [BLEDevice] {
        let bleUUIDs = Set(bleDevices.map { $0.uuid.lowercased() })
        var bleHardwareIds: Set<String> = Set(
            ConfiguredBLEDeviceStore.shared.allRecords.compactMap { record in
                guard ConfiguredBLEDeviceStore.isUsablePeripheralUUID(
                    record.blePeripheralUUID,
                    forHardwareId: record.hardwareId
                ) else { return nil }
                guard bleUUIDs.contains(record.blePeripheralUUID.lowercased()) else { return nil }
                let key = LimiDeviceNaming.normalizedHardwareId(record.hardwareId)
                return key.isEmpty ? nil : key
            }
        )
        for ble in bleDevices where ble.deviceType == .bluetooth {
            let name = ble.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.lowercased().hasPrefix("limi1ch-") else { continue }
            let hw = LimiDeviceNaming.normalizedHardwareId(name)
            if !hw.isEmpty { bleHardwareIds.insert(hw) }
        }

        var filtered = wifiDevices
        if !bleHardwareIds.isEmpty {
            filtered = filtered.filter { wifi in
                let hw = LimiDeviceNaming.normalizedHardwareId(wifi.txtRecord?["deviceId"] ?? "")
                if !hw.isEmpty, bleHardwareIds.contains(hw) { return false }
                return true
            }
        }

        let bleProvisioning = bleDevices.filter {
            $0.deviceType == .bluetooth && LimiDeviceNaming.isBLEProvisioningHubName($0.name)
        }
        guard !bleProvisioning.isEmpty, cloudConnected else { return filtered }

        let mqttLive = filtered.filter { wifi in
            let hw = LimiDeviceNaming.normalizedHardwareId(wifi.txtRecord?["deviceId"] ?? "")
            return !hw.isEmpty && DeviceTransportRegistry.shared.state(for: hw).mqttConnected
        }
        guard !mqttLive.isEmpty else { return filtered }

        return filtered.filter { wifi in
            let hw = LimiDeviceNaming.normalizedHardwareId(wifi.txtRecord?["deviceId"] ?? "")
            guard !hw.isEmpty else { return true }
            return DeviceTransportRegistry.shared.state(for: hw).mqttConnected
        }
    }

    private func updateBLEPresence() {
        let now = Date()
        var allIds = Set(scannedDevices.map(\.uuid))
        for device in ble.connectedBLEDevices() { allIds.insert(device.uuid) }
        for id in bleMissedCycles.keys { allIds.insert(id) }
        for id in ble.bleLastSeenById.keys { allIds.insert(id) }

        for id in allIds {
            if let last = ble.bleLastSeenById[id], now.timeIntervalSince(last) <= bleCycleInterval * 1.2 {
                bleMissedCycles[id] = 0
            } else {
                bleMissedCycles[id] = (bleMissedCycles[id] ?? 0) + 1
            }
        }
        rebuildDeviceList()
    }
}
