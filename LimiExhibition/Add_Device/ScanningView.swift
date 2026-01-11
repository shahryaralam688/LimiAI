//
//  ScanningView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//



import SwiftUI
import CoreBluetooth

struct ScanningView: View {
    let progress: Double
    let isAnimating: Bool
    let onBack: () -> Void

    @State private var rotation: Double = 0
    @State private var particlePositions: [(x: Double, y: Double, size: Double, speed: Double)] = []
    @State private var showBluetoothAlert = false
    @State private var showDevicesList = false
    @State private var discoveredDevices: [(name: String, id: String)] = []
    @State private var showHubHomeView = false // State for fullscreen navigation
    @State private var currentProgress: Int = 1
    @State private var showOfflineAlert = false // Add this state variable
    @State private var showDeveloperModeAlert = false
    @StateObject private var sharedDevice = SharedDevice.shared
    @State private var isLoading = false

    // Bluetooth Manager
    @StateObject private var bluetoothManager = BluetoothManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Navigation bar
                HStack {
                    Button(action: {
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.leading, 20)
                
                Spacer()
                
                // Title
                Text("Looking for\nnearby devices")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                
                // Scanning animation
                ZStack {
                    // Outer circles
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.alabaster.opacity(0.3), lineWidth: 1)
                            .frame(width: 280 - Double(i) * 60, height: 280 - Double(i) * 60)
                    }
                    
                    // Rotating circle
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 280, height: 280)
                        .rotationEffect(Angle(degrees: rotation))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                            
                            // Initialize particles
                            particlePositions = (0..<15).map { _ in
                                let distance = Double.random(in: 20...140)
                                let angle = Double.random(in: 0...360)
                                let x = cos(angle * .pi / 180) * distance
                                let y = sin(angle * .pi / 180) * distance
                                let size = Double.random(in: 2...6)
                                let speed = Double.random(in: 0.5...2.0)
                                return (x: x, y: y, size: size, speed: speed)
                            }
                        }
                    
                    // Progress indicator
                    ZStack {
                        Circle()
                            .fill(Color.alabaster.opacity(0.5))
                            .frame(width: 100, height: 100)
                        Text("\(Int(currentProgress))%")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Color.charlestonGreen)
                    }
                }
                .frame(height: 300)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.charlestonGreen)
            
            .onAppear {
                checkBluetoothStatus()

                // Start a timer that updates progress step-by-step
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    if currentProgress < 100 {
                        currentProgress += 1
                    } else {
                        timer.invalidate() // Stop the timer when it reaches 100
//                        bluetoothManager.stopScanning() // Stop scanning in the backend

                    }
                }

                // Call fetchData function with the desired URL
