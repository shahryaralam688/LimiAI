//
//  WLEDController.swift
//  Limi
//
//  Created by Mac Mini on 02/10/2025.
//

import SwiftUI
import Foundation
import Network
import Darwin

// MARK: - WLED Device Model

struct WLEDDevice: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let ip: String
    let port: Int
    let location: String
    var isOnline: Bool = true
    
    var baseURL: String {
        return AppURLs.WLED.deviceBase(ip: ip, port: port)
    }
    
    init(name: String, ip: String, port: Int, location: String) {
        self.name = name
        self.ip = ip
        self.port = port
        self.location = location
    }
}

// MARK: - SSDP Discovery Manager

class SSDPDiscoveryManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [WLEDDevice] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    private var udpConnection: NWConnection?
    private var listener: NWListener?
    // mDNS (Bonjour)
    private var mdnsBrowser: NetServiceBrowser?
    private var mdnsHTTPBrowser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []
    private let multicastGroup = "239.255.255.250"
    private let ssdpPort: UInt16 = 1900
    private let searchTarget = "ssdp:all"
    
    // MARK: - SSDP Discovery Methods
    
    func startDiscovery() {
        print("🔍 SSDP - Starting device discovery...")
        
        DispatchQueue.main.async {
            self.isScanning = true
            self.discoveredDevices.removeAll()
            self.errorMessage = nil
        }
        
        sendMSearchRequest()
        
        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        print("🛑 SSDP - Stopping device discovery...")
        
        udpConnection?.cancel()
        udpConnection = nil
        
        listener?.cancel()
        listener = nil
        
        // Stop mDNS Browser
        mdnsBrowser?.stop()
        mdnsBrowser = nil
        mdnsHTTPBrowser?.stop()
        mdnsHTTPBrowser = nil
        resolvingServices.forEach { $0.stop() }
        resolvingServices.removeAll()
        
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
    
    private func sendMSearchRequest() {
        // Create UDP listener for receiving responses
        setupListener()
        
        // Send M-SEARCH broadcast
        sendBroadcastMessage()
        
        // Start Bonjour/mDNS discovery for WLED
        startMDNSDiscovery()
    }
    
    private func setupListener() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredInterfaceType = .wifi
            
            listener = try NWListener(using: parameters)
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("📡 SSDP - New connection received")
                connection.start(queue: .global())
                self?.handleIncomingConnection(connection)
            }
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ SSDP - Listener ready")
                case .failed(let error):
                    print("❌ SSDP - Listener failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.start(queue: .global())
        } catch {
            print("❌ SSDP - Failed to create listener: \(error)")
        }
    }
    
    private func sendBroadcastMessage() {
        // Create broadcast connection
        let host = NWEndpoint.Host(multicastGroup)
        let port = NWEndpoint.Port(rawValue: ssdpPort)!
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .wifi
        
        udpConnection = NWConnection(to: endpoint, using: parameters)
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ SSDP - Broadcast connection ready")
                self?.sendMSearchMessage()
            case .failed(let error):
                print("❌ SSDP - Broadcast connection failed: \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    self?.isScanning = false
                }
            default:
                break
            }
        }
        
        udpConnection?.start(queue: .global())
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let error = error {
                print("❌ SSDP - Receive error: \(error)")
                return
            }
            
            if let data = data, let response = String(data: data, encoding: .utf8) {
                print("📥 SSDP - Received response:")
                print(response)
                self?.parseSSDPResponse(response)
            }
            
            // Continue listening
            self?.handleIncomingConnection(connection)
        }
    }
    
    private func sendMSearchMessage() {
        // Send multiple M-SEARCH requests with different search targets
        let searchTargets = ["ssdp:all", "upnp:rootdevice", "urn:schemas-upnp-org:device:Basic:1"]
        
        for target in searchTargets {
            let mSearchMessage = """
            M-SEARCH * HTTP/1.1\r
            HOST: \(multicastGroup):\(ssdpPort)\r
            MAN: "ssdp:discover"\r
            ST: \(target)\r
            MX: 5\r
            \r
            
            """
            
            let data = mSearchMessage.data(using: .utf8)!
            
            print("📤 SSDP - Sending M-SEARCH request for \(target):")
            print(mSearchMessage)
            
            udpConnection?.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ SSDP - Failed to send M-SEARCH for \(target): \(error)")
                } else {
                    print("✅ SSDP - M-SEARCH request sent successfully for \(target)")
                }
            })
            
            // Small delay between requests
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Also try direct IP scanning as fallback
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            self.scanLocalNetwork()
        }
    }

    // MARK: - mDNS (Bonjour) Discovery
    private func startMDNSDiscovery() {
        let browser = NetServiceBrowser()
        browser.includesPeerToPeer = false
        browser.delegate = self
        mdnsBrowser = browser
        // WLED advertises _wled._tcp. on local domain
        print("🔎 mDNS - Starting Bonjour browse for _wled._tcp.")
        browser.searchForServices(ofType: "_Limi1Ch._udp.", inDomain: "local.")
        
        // Also browse HTTP services, then verify via /json/info
        let httpBrowser = NetServiceBrowser()
        httpBrowser.includesPeerToPeer = false
        httpBrowser.delegate = self
        mdnsHTTPBrowser = httpBrowser
        print("🔎 mDNS - Starting Bonjour browse for _http._tcp.")
        httpBrowser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
    }
    
    private func scanLocalNetwork() {
        print("🔍 SSDP - Starting direct IP scan as fallback...")
        
        // Get local network IP range
        guard let localIP = getLocalIPAddress() else {
            print("❌ SSDP - Could not determine local IP address")
            return
        }
        
        print("📍 SSDP - Local IP: \(localIP)")
        
        // Extract network prefix (e.g., 192.168.1.x)
        let components = localIP.components(separatedBy: ".")
        if components.count == 4 {
            let networkPrefix = "\(components[0]).\(components[1]).\(components[2])"
            
            // Scan common IP ranges
            for i in 1...254 {
                let testIP = "\(networkPrefix).\(i)"
                checkWLEDDevice(ip: testIP)
            }
        }
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" || name == "en1" { // WiFi or Ethernet
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    private func checkWLEDDevice(ip: String) {
        let deviceURL = AppURLs.WLED.deviceInfo(ip: ip)
        
        guard let url = URL(string: deviceURL) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0 // Quick timeout for scanning
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if error != nil {
                // Silently ignore errors during scanning
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check if this looks like a WLED device
                    if let name = json["name"] as? String {
                        print("🎯 SSDP - Found WLED device via direct scan: \(name) at \(ip)")
                        self?.addDevice(name: name, ip: ip, port: 80, location: AppURLs.WLED.deviceBase(ip: ip))
                    }
                }
            } catch {
                // Ignore JSON parsing errors
            }
        }.resume()
    }
    
    private func parseSSDPResponse(_ response: String) {
        let lines = response.components(separatedBy: .newlines)
        var location: String?
        var server: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.lowercased().hasPrefix("location:") {
                location = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.lowercased().hasPrefix("server:") {
                server = String(trimmedLine.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Check if this might be a WLED device
        if let location = location,
           let server = server,
           (server.lowercased().contains("wled") || 
            server.lowercased().contains("esp") ||
            location.lowercased().contains("wled")) {
            
            print("🎯 SSDP - Potential WLED device found:")
            print("   Location: \(location)")
            print("   Server: \(server)")
            
            extractDeviceInfo(from: location, server: server)
        }
    }
    
    private func extractDeviceInfo(from location: String, server: String) {
        guard let url = URL(string: location) else {
            print("❌ SSDP - Invalid location URL: \(location)")
            return
        }
        
        let ip = url.host ?? "unknown"
        let port = url.port ?? 80
        
        // Try to get device name from WLED API
        fetchDeviceName(ip: ip, port: port, location: location, server: server)
    }
    
    private func fetchDeviceName(ip: String, port: Int, location: String, server: String) {
        let deviceURL = AppURLs.WLED.deviceInfo(ip: ip, port: port)
        
        guard let url = URL(string: deviceURL) else {
            print("❌ SSDP - Invalid device URL: \(deviceURL)")
            return
        }
        
        print("📡 SSDP - Fetching device info from: \(deviceURL)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ SSDP - Failed to fetch device info: \(error)")
                // Create device with fallback name
                self?.addDevice(name: "WLED Device", ip: ip, port: port, location: location)
                return
            }
            
            guard let data = data else {
                print("❌ SSDP - No data received from device")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let deviceName = json["name"] as? String ?? "WLED Device"
                    print("✅ SSDP - Device name: \(deviceName)")
                    self?.addDevice(name: deviceName, ip: ip, port: port, location: location)
                } else {
                    print("❌ SSDP - Invalid JSON response")
                    self?.addDevice(name: "WLED Device", ip: ip, port: port, location: location)
                }
            } catch {
                print("❌ SSDP - JSON parsing error: \(error)")
                self?.addDevice(name: "WLED Device", ip: ip, port: port, location: location)
            }
        }.resume()
    }
    
    private func addDevice(name: String, ip: String, port: Int, location: String) {
        let device = WLEDDevice(name: name, ip: ip, port: port, location: location)
        
        DispatchQueue.main.async {
            // Check if device already exists
            if !self.discoveredDevices.contains(where: { $0.ip == ip && $0.port == port }) {
                self.discoveredDevices.append(device)
                print("✅ SSDP - Added device: \(name) at \(ip):\(port)")
            }
        }
    }

    // MARK: - mDNS Delegates & Helpers
}

