import SwiftUI
import Network
import Foundation
import Combine
import Darwin // for inet_ntop/inet_ntoa

// MARK: - ICMP Ping wrapper (SimplePing-based)
private final class PingPoller: NSObject {
    struct Config {
        let maxAttempts: Int
        let gapBetween: TimeInterval
        let perAttemptTimeout: TimeInterval
    }

    private let host: String
    private let uuid: String
    private let config: Config
    private var currentAttempt = 0
    private var ping: SimplePing?
    private var timeoutTimer: Timer?
    private var gapTimer: Timer?
    private let completion: (String, Bool) -> Void

    init(host: String, uuid: String, config: Config, completion: @escaping (String, Bool) -> Void) {
        self.host = host
        self.uuid = uuid
        self.config = config
        self.completion = completion
        super.init()
    }

    func start() { scheduleNextAttempt() }

    func cancel() {
        invalidateTimers()
        ping?.stop()
        ping = nil
    }

    private func scheduleNextAttempt() {
        if currentAttempt >= config.maxAttempts {
            completion(uuid, false)
            return
        }
        currentAttempt += 1
        let p = SimplePing(hostName: host)
        p?.delegate = self
        p?.start()
        ping = p
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: config.perAttemptTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.ping?.stop()
            self.ping = nil
            self.scheduleGapThenNextAttempt()
        }
    }

    private func scheduleGapThenNextAttempt() {
        gapTimer = Timer.scheduledTimer(withTimeInterval: config.gapBetween, repeats: false) { [weak self] _ in
            self?.scheduleNextAttempt()
        }
    }

    private func invalidateTimers() {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        gapTimer?.invalidate(); gapTimer = nil
    }
}

extension PingPoller: SimplePingDelegate {
    @objc func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) { pinger.send(with: nil) }
    @objc func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        invalidateTimers()
        pinger.stop()
        scheduleGapThenNextAttempt()
    }
    @objc func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {}
    @objc func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        invalidateTimers()
        pinger.stop()
        completion(uuid, true)
    }
    @objc func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        invalidateTimers()
        pinger.stop()
        completion(uuid, true)
    }
}

// MARK: - UI

struct AnimatedSearchButton: View {
    @State private var isAnimating = false
    @State private var glowIntensity: Double = 0.3
    let iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "#2E2E2E"), Color(hex: "#3A3A3A")]), startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
                .shadow(color: Color.white.opacity(glowIntensity), radius: 25, x: 0, y: 8)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)

            Image(systemName: iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 0.8)
                .animation(.easeOut(duration: 2.5).repeatForever(autoreverses: false), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glowIntensity = 0.8 }
        }
    }
}

// MARK: - Model

struct BLEDevice: Identifiable, Equatable {
    enum DeviceType: Equatable { case bluetooth, wifi }
    enum Reachability: String { case online, offline }

    let id: String
    let name: String
    let uuid: String                  // BLE: Peripheral UUID string; Wi-Fi: TXT deviceId or service.name
    let deviceType: DeviceType
    let ipAddress: String?
    let txtRecord: [String: String]?
    let reachability: Reachability
    let lastSeen: Date?

    init(name: String,
         uuid: String,
         deviceType: DeviceType = .bluetooth,
         ipAddress: String? = nil,
         txtRecord: [String: String]? = nil,
         reachability: Reachability = .offline,
         lastSeen: Date? = nil) {
        self.name = name
        self.uuid = uuid
        self.id = uuid
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.txtRecord = txtRecord
        self.reachability = reachability
        self.lastSeen = lastSeen
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.uuid == rhs.uuid &&
        lhs.deviceType == rhs.deviceType &&
        lhs.ipAddress == rhs.ipAddress &&
        lhs.txtRecord == rhs.txtRecord &&
        lhs.reachability == rhs.reachability &&
        lhs.lastSeen == rhs.lastSeen
    }

    func with(ip: String?, txt: [String:String]?, reach: Reachability, lastSeen: Date?) -> BLEDevice {
        BLEDevice(name: name, uuid: uuid, deviceType: deviceType, ipAddress: ip, txtRecord: txt, reachability: reach, lastSeen: lastSeen)
    }
}

// MARK: - Bonjour Service Browser (Online/Offline, plus hard removal API)

