import Foundation
import Network
import Combine
import Darwin

protocol BonjourWiFiBrowsing: AnyObject, ObservableObject {
    var discoveredWiFiDevices: [BLEDevice] { get }
    func startBrowsing()
    func stopBrowsing()
    func removeCompletelyMatching(bleName: String, bleId: String)
}

class BonjourServiceBrowser: NSObject, ObservableObject, BonjourWiFiBrowsing, NetServiceBrowserDelegate, NetServiceDelegate {
    static let shared = BonjourServiceBrowser()

    private var serviceBrowser: NetServiceBrowser!
    private var isBrowsing = false

    @Published var discoveredWiFiDevices: [BLEDevice] = []
    private var resolvingServices: [NetService] = []
    private var lastBonjourRestart: Date = .distantPast
    private let minRestartInterval: TimeInterval = 3.0

    // Presence + monitoring
    private var deviceLastSeenTXT: [String: Date] = [:]   // uuid → last TXT update
    private var monitoringTimer: Timer?
    private let deviceTimeout: TimeInterval = 4.0

    // Tracking maps
    private var servicesByName: [String: NetService] = [:]
    private var servicesByUuid: [String: NetService] = [:]
    private var nameToUuid: [String: String] = [:]

    // Reachability pings
    private let maxPingAttempts = 3
    private let pingGap: TimeInterval = 0.7
    private let pingPerAttemptTimeout: TimeInterval = 0.9
    private var activePings: [String: PingPoller] = [:]   // uuid → ongoing monitor ping
    private var verifyPings: [String: PingPoller] = [:]   // uuid → initial verify ping

    private override init() {
        super.init()
        resetBrowser()
    }

    private func serviceIdentity(for service: NetService) -> String {
        "\(ObjectIdentifier(service).hashValue)"
    }

    private func resetBrowser() {
        if serviceBrowser != nil {
            serviceBrowser.stop()
            serviceBrowser.delegate = nil
        }
        let b = NetServiceBrowser()
        b.delegate = self
        serviceBrowser = b
    }