extension SSDPDiscoveryManager: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("🔎 mDNS - Found service: \(service.name) at type: \(service.type)")
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5.0)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        defer {
            if let idx = resolvingServices.firstIndex(where: { $0 === sender }) {
                resolvingServices.remove(at: idx)
            }
        }

        guard let addresses = sender.addresses else { return }
        for addressData in addresses {
            if let (ip, port) = ipPortFrom(addressData: addressData) {
                let name = sender.name
                let location = AppURLs.WLED.deviceBase(ip: ip, port: port)
                print("✅ mDNS - Resolved WLED service: \(name) -> \(ip):\(port)")
                addDevice(name: name, ip: ip, port: port, location: location)
                break
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("❌ mDNS - Failed to resolve service: \(sender.name), error: \(errorDict)")
        if let idx = resolvingServices.firstIndex(where: { $0 === sender }) {
            resolvingServices.remove(at: idx)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("❌ mDNS - Browser error: \(errorDict)")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("🛑 mDNS - Stopped browsing")
    }

    // Extract IPv4 from sockaddr data
    private func ipPortFrom(addressData: Data) -> (String, Int)? {
        return addressData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> (String, Int)? in
            guard let addrPtr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return nil }
            if addrPtr.pointee.sa_family == sa_family_t(AF_INET) {
                let addrIn = UnsafeRawPointer(addrPtr).assumingMemoryBound(to: sockaddr_in.self)
                var addr = addrIn.pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                let ipCString = inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                let ip = ipCString != nil ? String(cString: buffer) : nil
                let port = Int(UInt16(bigEndian: addrIn.pointee.sin_port))
                if let ip = ip { return (ip, port) }
            }
            return nil
        }
    }
}

