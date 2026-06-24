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
        print("🔍 Starting Bonjour service discovery for _Limi1Ch._udp.")
        servicesByName.removeAll()
        servicesByUuid.removeAll()
        nameToUuid.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.serviceBrowser.searchForServices(ofType: "_Limi1Ch._udp.", inDomain: "local.")
        }
        startDeviceMonitoring()
    }

    func stopBrowsing() {
        print("🔴 Stopping Bonjour service discovery")
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
        print("♻️ Restarting Bonjour discovery…")
        stopBrowsing()
        resetBrowser()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.startBrowsing() }
    }

    // MARK: - HARD REMOVE API (for BLE handover)

    /// Remove any Bonjour device whose TXT `deviceId`, Bonjour UUID, or Name matches the BLE identity.
    func removeCompletelyMatching(bleName: String, bleId: String) {
        // 1) Match by TXT deviceId
        if let toRemove = discoveredWiFiDevices.first(where: { ($0.txtRecord?["deviceId"] ?? "") == bleId || ($0.txtRecord?["deviceId"] ?? "") == bleName }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched TXT deviceId with BLE (\(bleName), \(bleId))")
            return
        }
        // 2) Match by Bonjour UUID against BLE id
        if let toRemove = discoveredWiFiDevices.first(where: { $0.uuid == bleId }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched Bonjour UUID with BLE id \(bleId)")
            return
        }
        // 3) Match by Bonjour Name against BLE name
        if let toRemove = discoveredWiFiDevices.first(where: { $0.name == bleName }) {
            removeWiFiDeviceCompletely(uuid: toRemove.uuid, reason: "Matched Bonjour Name with BLE name \(bleName)")
            return
        }
        // 4) Nothing matched
        print("ℹ️ No Bonjour entry matched BLE (\(bleName), \(bleId)) — nothing to remove.")
    }

    /// Fully purge a Wi-Fi record from memory, cancel pings/monitoring, and drop service references.
    private func removeWiFiDeviceCompletely(uuid: String, reason: String) {
        print("🧹 HARD REMOVE Bonjour device '\(uuid)' – \(reason)")
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
        discoveredWiFiDevices.removeAll { $0.uuid == uuid }
        // Trigger publisher
        discoveredWiFiDevices = Array(discoveredWiFiDevices)
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("🔍 Found Bonjour service: \(service.name) of type _Limi1Ch._udp.")
        print("   ↳ type=\(service.type) domain=\(service.domain) host=\(service.hostName ?? "nil") moreComing=\(moreComing)")
        servicesByName[serviceIdentity(for: service)] = service
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 10.0)
        service.startMonitoring()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("🔴 Bonjour service removed: \(service.name)")
        print("   ↳ type=\(service.type) domain=\(service.domain) host=\(service.hostName ?? "nil") moreComing=\(moreComing)")
        let identity = serviceIdentity(for: service)
        let uuid = nameToUuid[identity] ?? service.name
        markOffline(uuid: uuid, because: "Bonjour didRemove")
        servicesByName.removeValue(forKey: identity)
        nameToUuid.removeValue(forKey: identity)
        servicesByUuid.removeValue(forKey: uuid)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("❌ Bonjour search failed: \(errorDict)")
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("✅ Resolved Bonjour service: \(sender.name)")
        print("   ↳ type=\(sender.type) domain=\(sender.domain) host=\(sender.hostName ?? "nil") port=\(sender.port)")
        guard let addresses = sender.addresses, !addresses.isEmpty else {
            print("⚠️ No addresses found for service: \(sender.name)")
            return
        }

        guard let firstAddress = addresses.first else {
            print("⚠️ No address data for service: \(sender.name)")
            return
        }

        let ipAddress = getIPAddress(from: firstAddress)
        print("📍 Service \(sender.name) resolved to IP: \(ipAddress ?? "unknown")")

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
        print("🧾 TXT count for \(sender.name): \(txtRecordDict.count)")
        if txtRecordDict.isEmpty {
            print("🧾 TXT payload is empty for \(sender.name)")
        } else {
            for key in txtRecordDict.keys.sorted() {
                print("   • \(key)=\(txtRecordDict[key] ?? "")")
            }
        }

        // Keep each resolved device distinct even when multiple units share
        // the same deviceId or Bonjour name.
        let uuid = ipAddress.map { "\(sender.name)|\($0)" } ?? serviceIdentity(for: sender)
        nameToUuid[serviceIdentity(for: sender)] = uuid
        servicesByUuid[uuid] = sender
        print("🆔 Discovery identity for \(sender.name): \(uuid)")

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
            if let idx = self.discoveredWiFiDevices.firstIndex(where: { $0.uuid == uuid }) {
                let prev = self.discoveredWiFiDevices[idx]
                let mergedTxt: [String:String]? = txt.isEmpty ? prev.txtRecord : txt
                let newLastSeen: Date? = (reach == .online) ? Date() : prev.lastSeen
                let updated = prev.with(ip: ipAddress, txt: mergedTxt, reach: reach, lastSeen: newLastSeen)
                self.discoveredWiFiDevices[idx] = updated
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
            self.discoveredWiFiDevices = Array(self.discoveredWiFiDevices)
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
        print("🔄 Started continuous device monitoring (every 1.0s)")
    }

    private func stopDeviceMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("⏹️ Stopped device monitoring")
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
        print("🔻 Marking '\(uuid)' Offline – \(because)")
        updateReachability(uuid: uuid, reach: .offline)
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