class BonjourServiceBrowser: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
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
        servicesByName[service.name] = service
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 10.0)
        service.startMonitoring()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("🔴 Bonjour service removed: \(service.name)")
        let uuid = nameToUuid[service.name] ?? service.name
        markOffline(uuid: uuid, because: "Bonjour didRemove")
        servicesByName.removeValue(forKey: service.name)
        nameToUuid.removeValue(forKey: service.name)
        servicesByUuid.removeValue(forKey: uuid)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("❌ Bonjour search failed: \(errorDict)")
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("✅ Resolved Bonjour service: \(sender.name)")
        guard let addresses = sender.addresses, !addresses.isEmpty else {
            print("⚠️ No addresses found for service: \(sender.name)")
            return
        }

        let ipAddress = getIPAddress(from: addresses.first!)
        print("📍 Service \(sender.name) resolved to IP: \(ipAddress ?? "unknown")")

        var txtRecordDict: [String: String] = [:]
        if let txtData = sender.txtRecordData(),
           let txtDict = NetService.dictionary(fromTXTRecord: txtData) as? [String: Data] {
            for (k, v) in txtDict {
                txtRecordDict[k] = String(data: v, encoding: .utf8) ?? "N/A"
            }
        }

        let uuid = txtRecordDict["deviceId"] ?? sender.name
        nameToUuid[sender.name] = uuid
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
        let uuid = nameToUuid[sender.name] ?? sender.name
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
            if ipToPing == nil, let svc = servicesByUuid[uuid], let addresses = svc.addresses {
                ipToPing = getIPAddress(from: addresses.first!)
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

// MARK: - DevicesButton

struct DevicesButton: View {
    let deviceName: String?
    let searchDeviceUUID: String?
    let onConnect: (String, String) -> Void
    let isConnected: Bool
    let deviceType: BLEDevice.DeviceType
    let ipAddress: String?
    var reachability: BLEDevice.Reachability = .offline

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator + icon
            VStack(spacing: 6) {
                Circle()
                    .fill(reachability == .online ? Color.emerald : Color.gray)
                    .frame(width: 12, height: 12)
                VStack(spacing: 4) {
                    Image(systemName: deviceType == .bluetooth ? "lamp.table.fill" : "wifi")
                        .font(.system(size: deviceType == .bluetooth ? 24 : 20, weight: .medium))
                        .foregroundColor(deviceType == .bluetooth ? Color.white : (reachability == .online ? .white : .red))
                    Text(deviceType == .bluetooth ? "BLE" : (reachability == .online ? "Online" : "Offline"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(reachability == .online ? .white : .red)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(deviceName ?? "Unknown Device")
                        .font(.custom("Poppins-Medium", size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black)
                        .cornerRadius(4)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(searchDeviceUUID ?? "XTP-1245")
                        .font(.custom("Poppins-Bold", size: 20))
                        .foregroundColor(.white)
                    if deviceType == .wifi, let ip = ipAddress {
                        Text("IP: \(ip)")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundColor(Color.blue.opacity(0.8))
                    }
                }
                Button(action: {
                    if let name = deviceName, let id = searchDeviceUUID { onConnect(name, id) }
                }) {
                    Text(isConnected ?  "Connected" : (reachability == .online ?"Connect" : "Disconnected"))
                        .font(.custom("Poppins-SemiBold", size: 16))
                        .foregroundColor(reachability == .online ? Color.alabaster : Color.charlestonGreen )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isConnected ? (reachability == .online ? Color.clear : Color.gray) : (reachability == .online ? Color.emerald : Color.gray))
                        .cornerRadius(8)
                }
                .disabled(reachability == .offline)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#24262B")))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4A4A4A"), lineWidth: 1))
    }
}

// MARK: - DemoScanDevicesView

struct DemoScanDevicesView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var scannedDevices: [BLEDevice] = []
    private let allowedNames: Set<String> = ["limi1ch-EC3564","1 CH-HUB", "4 CH-HUB","8 CH-HUB", "16 CH-HUB", "Mini Controller", "LIMI Device"]
    @ObservedObject private var ble = BluetoothManager.shared
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared

    @State private var showAddWifi: Bool = false
    @State private var selectedName: String? = nil
    @State private var selectedId: String? = nil
    @State private var selectedChannelMac: String = ""
    @State private var isShowingPWM2LEDSheet: Bool = false
    @State private var isShowingRGBDataSheet: Bool = false
    @State private var showLiginSkip: Bool = false
    @State private var ssidNameArray: [String] = []
    @State private var isConnectingToBLE: Bool = false
    @State private var bleMissedCycles: [String: Int] = [:]
    @State private var bleDisconnectedRecently: Set<String> = []
    private let bleCycleInterval: TimeInterval = 5.0
    private let bleGreyAfterCycles: Int = 2
    private let bleRemoveAfterCycles: Int = 3

    private var shouldShowContinue: Bool {
        let hasAllowedBonjour = bonjourBrowser.discoveredWiFiDevices.contains { allowedNames.contains($0.name) && $0.reachability == .online }
        let hasAllowedConnectedBLE = ble.connectedDevices.contains { (_, tuple) in
            tuple.peripheral.state == .connected && allowedNames.contains(tuple.peripheral.name ?? "")
        }
        return hasAllowedBonjour || hasAllowedConnectedBLE
    }

    var body: some View {
        VStack {
            VStack(alignment: .center, spacing:12){
                HStack{
                    Button {
                        if let onBack { onBack() } else { dismiss() }
                    } label: {
                        Image("Solid arrow right sm")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(Rectangle().fill(Color(hex: "#24262B")).cornerRadius(16))
                    }
                    Spacer()
                    Text("Add Device")
                        .font(.custom("Poppins-Bold", size: 30))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .kerning(-0.3)
                        .foregroundColor(Color.alabaster)
                    Spacer(); Spacer()
                }
                .padding(.top)
                .padding(.horizontal, 16)
                Text("Scanning....")
                    .font(.custom("Poppins-Medium", size: 20))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.alabaster)
            }.padding(.bottom, 12)
            
            AnimatedSearchButton(iconName: "magnifyingglass")

            VStack{
                HStack{
                    Text("Available Devices")
                        .font(.custom("Poppins-Medium", size: 20))
                        .foregroundColor(Color(hex: "#C9C4BD"))
                        .padding(.horizontal, 16)
                    Spacer()
                }
                                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Wi-Fi devices (allowed only)
                        let wifiDevices = bonjourBrowser.discoveredWiFiDevices
                            .filter { allowedNames.contains($0.name) }
                            .sorted { ($0.reachability == .online ? 0 : 1, $0.name) < ($1.reachability == .online ? 0 : 1, $1.name) }

                        // BLE devices (scanned + connected)
                        let connected: [BLEDevice] = ble.connectedDevices.compactMap { (uuid, tuple) in
                            guard tuple.peripheral.state == .connected else { return nil }
                            return BLEDevice(name: tuple.peripheral.name ?? "Unknown Device", uuid: uuid.uuidString, deviceType: .bluetooth, reachability: .online, lastSeen: Date())
                        }
                        let allBLEDevices = scannedDevices + connected
                        let mergedBLEById: [String: BLEDevice] = allBLEDevices.reduce(into: [:]) { dict, dev in dict[dev.uuid] = dev }
                        let bleDevices = Array(mergedBLEById.values).filter { allowedNames.contains($0.name) }
                        let bleFiltered = bleDevices.filter {
                            let isConnected = UUID(uuidString: $0.uuid).map { id in ble.connectedDevices[id]?.peripheral.state == .connected } ?? false
                            return isConnected || ((bleMissedCycles[$0.uuid] ?? 0) < bleRemoveAfterCycles)
                        }

                        let orderedDevices = wifiDevices + bleFiltered
                        ForEach(orderedDevices) { device in
                            if (device.deviceType == .bluetooth && ble.isBluetoothOn) || device.deviceType == .wifi {
                                DevicesButton(
                                    deviceName: device.name,
                                    searchDeviceUUID: device.uuid,
                                    onConnect: { name, id in
                                        if device.deviceType == .bluetooth {
                                            // Start connection process with loading state
                                            self.selectedName = name
                                            self.selectedId = id
                                            self.ssidNameArray = []
                                            self.isConnectingToBLE = true
                                            
                                            BonjourServiceBrowser.shared.removeCompletelyMatching(bleName: name, bleId: id)
                                            BluetoothManager.shared.selectAndConnect(name: name, uuidString: id)
                                        } else {
                                            print("📶 Wi-Fi device tapped: \(name) (\(device.reachability == .online ? "Online" : "Offline"))")
                                            if device.reachability == .online {
                                                if let txt = device.txtRecord,
                                                   let channelCountStr = txt["channelCount"],
                                                   let channelCount = Int(channelCountStr),
                                                   let channelMac = txt["deviceId"] {
                                                    if channelCount == 1 {
                                                        self.selectedChannelMac = channelMac
                                                        self.isShowingPWM2LEDSheet = true
                                                    } else {
                                                        self.selectedName = name
                                                        self.selectedId = id
                                                        self.isShowingRGBDataSheet = true
                                                    }
                                                } else {
                                                    self.selectedName = name
                                                    self.selectedId = id
                                                    self.showAddWifi = true
                                                }
                                            }
                                        }
                                    },
                                    isConnected: {
                                        if device.deviceType == .bluetooth {
                                            return UUID(uuidString: device.uuid).map { ble.connectedDevices[$0]?.peripheral.state == .connected } ?? false
                                        } else { return device.reachability == .online }
                                    }(),
                                    deviceType: device.deviceType,
                                    ipAddress: device.ipAddress,
                                    reachability: device.reachability
                                )
                                .opacity({
                                    if device.deviceType == .wifi { return 1.0 }
                                    let isConn = UUID(uuidString: device.uuid).map { ble.connectedDevices[$0]?.peripheral.state == .connected } ?? false
                                    if isConn { return 1.0 }
                                    return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles ? 0.4 : 1.0
                                }())
                                .disabled({
                                    if device.deviceType == .wifi { return device.reachability == .offline }
                                    let isConn = UUID(uuidString: device.uuid).map { ble.connectedDevices[$0]?.peripheral.state == .connected } ?? false
                                    if isConn { return false }
                                    return (bleMissedCycles[device.uuid] ?? 0) >= bleGreyAfterCycles
                                }())
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                Spacer()
                if shouldShowContinue {
                    Button(action: { showLiginSkip = true }) {
                        Text("Continue")
                            .font(.custom("Poppins-SemiBold", size: 16))
                            .foregroundColor(Color.charlestonGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background( Color.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .background(Color(hex: "#111214"))
        .onAppear {
            BluetoothManager.shared.startScanning { devices in
                let mapped = devices.map { BLEDevice(name: $0.name, uuid: $0.id, deviceType: .bluetooth, reachability: .online, lastSeen: Date()) }
                DispatchQueue.main.async { self.scannedDevices = mapped }
            }
            bonjourBrowser.startBrowsing()
        }
        .onDisappear {
            BluetoothManager.shared.stopScanning()
            bonjourBrowser.stopBrowsing()
        }
        .onReceive(Timer.publish(every: bleCycleInterval, on: .main, in: .common).autoconnect()) { _ in
            updateBLEPresence()
        }
        .onReceive(ble.$lastDisconnectedDeviceID) { id in
            guard let id = id else { return }
            bleDisconnectedRecently.insert(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { bleDisconnectedRecently.remove(id) }
        }
        .onChange(of: ble.isConnected) { _, isConnected in
            print("🔍 onChange triggered: isConnected = \(isConnected), isConnectingToBLE = \(self.isConnectingToBLE)")
            if isConnected && self.isConnectingToBLE {
                print("✅ BLE connected! Fetching WiFi list...")
                // BLE is now connected! Fetch WiFi list and show WiFi screen
                BluetoothManager.shared.readWifiList { list in
                    print("📶 WiFi list callback received: \(list.count) networks")
                    DispatchQueue.main.async {
                        self.ssidNameArray = list
                        print("📶 ssidNameArray set: \(self.ssidNameArray)")
                        self.isConnectingToBLE = false
                        print("✅ Setting showAddWifi = true")
                        self.showAddWifi = true
                    }
                }
            } else {
                print("⚠️ onChange: condition not met (isConnected:\(isConnected), isConnectingToBLE:\(self.isConnectingToBLE))")
            }
        }
        .fullScreenCover(isPresented: $showAddWifi) {
            WifiList(deviceName: selectedName ?? "", deviceId: selectedId ?? "", wifiList: ssidNameArray)
        }
        .overlay {
            if isConnectingToBLE {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Connecting to device...")
                            .font(.custom("Poppins-Medium", size: 16))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLiginSkip) {
            ConnectedDevicesView()
        }
    }

    private func updateBLEPresence() {
        let now = Date()
        var allIds = Set(scannedDevices.map { $0.uuid })
        for (uuid, _) in ble.connectedDevices { allIds.insert(uuid.uuidString) }
        for id in bleMissedCycles.keys { allIds.insert(id) }
        for (id, _) in ble.bleLastSeen { allIds.insert(id) }
        for id in allIds {
            if let last = ble.bleLastSeen[id], now.timeIntervalSince(last) <= bleCycleInterval * 1.2 {
                bleMissedCycles[id] = 0
            } else {
                bleMissedCycles[id] = (bleMissedCycles[id] ?? 0) + 1
            }
        }
    }
}

#Preview { DemoScanDevicesView() }

// MARK: - Color helpers
extension Color {
    init(hex: String, alpha: Double = 1.0) {
        var hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexString.count {
        case 3: (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: alpha)
    }
}