// MARK: - WLED Device Controller

@MainActor
class WLEDDeviceController: ObservableObject {
    @Published var isConnected = false
    @Published var deviceState: WLEDDeviceState?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var device: WLEDDevice
    
    init(device: WLEDDevice) {
        self.device = device
    }
    
    // MARK: - Device State Model
    
    struct WLEDDeviceState: Codable {
        let on: Bool
        let bri: Int
        let seg: [Segment]
        
        struct Segment: Codable {
            let id: Int
            let start: Int
            let stop: Int
            let col: [[Int]]
            let fx: Int
            let sx: Int
            let ix: Int
            let pal: Int
        }
    }
    
    // MARK: - API Methods
    
    func fetchState() async {
        await performRequest(endpoint: "/json/state") { (state: WLEDDeviceState) in
            DispatchQueue.main.async {
                self.deviceState = state
                self.isConnected = true
                self.errorMessage = nil
            }
        }
    }
    
    func setPower(_ isOn: Bool) async {
        let payload = ["on": isOn]
        await sendCommand(payload: payload)
    }
    
    func setBrightness(_ brightness: Int) async {
        let payload = ["bri": max(0, min(255, brightness))]
        await sendCommand(payload: payload)
    }
    
    func setColor(red: Int, green: Int, blue: Int) async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "col": [[red, green, blue]]
                ]
            ]
        ]
        await sendCommand(payload: payload)
    }
    
    // MARK: - Private Helper Methods
    
    private func performRequest<T: Codable>(endpoint: String, completion: @escaping (T) -> Void) async {
        guard let url = URL(string: device.baseURL + endpoint) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isConnected = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            completion(decodedData)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isConnected = false
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    private func sendCommand(payload: [String: Any]) async {
        guard let url = URL(string: device.baseURL + "/json/state") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await fetchState()
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Command failed"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Send error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - WLED Discovery View

struct WLEDDiscoveryView: View {
    @StateObject private var discoveryManager = SSDPDiscoveryManager()
    @State private var selectedDevice: WLEDDevice?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Device List
                if discoveryManager.discoveredDevices.isEmpty && !discoveryManager.isScanning {
                    emptyStateView
                } else {
                    deviceListView
                }
                
                Spacer()
            }
            .background(Color.appCanvasHotel)
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
            .onAppear {
                discoveryManager.startDiscovery()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 15) {
            Text("WLED Device Discovery")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.themeWhite)
            
            Button(action: {
                discoveryManager.startDiscovery()
            }) {
                HStack {
                    if discoveryManager.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    
                    Text(discoveryManager.isScanning ? "Scanning..." : "Scan for Devices")
                        .fontWeight(.medium)
                }
                .foregroundColor(.themeWhite)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(discoveryManager.isScanning ? Color.gray : Color.blue)
                )
            }
            .disabled(discoveryManager.isScanning)
            
            if let errorMessage = discoveryManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.appDanger)
                    .font(.caption)
            }
        }
        .background(Color.appCanvasHotel)
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.appTextMuted)
            
            Text("No WLED devices found")
                .font(.title2)
                .foregroundColor(.appTextMuted)
            
            Text("Make sure your WLED devices are connected to the same Wi-Fi network")
                .font(.body)
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var deviceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(discoveryManager.discoveredDevices) { device in
                    DeviceRowView(device: device) {
                        selectedDevice = device
                    }
                }
            }
        }
        .sheet(item: $selectedDevice) { device in
            WLEDDeviceControlView(device: device)
        }
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: WLEDDevice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.themeWhite)
                    
                    Text("\(device.ip):\(device.port)")
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundColor(.appTextMuted)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.appTextMuted)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - WLED Device Control View