//                fetchData(from: "https://example.com/api/devices")
            }
            .alert(isPresented: $showBluetoothAlert) {
                Alert(
                    title: Text("Bluetooth is turned off"),
                    message: Text("Turn on Bluetooth to scan for nearby devices."),
                    primaryButton: .default(Text("Settings"), action: openBluetoothSettings),
                    secondaryButton: .cancel()
                )
            }
            
            // Device List Popup
            if showDevicesList {
                Color.charlestonGreen.opacity(0.5) // Background blur effect
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showDevicesList = false
                    }
                
                VStack(spacing: 16) {
                    Text("Discovered Devices")
                        .font(.headline)
                        .foregroundColor(.charlestonGreen)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(discoveredDevices.filter {
                                $0.name == "LIMI-CONTROLLER" ||
                                $0.name == "16 CH-HUB" ||
                                $0.name == "1 CH-HUB" 
                            }, id: \.id) { device in
                                Text("\(device.name)")
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.alabaster.opacity(0.9))
                                    .cornerRadius(8)
                                    .foregroundColor(.charlestonGreen)
                                    .onTapGesture {
                                        isLoading = true
                                        print("Starting device connection...")
                                        bluetoothManager.connectToDevice(deviceId: device.id)
                                        showHubHomeView = true
                                        
                                        // First wait 2 seconds to show loading
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                                                isLoading = false
//                                                
//                                                // Then handle the connection logic
//                                                let receivedBytes = SharedDevice.shared.lastReceivedBytes
//                                                print("⚡️ Checking received bytes: \(receivedBytes)")
//                                                
//                                                showDevicesList = false
//                                                if UserRoleManager.shared.currentRole == .productionUser  {
//                                                    showDeveloperModeAlert = true
//                                                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
//                                                    let window = windowScene?.windows.first
//                                                    window?.rootViewController = UIHostingController(rootView: ContentView())
//                                                    
//                                                } else {
//                                                        if !SharedDevice.shared.lastReceivedBytes.isEmpty &&
//                                                       SharedDevice.shared.lastReceivedBytes[0] == 91 {
//                                                        print("✅ Normal mode detected: \(SharedDevice.shared.lastReceivedBytes)")
//                                                        print("Regular user - showing hub home")
//                                                        showHubHomeView = true
//                                                        
//                                                        // Send device info to the API
//                                                        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
//                                                        sendDeviceInfo(deviceInfo: deviceInfo)
//
//                                                    } else {
//                                                        print("❌ Invalid mode")
//                                                        print("Expected: Normal mode (91)")
//                                                        print("Received: \(SharedDevice.shared.lastReceivedBytes)")
//                                                        bluetoothManager.disconnectCurrentDevice()
//                                                        showOfflineAlert = true
//                                                    }
//                                                }
//                                            }
                                    }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 600)
                    .background(Color.charlestonGreen.opacity(0.7))
                    .cornerRadius(12)
                    
                    Button(action: {
                        showDevicesList = false
                    }) {
                        Image("closeicon")
                            .renderingMode(.template)
                            .foregroundColor(.emerald)
                            .frame(width: 34, height: 34)
                    }
                }
                .padding()
                .background(Color.alabaster)
                .cornerRadius(16)
                .frame(maxWidth: 350)
                .shadow(radius: 10)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .fullScreenCover(isPresented: $showHubHomeView) {
            //HubContentView()
            HomeView()
        }
        .alert(isPresented: $showDeveloperModeAlert) {
            Alert(
                title: Text("Developer Mode"),
                message: nil,
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showOfflineAlert) {
            Alert(
                title: Text("Please Set Normal MOde "),
                message: Text("The selected device is not responding. Please try again."),
                dismissButton: .default(Text("OK")){
                    // Navigate to ContentView
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    let window = windowScene?.windows.first
                    window?.rootViewController = UIHostingController(rootView: GetStart())
                }
            )
        }
        // Inside the main ZStack, after all other views and alerts
        if isLoading {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                Text("Connecting with Device")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top, 20)
            }
        }
    }
    
    func fetchData(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error as NSError? {
                switch error.code {
                case NSURLErrorCannotFindHost:
                    print("Error: Cannot find host")
                case NSURLErrorNotConnectedToInternet:
                    print("Error: Not connected to the internet")
                default:
                    print("Error: \(error.localizedDescription)")
                }
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            // Process the data
            print("Data received: \(data)")
        }

        task.resume()
    }
    
    private func checkBluetoothStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if bluetoothManager.isBluetoothOn {
                showBluetoothAlert = false
                bluetoothManager.startScanning { devices in
                    let filteredDevices = devices.filter {
                        $0.name == "LIMI-CONTROLLER" ||
                        $0.name == "16 CH-HUB" ||
                        $0.name == "1 CH-HUB"
                    }
                    self.discoveredDevices = filteredDevices
                    if !filteredDevices.isEmpty {
                        self.showDevicesList = true
                    }
                }
            } else {
                showBluetoothAlert = true
            }
        }
    }
    
    private func openBluetoothSettings() {
        if let url = URL(string: "App-Prefs:root=Bluetooth"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    // Inside the ScanningView struct

    private func sendDeviceInfo(deviceInfo: String) {
        guard let url = URL(string: APIConstants.addDeviceInfo) else {
            print("Invalid URL")
            return
        }

        // Retrieve the token from app storage (UserDefaults in this case)
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("No token found")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set the token in the Authorization header
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")

        let json: [String: Any] = ["deviceInfo": deviceInfo]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            print("Error serializing JSON")
            return
        }

        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending device info: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            // Process the response
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response from server: \(responseString)")
            }
        }

        task.resume()
    }

}