    func startBrowsing() {
        guard !isBrowsing else { return }
        isBrowsing = true
        servicesByName.removeAll()
        servicesByUuid.removeAll()
        nameToUuid.removeAll()
        DeviceConsole.log(.bonjour, "start browsing _Limi1Ch._udp. local.")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.serviceBrowser.searchForServices(ofType: "_Limi1Ch._udp.", inDomain: "local.")
        }
        startDeviceMonitoring()
    }

    func stopBrowsing() {
        DeviceConsole.log(.bonjour, "stop browsing")
        serviceBrowser.stop()
        resolvingServices.removeAll()
        stopDeviceMonitoring()
        isBrowsing = false
        activePings.values.forEach { $0.cancel() }
        activePings.removeAll()
        verifyPings.values.forEach { $0.cancel() }
        verifyPings.removeAll()
    }

    private func restartBonjourDiscovery() {
        let now = Date()
        guard now.timeIntervalSince(lastBonjourRestart) >= minRestartInterval else { return }
        lastBonjourRestart = now
        stopBrowsing()
        resetBrowser()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.startBrowsing() }
    }

    // MARK: - HARD REMOVE API (for BLE handover)

    /// Remove Wi‑Fi ghost only when it is the same physical hub as this BLE peripheral (by hardware id).
    func removeCompletelyMatching(bleName: String, bleId: String) {
        if WiFiProvisioningActivityGate.isActive || AddDeviceFlowActivityGate.isActive {
            DeviceConsole.log(
                .bonjour,
                "skip removeCompletelyMatching — Add Device / provision active ble=\(bleId)"
            )
            return
        }
        if let ownerHw = ConfiguredBLEDeviceStore.shared.allRecords.first(where: {
            $0.blePeripheralUUID.caseInsensitiveCompare(bleId) == .orderedSame
        })?.hardwareId {
            let hw = LimiDeviceNaming.normalizedHardwareId(ownerHw)
            if let toRemove = discoveredWiFiDevices.first(where: { $0.resolvedHardwareId() == hw }) {
                removeWiFiDeviceCompletely(
                    uuid: toRemove.uuid,
                    reason: "Matched LAN hub hw=\(hw) for BLE \(bleId)"
                )
                return
            }
        }
        // Match TXT deviceId to peripheral UUID (legacy paths).
        if let toRemove = discoveredWiFiDevices.first(where: {
            ($0.txtRecord?["deviceId"] ?? "") == bleId || ($0.txtRecord?["deviceId"] ?? "") == bleName
        }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched TXT deviceId with BLE (\(bleName), \(bleId))")
            return
        }
        if let toRemove = discoveredWiFiDevices.first(where: { $0.uuid == bleId }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched Bonjour UUID with BLE id \(bleId)")
            return
        }
        // Never drop a Wi‑Fi row by generic name alone ("LIMI Device" is shared by every hub).
        guard !LimiDeviceNaming.isBLEProvisioningHubName(bleName), bleName != "LIMI Device" else { return }
        if let toRemove = discoveredWiFiDevices.first(where: { $0.name == bleName }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched Bonjour Name with BLE name \(bleName)")
        }
    }

    /// Fully purge a Wi-Fi record from memory, cancel pings/monitoring, and drop service references.
    private func removeWiFiDeviceCompletely(uuid: String, reason: String) {
        // Cancel any pings
        if let p = activePings.removeValue(forKey: uuid) { p.cancel() }
        if let v = verifyPings.removeValue(forKey: uuid) { v.cancel() }
        // Stop NetService monitoring if we have it
        if let service = servicesByUuid.removeValue(forKey: uuid) {
            service.stopMonitoring()
            service.delegate = nil
        }
        // Remove reverse map entries
        if let name = nameToUuid.first(where: { $0.value == uuid })?.key {
            nameToUuid.removeValue(forKey: name)
            servicesByName.removeValue(forKey: name)
        }
        // Drop presence bookkeeping
        deviceLastSeenTXT.removeValue(forKey: uuid)
        // Remove from array
        let before = discoveredWiFiDevices.count
        discoveredWiFiDevices.removeAll { $0.uuid == uuid }
        // Trigger publisher
        discoveredWiFiDevices = Array(discoveredWiFiDevices)
        if discoveredWiFiDevices.count != before {
            DeviceConsole.log(.bonjour, "purged uuid=\(uuid) reason=\(reason)")
        }
    }

    /// Drop every Offline Bonjour row (stale IP after factory reset / reboot).
    func purgeOfflineDevices(reason: String) {
        let offlineUUIDs = discoveredWiFiDevices
            .filter { device in
                guard device.deviceType == .wifi && device.reachability == .offline else { return false }
                let hw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? device.uuid)
                // Configured hubs may flicker offline during browse restarts — keep for re-resolve.
                if !hw.isEmpty, ConfiguredBLEDeviceStore.shared.hasConfiguredBLE(for: hw) {
                    return false
                }
                return true
            }
            .map(\.uuid)
        for uuid in offlineUUIDs {
            removeWiFiDeviceCompletely(uuid: uuid, reason: reason)
        }
    }

    /// Drop Bonjour Wi‑Fi rows with no live MQTT while a BLE provisioning hub is visible.
    /// After factory reset the board stops MQTT but the old LAN IP can still answer ping.
    /// Skipped while Wi‑Fi provisioning is actively waiting for Bonjour/MQTT confirmation.
    func purgeWiFiGhostsWithoutLiveMQTT(bleProvisioningVisible: Bool) {
        guard bleProvisioningVisible else { return }
        if WiFiProvisioningActivityGate.isActive || AddDeviceFlowActivityGate.isActive {
            return
        }
        guard LightControllingSocket.shared.isConnected else { return }

        let hasAnyLiveMQTT = discoveredWiFiDevices.contains { device in
            guard device.deviceType == .wifi else { return false }
            let hw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? "")
            guard !hw.isEmpty else { return false }
            return DeviceTransportRegistry.shared.state(for: hw).mqttConnected
        }
        guard hasAnyLiveMQTT else { return }

        for device in discoveredWiFiDevices where device.deviceType == .wifi {
            let hw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? "")
            guard !hw.isEmpty else { continue }
            if DeviceTransportRegistry.shared.state(for: hw).mqttConnected { continue }
            removeWiFiDeviceCompletely(
                uuid: device.uuid,
                reason: "BLE provisioning visible; Bonjour Wi‑Fi has no live MQTT"
            )
        }
    }

    /// Collapse rename ghosts already in memory (same MAC or same IP, multiple rows).
    func collapseDuplicateDevices(reason: String) {
        let wifi = discoveredWiFiDevices.filter { $0.deviceType == .wifi }
        guard wifi.count > 1 else { return }

        var keepers: [BLEDevice] = []
        for device in wifi {
            let hw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? "")
            let ip = (device.ipAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if let idx = keepers.firstIndex(where: { kept in
                let keptHw = LimiDeviceNaming.normalizedHardwareId(kept.txtRecord?["deviceId"] ?? "")
                if !hw.isEmpty, keptHw == hw { return true }
                let keptIP = (kept.ipAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !ip.isEmpty, keptIP == ip { return true }
                return false
            }) {
                let preferred = LimiDeviceNaming.preferredWiFiDuplicate(keepers[idx], device)
                let drop = preferred.uuid == device.uuid ? keepers[idx] : device
                keepers[idx] = preferred
                if drop.uuid != preferred.uuid {
                    DeviceConsole.log(
                        .bonjour,
                        "collapse (\(reason)) drop=\(drop.name)/\(drop.uuid) keep=\(preferred.name)/\(preferred.uuid)"
                    )
                    removeWiFiDeviceCompletely(uuid: drop.uuid, reason: "collapse \(reason)")
                }
            } else {
                keepers.append(device)
            }
        }
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        servicesByName[serviceIdentity(for: service)] = service
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 10.0)
        service.startMonitoring()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let identity = serviceIdentity(for: service)
        let uuid = nameToUuid[identity] ?? service.name
        markOffline(uuid: uuid, because: "Bonjour didRemove")
        servicesByName.removeValue(forKey: identity)
        nameToUuid.removeValue(forKey: identity)
        servicesByUuid.removeValue(forKey: uuid)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses, !addresses.isEmpty else {
            return
        }

        guard let firstAddress = addresses.first else {
            return
        }

        let ipAddress = getIPAddress(from: firstAddress)

        var txtRecordDict: [String: String] = [:]
        if let txtData = sender.txtRecordData() {
            // Cast to NSDictionary (Objective-C type) to avoid the bridging crash
            let txtDict = NetService.dictionary(fromTXTRecord: txtData) as NSDictionary
            
            for (key, value) in txtDict {
                // Safely extract the key as a String
                if let k = key as? String {
                    // Check if value is Data and not NSNull
                    if let v = value as? Data {
                        txtRecordDict[k] = String(data: v, encoding: .utf8) ?? "N/A"
                    } else {
                        // This handles NSNull or any other non-data value
                        txtRecordDict[k] = ""
                    }
                }
            }
        }
        if txtRecordDict.isEmpty {
        } else {
            for key in txtRecordDict.keys.sorted() {
            }
        }

        // Stable identity: prefer TXT deviceId (MAC), else IP.
        // Do NOT key by advertised name — rename (LIMI Device → LIMI Device-2)
        // would otherwise create duplicate rows for the same board.
        let hardwareKey = LimiDeviceNaming.normalizedHardwareId(txtRecordDict["deviceId"] ?? "")
        let uuid: String
        if !hardwareKey.isEmpty {
            uuid = hardwareKey
        } else if let ip = ipAddress, !ip.isEmpty {
            uuid = "ip:\(ip)"
        } else {
            uuid = serviceIdentity(for: sender)
        }
        nameToUuid[serviceIdentity(for: sender)] = uuid
        servicesByUuid[uuid] = sender

        // Verify reachability once before deciding initial state
        if let ip = ipAddress {
            verifyAndUpsert(uuid: uuid, name: sender.name, ipAddress: ip, txt: txtRecordDict)
        } else {
            upsert(uuid: uuid, name: sender.name, ipAddress: nil, txt: txtRecordDict, reach: .offline)
        }

        resolvingServices.removeAll { $0 == sender }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        resolvingServices.removeAll { $0 == sender }
    }

    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        let uuid = nameToUuid[serviceIdentity(for: sender)] ?? sender.name
        deviceLastSeenTXT[uuid] = Date()
        updateReachability(uuid: uuid, reach: .online)
    }

    // MARK: - Add/Update helpers

    private func upsert(uuid: String, name: String, ipAddress: String?, txt: [String:String], reach: BLEDevice.Reachability) {
        DispatchQueue.main.async {
            let deviceId = txt["deviceId"] ?? ""
            let hardwareKey = LimiDeviceNaming.normalizedHardwareId(deviceId)
            let isNew = !self.discoveredWiFiDevices.contains(where: { $0.uuid == uuid })
            if let idx = self.discoveredWiFiDevices.firstIndex(where: { $0.uuid == uuid }) {
                let prev = self.discoveredWiFiDevices[idx]
                let mergedTxt: [String:String]? = txt.isEmpty ? prev.txtRecord : txt
                let newLastSeen: Date? = (reach == .online) ? Date() : prev.lastSeen
                let updated = prev.with(
                    name: name,
                    ip: ipAddress,
                    txt: mergedTxt,
                    reach: reach,
                    lastSeen: newLastSeen
                )
                let reachChanged = prev.reachability != reach
                let nameChanged = prev.name != name
                self.discoveredWiFiDevices[idx] = updated
                if reachChanged || nameChanged {
                    DeviceConsole.log(
                        .bonjour,
                        "update name=\(name) id=\(deviceId.isEmpty ? uuid : deviceId) ip=\(ipAddress ?? "-") reach=\(reach.rawValue)"
                    )
                }
            } else {
                let initialLastSeen: Date? = (reach == .online) ? Date() : nil
                let new = BLEDevice(
                    name: name,
                    uuid: uuid,
                    deviceType: .wifi,
                    ipAddress: ipAddress,
                    txtRecord: txt.isEmpty ? nil : txt,
                    reachability: reach,
                    lastSeen: initialLastSeen
                )
                self.discoveredWiFiDevices.append(new)
            }
            if isNew {
                DeviceConsole.log(
                    .bonjour,
                    "discovered name=\(name) id=\(deviceId.isEmpty ? uuid : deviceId) ip=\(ipAddress ?? "-") reach=\(reach.rawValue)"
                )
            }
            if reach == .online, !hardwareKey.isEmpty {
                PresenceSnapshotStore.shared.record(
                    deviceId: hardwareKey,
                    isOnline: true,
                    path: .local
                )
            }

            // Drop rename/stale twins: same MAC or same LAN IP must be one row.
            self.purgeDuplicateWiFiRows(
                keepingUUID: uuid,
                hardwareId: hardwareKey,
                ipAddress: ipAddress
            )
            self.discoveredWiFiDevices = Array(self.discoveredWiFiDevices)
        }
    }

    /// Removes ghost rows left after a board renames or re-advertises under a new Bonjour name.
    private func purgeDuplicateWiFiRows(keepingUUID: String, hardwareId: String, ipAddress: String?) {
        let hw = LimiDeviceNaming.normalizedHardwareId(hardwareId)
        let ip = ipAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let twins = discoveredWiFiDevices.filter { device in
            guard device.uuid != keepingUUID else { return false }
            let otherHw = LimiDeviceNaming.normalizedHardwareId(device.txtRecord?["deviceId"] ?? "")
            if !hw.isEmpty {
                if otherHw == hw { return true }
                if LimiDeviceNaming.normalizedHardwareId(device.uuid) == hw { return true }
            }
            if !ip.isEmpty, let otherIP = device.ipAddress,
               otherIP.trimmingCharacters(in: .whitespacesAndNewlines) == ip {
                return true
            }
            // Legacy name|ip keys from older builds.
            if !ip.isEmpty, device.uuid.hasSuffix("|\(ip)") { return true }
            return false
        }
        for twin in twins {
            DeviceConsole.log(
                .bonjour,
                "dedupe purge twin name=\(twin.name) uuid=\(twin.uuid) ip=\(twin.ipAddress ?? "-") kept=\(keepingUUID)"
            )
            removeWiFiDeviceCompletely(
                uuid: twin.uuid,
                reason: "duplicate of \(keepingUUID) hw=\(hw.isEmpty ? "-" : hw) ip=\(ip.isEmpty ? "-" : ip)"
            )
        }
    }

    private func updateReachability(uuid: String, reach: BLEDevice.Reachability) {
        DispatchQueue.main.async {
            if let idx = self.discoveredWiFiDevices.firstIndex(where: { $0.uuid == uuid }) {
                let d = self.discoveredWiFiDevices[idx]
                self.discoveredWiFiDevices[idx] = d.with(ip: d.ipAddress, txt: d.txtRecord, reach: reach, lastSeen: reach == .online ? Date() : d.lastSeen)
                self.discoveredWiFiDevices = Array(self.discoveredWiFiDevices)
            }
        }
    }

    // Verify before first add/update
    private func verifyAndUpsert(uuid: String, name: String, ipAddress: String, txt: [String:String]) {
        if verifyPings[uuid] != nil { return }
        let cfg = PingPoller.Config(maxAttempts: 2, gapBetween: 0.3, perAttemptTimeout: 0.8)
        let poller = PingPoller(host: ipAddress, uuid: uuid, config: cfg) { [weak self] uuid, reachable in
            guard let self else { return }
            DispatchQueue.main.async {
                self.verifyPings.removeValue(forKey: uuid)
                self.upsert(uuid: uuid, name: name, ipAddress: ipAddress, txt: txt, reach: reachable ? .online : .offline)
            }
        }
        verifyPings[uuid] = poller
        poller.start()
    }

    // MARK: - Monitoring (keep status fresh)

    private func startDeviceMonitoring() {
        stopDeviceMonitoring()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
    }

    private func stopDeviceMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func tick() {
        let now = Date()
        for dev in discoveredWiFiDevices where dev.deviceType == .wifi {
            let uuid = dev.uuid
            let last = dev.lastSeen ?? deviceLastSeenTXT[uuid] ?? .distantPast
            let elapsed = now.timeIntervalSince(last)
            if elapsed <= deviceTimeout {
                if let poller = activePings.removeValue(forKey: uuid) { poller.cancel() }
                continue
            }
            if activePings[uuid] != nil { continue }

            var ipToPing: String? = dev.ipAddress
            if ipToPing == nil, let svc = servicesByUuid[uuid], let addresses = svc.addresses, let firstAddress = addresses.first {
                ipToPing = getIPAddress(from: firstAddress)
            }
            guard let ip = ipToPing else {
                markOffline(uuid: uuid, because: "No IP")
                continue
            }

            let cfg = PingPoller.Config(maxAttempts: maxPingAttempts, gapBetween: pingGap, perAttemptTimeout: pingPerAttemptTimeout)
            let poller = PingPoller(host: ip, uuid: uuid, config: cfg) { [weak self] uuid, reachable in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.activePings.removeValue(forKey: uuid)
                    if reachable {
                        self.updateReachability(uuid: uuid, reach: .online)
                    } else {
                        self.markOffline(uuid: uuid, because: "ping failed \(self.maxPingAttempts)x")
                        self.restartBonjourDiscovery()
                    }
                }
            }
            activePings[uuid] = poller
            poller.start()
        }
    }

    private func markOffline(uuid: String, because: String) {
        updateReachability(uuid: uuid, reach: .offline)
        // After factory reset / reboot the old mDNS+IP often lingers as Offline.
        // Drop it shortly so Add Device does not show a dead Wi‑Fi twin next to BLE.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self else { return }
            guard let still = self.discoveredWiFiDevices.first(where: { $0.uuid == uuid }),
                  still.reachability == .offline else { return }
            self.removeWiFiDeviceCompletely(uuid: uuid, reason: "offline timeout (\(because))")
        }
    }

    // MARK: - Utils

    private func getIPAddress(from addressData: Data) -> String? {
        return addressData.withUnsafeBytes { bytes in
            let sockaddr = bytes.bindMemory(to: sockaddr.self).baseAddress!
            switch Int32(sockaddr.pointee.sa_family) {
            case AF_INET:
                let addr = bytes.bindMemory(to: sockaddr_in.self).baseAddress!
                return String(cString: inet_ntoa(addr.pointee.sin_addr))
            case AF_INET6:
                let addr = bytes.bindMemory(to: sockaddr_in6.self).baseAddress!
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                let sin6 = addr.pointee.sin6_addr
                let result = withUnsafePointer(to: sin6) { ptr in
                    inet_ntop(AF_INET6, ptr, &buffer, socklen_t(INET6_ADDRSTRLEN))
                }
                return result != nil ? String(cString: buffer) : nil
            default:
                return nil
            }
        }
    }
}