struct WLEDDeviceControlView: View {
    let device: WLEDDevice
    @StateObject private var controller: WLEDDeviceController
    @State private var brightness: Double = 128
    @State private var isOn = false
    @State private var selectedColor = Color.red
    @Environment(\.dismiss) private var dismiss
    
    init(device: WLEDDevice) {
        self.device = device
        self._controller = StateObject(wrappedValue: WLEDDeviceController(device: device))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Device Info
                deviceInfoView
                
                // Controls
                controlsView
                
                Spacer()
            }
            .padding()
            .background(Color.appCanvasPrimary.ignoresSafeArea())
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await controller.fetchState()
                if let state = controller.deviceState {
                    isOn = state.on
                    brightness = Double(state.bri)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var deviceInfoView: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(controller.isConnected ? "Connected" : "Disconnected")
                    .foregroundColor(.appTextMuted)
            }
            
            Text("\(device.ip):\(device.port)")
                .font(.caption)
                .foregroundColor(.appTextMuted)
            
            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.appDanger)
                    .font(.caption)
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 25) {
            // Power Toggle
            powerToggleView
            
            // Brightness Slider
            brightnessSliderView
            
            // Color Picker
            colorPickerView
        }
    }
    
    private var powerToggleView: some View {
        HStack {
            Text("Power")
                .font(.headline)
                .foregroundColor(.themeWhite)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: isOn) { _, newValue in
                    let controller = self.controller
                    Task {
                        await controller.setPower(newValue)
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private var brightnessSliderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Brightness")
                    .font(.headline)
                    .foregroundColor(.themeWhite)
                
                Spacer()
                
                Text("\(Int((brightness / 255) * 100))%")
                    .foregroundColor(.appTextMuted)
            }
            
            Slider(value: $brightness, in: 0...255, step: 1)
                .accentColor(.blue)
                .onChange(of: brightness) { _, newValue in
                    let controller = self.controller
                    Task {
                        await controller.setBrightness(Int(newValue))
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private var colorPickerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.headline)
                .foregroundColor(.themeWhite)
            
            ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newColor in
                    let controller = self.controller
                    let rgb = newColor.toRGBValues()
                    Task {
                        await controller.setColor(red: rgb.red, green: rgb.green, blue: rgb.blue)
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

// MARK: - Color Extension (Private to avoid conflicts)

private extension Color {
    func toRGBValues() -> (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (
            red: Int(red * 255),
            green: Int(green * 255),
            blue: Int(blue * 255)
        )
    }
}

// MARK: - Preview

struct WLEDDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        WLEDDiscoveryView()
    }
}
