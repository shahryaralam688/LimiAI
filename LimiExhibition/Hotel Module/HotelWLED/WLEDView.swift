//
//  WLEDView.swift
//  Limi
//
//  Created by Mac Mini on 02/10/2025.
//

import SwiftUI
import Foundation
import UIKit
import Network

// MARK: - WLED API Manager

/// Manager class for handling all WLED REST/JSON API communications
@MainActor
class WLEDAPIManager: ObservableObject {
    private let baseURL = AppURLs.WLED.localHost
    
    // MARK: - Data Models
    
    struct WLEDState: Codable {
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
    
    struct WLEDInfo: Codable {
        let ver: String
        let vid: Int
        let leds: LEDInfo
        
        struct LEDInfo: Codable {
            let count: Int
            let pwr: Int
            let fps: Int
            let maxpwr: Int
            let maxseg: Int
        }
    }
    
    struct WLEDEffect: Codable, Identifiable {
        let id: Int
        let name: String
        
        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }
    
    struct WLEDPalette: Codable, Identifiable {
        let id: Int
        let name: String
        
        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }
    
    struct WLEDPreset: Codable, Identifiable {
        let id: Int
        let name: String
        let on: Bool
        let bri: Int
        let colors: [[Int]]
        let effect: Int
        let palette: Int
        
        init(id: Int, name: String, on: Bool, bri: Int, colors: [[Int]], effect: Int, palette: Int) {
            self.id = id
            self.name = name
            self.on = on
            self.bri = bri
            self.colors = colors
            self.effect = effect
            self.palette = palette
        }
    }
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var currentState: WLEDState?
    @Published var deviceInfo: WLEDInfo?
    @Published var effects: [WLEDEffect] = []
    @Published var palettes: [WLEDPalette] = []
    @Published var presets: [WLEDPreset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - API Methods
    
    /// Fetch current WLED state
    func fetchState() async {
        await performRequest(endpoint: "/json/state") { (state: WLEDState) in
            DispatchQueue.main.async {
                self.currentState = state
                self.isConnected = true
                self.errorMessage = nil
            }
        }
    }
    
    /// Fetch device information
    func fetchInfo() async {
        await performRequest(endpoint: "/json/info") { (info: WLEDInfo) in
            DispatchQueue.main.async {
                self.deviceInfo = info
            }
        }
    }
    
    /// Fetch available effects
    func fetchEffects() async {
        await performRequest(endpoint: "/json/effects") { (effectNames: [String]) in
            DispatchQueue.main.async {
                self.effects = effectNames.enumerated().map { WLEDEffect(id: $0.offset, name: $0.element) }
            }
        }
    }
    
    /// Fetch available palettes
    func fetchPalettes() async {
        await performRequest(endpoint: "/json/palettes") { (paletteNames: [String]) in
            DispatchQueue.main.async {
                self.palettes = paletteNames.enumerated().map { WLEDPalette(id: $0.offset, name: $0.element) }
            }
        }
    }
    
    /// Set power state
    func setPower(_ isOn: Bool) async {
        let payload = ["on": isOn]
        print("🔌 WLED API - Setting power: \(isOn)")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Set brightness (0-255)
    func setBrightness(_ brightness: Int) async {
        let payload = ["bri": max(0, min(255, brightness))]
        print("💡 WLED API - Setting brightness: \(brightness)")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Set single color (RGB)
    func setColor(red: Int, green: Int, blue: Int) async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "start": 0,
                    "stop": 256,
                    "col": [[red, green, blue]]
                ]
            ]
        ]
        print("🎨 WLED API - Setting color for all 256 LEDs: RGB(\(red), \(green), \(blue))")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Set custom color pattern (multiple colors)
    func setColorPattern(_ colors: [[Int]]) async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "start": 0,
                    "stop": 256,
                    "col": colors
                ]
            ]
        ]
        print("🌈 WLED API - Setting color pattern for all 256 LEDs: \(colors.count) colors")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Set effect
    func setEffect(_ effectId: Int) async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "start": 0,
                    "stop": 256,
                    "fx": effectId
                ]
            ]
        ]
        print("✨ WLED API - Setting effect ID \(effectId) for all 256 LEDs")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Set palette
    func setPalette(_ paletteId: Int) async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "start": 0,
                    "stop": 256,
                    "pal": paletteId
                ]
            ]
        ]
        print("🎨 WLED API - Setting palette ID \(paletteId) for all 256 LEDs")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Save current settings as preset
    func savePreset(id: Int, name: String) async {
        guard let state = currentState else { return }
        
        let preset = [
            "psave": id,
            "n": name,
            "on": state.on,
            "bri": state.bri,
            "seg": state.seg.map { segment in
                [
                    "id": segment.id,
                    "col": segment.col,
                    "fx": segment.fx,
                    "pal": segment.pal
                ]
            }
        ] as [String: Any]
        
        await sendCommand(payload: preset)
    }
    
    /// Load preset
    func loadPreset(_ presetId: Int) async {
        let payload = ["ps": presetId]
        print("💾 WLED API - Loading preset ID: \(presetId)")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    /// Initialize segment to cover all 256 LEDs
    func initializeFullSegment() async {
        let payload = [
            "seg": [
                [
                    "id": 0,
                    "start": 0,
                    "stop": 256,
                    "on": true
                ]
            ]
        ]
        print("🔧 WLED API - Initializing segment for all 256 LEDs")
        print("📤 Payload: \(payload)")
        await sendCommand(payload: payload)
    }
    
    // MARK: - Private Helper Methods
    
    private func performRequest<T: Codable>(endpoint: String, completion: @escaping (T) -> Void) async {
        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ WLED API - Invalid URL: \(baseURL + endpoint)")
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isConnected = false
            }
            return
        }
        
        print("📡 WLED API - GET Request to: \(url.absoluteString)")
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 WLED API - Response Status: \(httpResponse.statusCode)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 WLED API - Response Data: \(jsonString)")
            }
            
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            completion(decodedData)
            print("✅ WLED API - Request successful")
        } catch {
            print("❌ WLED API - Network error: \(error.localizedDescription)")
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
        guard let url = URL(string: baseURL + "/json/state") else {
            print("❌ WLED API - Invalid URL for command: \(baseURL + "/json/state")")
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 WLED API - POST Request to: \(url.absoluteString)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 WLED API - Sending JSON: \(jsonString)")
            }
            
            request.httpBody = jsonData
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 WLED API - Command Response Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 WLED API - Command Response Data: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ WLED API - Command successful")
                    // Refresh state after successful command
                    await fetchState()
                } else {
                    print("❌ WLED API - Command failed with status: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Command failed with status: \(httpResponse.statusCode)"
                    }
                }
            }
        } catch {
            print("❌ WLED API - Send error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Send error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Color Extension for RGB Conversion

extension Color {
    func toRGB() -> (red: Int, green: Int, blue: Int) {
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
    
    static func fromRGB(red: Int, green: Int, blue: Int) -> Color {
        return Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }
    
}
struct WLEDView: View {
    @StateObject private var apiManager = WLEDAPIManager()
    @State private var selectedHue: Double = 0.0
    @State private var brightness: Double = 128 // Slider drives 0...255 for UI/thumb location
    @State private var selectedEffect = 0
    @State private var showingColorPicker = false
    @State private var selectedTopTab: Int = 0 // 0 = Offline, 1 = Customize
    @State private var isOnline: Bool = true
    @State private var showToast: Bool = false

    // rainBow Color Bar Variable
    @AppStorage("lampRGB") private var isOn: Bool = false
    @AppStorage("RGBBrightness") private var RGBBrightness: Double = 50 // Device brightness 0...100
    @State private var colorValue: Double = 0.0 // Represents position on rainbow slider
    @AppStorage("selectedColorHex") private var selectedColorHex: String = AppThemeDefaults.selectedColorHex
    @State private var selectedColor: Color = Color(hex: UserDefaults.standard.string(forKey: "selectedColorHex") ?? AppThemeDefaults.selectedColorHex)
    @State private var patternSpeed: Double = 50      // 0-100 UI
    @State private var patternIntensity: Double = 50  // 0-100 UI
    @State private var hasSelectedPattern: Bool = false
    @State private var lastSentBrightnessStep: Int?
    private var hexColor: Color {
        Color(hex: selectedColorHex)
    }
    // Golable Variavble
    let chennalMac: String?
    let chennelPosition : Int?

    let selectColorObj =  LightControllingSocket.shared
    @State private var showSolidColor: Bool = true // State variable to toggle between sliders

    private var brightnessPercent: Double { (brightness / 255.0) * 100.0 }

    
    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 20) {
                    // Custom Title with safe area
                    VStack(spacing: 12) {
                        ZStack(alignment: .topTrailing) {
                            // Content stays in place
                            Group {
                                if selectedTopTab == 0 {
                                    StaticLightARViewContainer(macAddress: chennalMac)
                                        .frame(height: 400)
                                        .cornerRadius(16)
                                        .clipped()
                                } else {
                                    if let token = AuthManager.shared.getToken(),
                                       let url = URL(string: AppURLs.Web.configuratorV2(token: token)) {
                                        LimiWebViewCon(url: url, macAddress: chennalMac)
                                            .frame(height: 450)
                                            .cornerRadius(16)
                                            .clipped()
                                        
                                    }
                                }
                            }

                            // Buttons overlaid on top with padding, without shifting content
                            HStack(spacing: 10) {
                                Spacer()
                                Button(action: {
                                    if selectedTopTab == 0 {
                                        if isOnline { selectedTopTab = 1 } else { showToast = true }
                                    } else {
                                        selectedTopTab = 0
                                    }
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.appTextPrimary)
                                        .frame(width: 36, height: 36)
                                        .background((selectedTopTab == 1 ? Color.orbGlow4 : Color.gray.opacity(0.4)))
                                        .clipShape(Circle())
                                }
                                
                            }
                            .padding(12)
                        }
                    }
                    
                    // Power Toggle Button
                    powerToggleButton
                    
                    // Brightness Bar
                    brightnessBar
                    
                    // Rainbow Color Bar
//                    rainbowColorBar
                    
                    VStack {
                        HStack{
                            Text("Select Color")
                                .font(.system(size: 18, weight: .bold, design: .rounded)) // Bold weight
                                .foregroundColor(.appTextPrimary)
                                .kerning(0.9)        // 5% of 18px ≈ 0.9 pts
                                .lineSpacing(0)      // line-height = 100%
                                .lineLimit(1)        // prevent wrapping
                                .fixedSize()         // keeps alignment tight

                            Spacer()
                        }
                        
                        
                        
                        // Toggle buttons for Solid Color and Rainbow Color
                        HStack {
                            Button(action: {
                                showSolidColor = true
                            }) {
                                Text("Solid Color")
                                    .padding(8)
                                    .background(showSolidColor ? Color.orbGlow4 : Color.eton.opacity(0.4))
                                    .foregroundColor(.appTextPrimary)
                                    .cornerRadius(8)
                            }
                            .disabled(!isOn)
                            .opacity(isOn ? 1.0 : 0.4)
                            
                            Button(action: {
                                showSolidColor = false
                            }) {
                                Text("Rainbow Color")
                                    .padding(8)
                                    .background(!showSolidColor ? Color.orbGlow4 : Color.eton.opacity(0.4))
                                    .foregroundColor(.themeWhite)
                                    .cornerRadius(8)
                            }
                            .disabled(!isOn)
                            .opacity(isOn ? 1.0 : 0.4)
                        }
                        .padding(.bottom, 20)
                        
                        // Show the appropriate slider based on the toggle
                        if showSolidColor {
                                ColorCircleSlider(selectedColor: $selectedColor)
                                    .frame(height: 20)
                                    .onChange(of: selectedColor) { oldValue, newValue in
                                        // Haptic feedback
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        sendHapticFeedback()
                                        // Send color to LED
                                        sendColorToLED(selectedColor)
                                    }
                                    .disabled(!isOn)
                                    .opacity(isOn ? 1.0 : 0.4)

                        } else {
                            RainbowSlider(value: $colorValue, selectedColor: $selectedColor)
                                .frame(height: 20)
                                .onChange(of: colorValue) { oldValue, newValue in
                                    selectedColor = getColorFromSlider(newValue)
                                    sendColorToLED(selectedColor)
                                    sendHapticFeedback()
                                    // Haptic feedback on value change
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                                .disabled(!isOn)
                                .opacity(isOn ? 1.0 : 0.4)
                        }
                        
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.appSurfacePrimary)
                    )
                    .padding(.bottom, 20)
                    
                    // Effects Horizontal Scroll
                    effectsScrollView

                    // Pattern Speed & Intensity Controls (only after a pattern is selected)
                    if hasSelectedPattern {
                        patternControls
                    }
                }
                .padding(.horizontal)
                
                // Bottom spacing for safe area
                Spacer(minLength: 30)
            }.padding()
        }
        .background(Color.appCanvasPrimary)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if showToast {
                Text("Please connect to internet.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.themeBlack.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .padding(.top, 0)
//        .padding(.horizontal, 16)
        .task {
            // Initialize segment to cover all 256 LEDs
            await apiManager.initializeFullSegment()
            
            // Fetch device data
            await apiManager.fetchEffects()
            await apiManager.fetchState()
            
            // Update UI state from API response
            if let state = apiManager.currentState {
                DispatchQueue.main.async {
                    self.isOn = state.on
                    self.brightness = Double(state.bri)
                    self.RGBBrightness = (Double(state.bri) / 255.0) * 100.0
                    self.lastSentBrightnessStep = Int(self.RGBBrightness.rounded())
                    self.selectedEffect = state.seg.first?.fx ?? 0
                }
            }
        }
        .onChange(of: selectedColor) { oldValue, newValue in
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            selectedColorHex = newValue.toHex()
        }

        .onAppear {
            print("appear")
            selectColorObj.connect()
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                DispatchQueue.main.async {
                    isOnline = (path.status == .satisfied)
                    if !isOnline && selectedTopTab == 1 {
                        selectedTopTab = 0
                        showToast = true
                    }
                }
            }
            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.start(queue: queue)
        }
        .onChange(of: showToast) { old, newVal in
            if newVal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showToast = false }
                }
            }
        }
        .onChange(of: selectedColor) { oldValue, newValue in
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            selectedColorHex = newValue.toHex()
        }
    }
    
    func sendColorToLED(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert to 0-255 integer range
        let redValue = Int(red * 255)
        let greenValue = Int(green * 255)
        let blueValue = Int(blue * 255)
        
        let brightnessValue = Int(min(max(RGBBrightness.rounded(), 0), 100))
        
        // Convert all to strings for message array
        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(chennelPosition ?? 1),
            String(redValue),
            String(greenValue),
            String(blueValue),
            String(brightnessValue)
        ]
        
        // Prepare and send combined info
        sendMessage(message: byteArray)
    }
    func updateBrightness(_ brightness100: Double, selectedColor: Color) {
        let clamped = min(max(brightness100, 0), 100)
        RGBBrightness = clamped

        let targetBrightness = Int(clamped.rounded())
        let startBrightness = lastSentBrightnessStep ?? targetBrightness
        let step = startBrightness <= targetBrightness ? 1 : -1
        let rgb = currentRGBValues(from: selectedColor)

        for brightnessStep in stride(from: startBrightness, through: targetBrightness, by: step) {
            sendBrightnessStep(
                brightnessStep,
                red: rgb.red,
                green: rgb.green,
                blue: rgb.blue
            )
        }

        lastSentBrightnessStep = targetBrightness
    }
    private func sendMessage( message: [String]) {
            selectColorObj.sendLightControlRGB( message: message) // Convert Data back to [UInt8]
    }

    private func currentRGBValues(from color: Color) -> (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(color)
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

    private func sendBrightnessStep(_ brightnessStep: Int, red: Int, green: Int, blue: Int) {
        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(chennelPosition ?? 1),
            String(red),
            String(green),
            String(blue),
            String(brightnessStep)
        ]

        sendMessage(message: byteArray)
    }
    // Function to map slider value to a color
    func getColorFromSlider(_ value: Double) -> Color {
        let hue = value / 100.0
        return Color(hue: hue, saturation: 1, brightness: 1)
    }
    // Haptic Feed Back
    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    // MARK: - View Components
    
    private var powerToggleButton: some View {
        HStack{
            VStack(alignment: .leading, spacing: 4) {
                Text("Power")
                    .font(.system(size: 18, weight: .bold, design: .rounded)) // Bold weight
                    .foregroundColor(.appTextPrimary)
                    .kerning(0.9)        // 5% of 18px ≈ 0.9 pts
                    .lineSpacing(0)      // line-height = 100%
                    .lineLimit(1)        // prevent wrapping
                    .fixedSize()         // keeps alignment tight

                Text("Turn OFF/ON")
                    .foregroundColor(.appTextPrimary)
                    .font(.system(size: 15, weight: .regular, design: .rounded)) // Regular weight
                    .kerning(0.75)     // 5% of 15px = 0.75
                    .lineSpacing(0)    // line-height = 100%
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading) // push whole VStack to the left

            Spacer()

            HStack {
                Spacer()
                
                Button(action: {
                    isOn.toggle()
                    print("🔌 User toggled power: \(isOn)")
                    Task {
                        sendLampState()
                    }
                }) {
                    ZStack {
                        // Background circle
                        Rectangle()
                            .fill(isOn ? Color.orbGlow4 : Color.gray.opacity(0.3))
                            .frame(width: 50, height: 26)
                            .cornerRadius(100)
                        
                        // Inner dot
                        Circle()
                            .fill(Color.themeBlack)
                            .frame(width: 20, height: 20)
                            .offset(x: isOn ? 12 : -12, y: 0)
                            .animation(.easeInOut(duration: 0.2), value: isOn)
                    }
                    
                }
                .buttonStyle(PlainButtonStyle())
                
            }
        }
        .padding()
        .background(Color.appSurfacePrimary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Pattern Controls (Speed & Intensity)
    private var patternControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pattern Controls")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.appTextPrimary)

            // Speed Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                    Text("\(Int(patternSpeed))%")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }

                Slider(value: $patternSpeed, in: 0...100)
                    .accentColor(.emerald)
                    .onChange(of: patternSpeed) { _, _ in
                        if hasSelectedPattern {
                            sendCurrentPattern(patternId: selectedEffect)
                        }
                    }
            }

            // Intensity Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                    Text("\(Int(patternIntensity))%")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }

                Slider(value: $patternIntensity, in: 0...100)
                    .accentColor(.emerald)
                    .onChange(of: patternIntensity) { _, _ in
                        if hasSelectedPattern {
                            sendCurrentPattern(patternId: selectedEffect)
                        }
                    }
            }
        }
        .padding()
        .background(Color.appSurfacePrimary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sendCurrentPattern(patternId: Int) {
        guard let mac = chennalMac else { return }

        // Convert selectedColor to RGB 0-255
        let uiColor = UIColor(selectedColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let redValue = Int(r * 255)
        let greenValue = Int(g * 255)
        let blueValue = Int(b * 255)

        // Map 0-100 UI sliders to 0-255 for socket
        let speed255 = Int((patternSpeed / 100.0) * 255.0)
        let intensity255 = Int((patternIntensity / 100.0) * 255.0)

        LightControllingSocket.shared.sendPatternControl(
            deviceId: mac,
            channelPosition: chennelPosition ?? 1,
            patternId: patternId,
            red: redValue,
            green: greenValue,
            blue: blueValue,
            speed: speed255,
            intensity: intensity255
        )
    }
    
    private func sendLampState() {
        if isOn {
            let uiColor = UIColor(selectedColor)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            // Convert RGB to 0-255 range
            let redValue = Int(red * 255)
            let greenValue = Int(green * 255)
            let blueValue = Int(blue * 255)
            let brightnessValue = Int(min(max(RGBBrightness.rounded(), 0), 100))
            
            let byteArray: [String] = [
                String(chennalMac ?? ""),
                String(chennelPosition ?? 1),
                String(redValue),
                String(greenValue),
                String(blueValue),
                String(brightnessValue)
            ]
            
            sendMessage(message: byteArray)
        } else {
            // When lamp is off, send off command
            let byteArray: [String] = [
                String(chennalMac ?? ""),
                String(chennelPosition ?? 1),
                String(0),
                String(0),
                String(0),
                String(0)
            ]
            
            sendMessage(message: byteArray)
        }
    }
    
    private var rainbowColorBar: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Color")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .lineSpacing(0)
                .kerning(0)
                .lineLimit(1)
                .fixedSize()
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                
                    // Rainbow gradient background - using proper HSB color spectrum
                    LinearGradient(
                        stops: [
                            .init(color: Color(hue: 0.0, saturation: 1.0, brightness: 1.0), location: 0.0),      // Red
                            .init(color: Color(hue: 0.16, saturation: 1.0, brightness: 1.0), location: 0.16),   // Orange/Yellow
                            .init(color: Color(hue: 0.33, saturation: 1.0, brightness: 1.0), location: 0.33),   // Green
                            .init(color: Color(hue: 0.5, saturation: 1.0, brightness: 1.0), location: 0.5),     // Cyan
                            .init(color: Color(hue: 0.66, saturation: 1.0, brightness: 1.0), location: 0.66),   // Blue
                            .init(color: Color(hue: 0.83, saturation: 1.0, brightness: 1.0), location: 0.83),   // Magenta
                            .init(color: Color(hue: 1.0, saturation: 1.0, brightness: 1.0), location: 1.0)      // Red again
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 45)
                    .cornerRadius(35)
                    
                    // Slider thumb indicator - shows current selected color
                    Circle()
                        .fill(Color(hue: selectedHue, saturation: 1.0, brightness: 1.0))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.themeWhite, lineWidth: 3)
                                .shadow(radius: 2)
                        )
                        .offset(x: selectedHue * (geometry.size.width - 30))
                }
                
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let width = geometry.size.width - 30
                            let newHue = max(0, min(1, (value.location.x - 15) / width))
                            selectedHue = newHue
                            
                            print("🌈 User selected hue: \(selectedHue) (0.0 = Red, 0.33 = Green, 0.66 = Blue)")
                            
                            // Convert hue to RGB and send to WLED
                            let color = Color(hue: selectedHue, saturation: 1.0, brightness: 1.0)
                            let rgb = color.toRGB()
                            print("🎨 Converted to RGB: (\(rgb.red), \(rgb.green), \(rgb.blue))")
                            
                            Task {
                                await apiManager.setColor(red: rgb.red, green: rgb.green, blue: rgb.blue)
                            }
                        }
                )
                
            }
            .frame(height: 40)
        }
        .padding()
        .background(Color.appSurfacePrimary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var brightnessBar: some View {
        VStack( spacing: 15) {
            brightnessTitle
            brightnessSliderContainer
        }
        
        .padding()
        .background(Color.appSurfacePrimary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var brightnessTitle: some View {
        Text("Brightness")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.appTextPrimary)
            .lineSpacing(0)
            .kerning(0)
            .lineLimit(1)
            .fixedSize()
    }


    
    private var brightnessSliderContainer: some View {
        HStack(spacing: 8) {
            leftCircle
            customSlider
            rightCircle
        }
        .padding(7)
        .background(sliderBackground)
        .overlay(sliderBorder)
    }
    
    private var leftCircle: some View {
        Circle()
            .fill(Color.appSurfacePrimary)
            .frame(width: 46, height: 46)
            .overlay(
                Text("0%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeWhite)
            )
    }
    
    private var rightCircle: some View {
        Circle()
            .fill(Color.appSurfacePrimary)
            .frame(width: 46, height: 46)
            .overlay(
                Text("\(Int(100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.themeWhite)
            )
    }
    
    private var customSlider: some View {
        GeometryReader { geometry in
            ZStack {
                sliderTrack
                tickMarks
                sliderThumb(geometry: geometry)
            }
            .gesture(sliderGesture(geometry: geometry))
        }
        .frame(height: 20)
    }
    
    private var sliderTrack: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.appSliderDark, Color.appSliderMid],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 20)
    }
    
    private var tickMarks: some View {
        HStack {
            ForEach(0..<10) { index in
                Circle()
                    .fill(Color.themeWhite)
                    .frame(width: 4, height: 4)
                if index < 9 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 15)
    }
    
    private func sliderThumb(geometry: GeometryProxy) -> some View {
        Circle()
            .fill(Color.appSliderLight)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(Color.themeBlack, lineWidth: 1)
            )
            .overlay(
                Circle()
                    .fill(Color.appSliderThumb)
                    .frame(width: 8, height: 8)

                
            )
            .position(
                x: 15 + ((brightness / 255) * (geometry.size.width - 30)),
                y: 10
            )
    }
    
    private func sliderGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let padding: CGFloat = 15
                let availableWidth = geometry.size.width - (padding * 2)
                let clampedX = max(padding, min(geometry.size.width - padding, value.location.x))
                let newBrightness255 = max(0, min(255, ((clampedX - padding) / availableWidth) * 255))
                brightness = newBrightness255

                let brightness100 = (newBrightness255 / 255.0) * 100.0
                RGBBrightness = brightness100
                updateBrightness(brightness100, selectedColor: selectedColor)
            }
    }
    
    private var sliderBackground: some View {
        Color.themeBlack.opacity(0.3)
            .cornerRadius(70)
    }
    
    private var sliderBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.themeBlack.opacity(0.68), lineWidth: 2)
            .shadow(color: Color.themeBlack.opacity(0.68), radius: 4, x: 0, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: 70))
    }
    
    private var effectsScrollView: some View {
        // Static sample effects for UI only (no API dependency)
        let sampleEffects: [(id: Int, name: String)] = [
            (1,  "Solid"),                    // LED_PATTERN_SOLID
            (2,  "Pulse"),                    // LED_PATTERN_PULSE
            (3,  "Rainbow"),                  // LED_PATTERN_RAINBOW
            (4,  "Rainbow Cycle"),            // LED_PATTERN_RAINBOW_CYCLE
            (5,  "Fade"),                     // LED_PATTERN_FADE
            (6,  "Breathe"),                  // LED_PATTERN_BREATHE
            (7,  "Chase"),                    // LED_PATTERN_CHASE
            (8,  "Sparkle"),                  // LED_PATTERN_SPARKLE
            (9,  "Meteor"),                   // LED_PATTERN_METEOR
            (10, "Fire"),                     // LED_PATTERN_FIRE
            (11, "Cylon"),                    // LED_PATTERN_CYLON
            (12, "Rainbow Strobe"),           // LED_PATTERN_RAINBOW_STROBE
            (13, "Chase Rainbow"),            // LED_PATTERN_CHASE_RAINBOW
            (14, "Double Chase"),             // LED_PATTERN_DOUBLE_CHASE
            (15, "Wave"),                     // LED_PATTERN_WAVE
            (16, "Running Lights"),           // LED_PATTERN_RUNNING_LIGHTS
            (17, "Rainbow Pulse"),            // LED_PATTERN_RAINBOW_PULSE
            (18, "Gradient"),                 // LED_PATTERN_GRADIENT
            (19, "Dots"),                     // LED_PATTERN_DOTS
            (20, "Fading Blocks"),            // LED_PATTERN_FADING_BLOCKS
            (21, "Bouncing Ball"),            // LED_PATTERN_BOUNCING_BALL
            (22, "Flashing"),                 // LED_PATTERN_FLASHING
            (23, "Strobe"),                   // LED_PATTERN_STROBE
            (24, "Color Wipe"),               // LED_PATTERN_COLOR_WIPE
            (25, "Theater Chase"),            // LED_PATTERN_THEATER_CHASE
            (26, "Twinkle"),                  // LED_PATTERN_TWINKLE
            (27, "Rainbow Multi"),            // LED_PATTERN_RAINBOW_MULTI
            (28, "Alternating"),              // LED_PATTERN_ALTERNATING
            (29, "Random Flash"),             // LED_PATTERN_RANDOM_FLASH
            (30, "Breathing Rainbow"),        // LED_PATTERN_BREATHING_RAINBOW
            (31, "Segment Rainbow")           // LED_PATTERN_SEGMENT_RAINBOW (MAX)
        ]
        
        return VStack(alignment: .leading, spacing: 15) {
            Text("Effects")
                .font(.headline)
                .foregroundColor(.appTextPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(sampleEffects, id: \.id) { effect in
                        Button(action: {
                            // Update UI selection
                            selectedEffect = effect.id
                            hasSelectedPattern = true
                            // Send pattern command using device MAC, pattern id and current color/speed/intensity
                            sendCurrentPattern(patternId: effect.id)
                        }) {
                            VStack(spacing: 8) {
                                // Effect icon based on name
                                Image(systemName: effectIcon(for: effect.name))
                                    .font(.title2)
                                    .foregroundColor(selectedEffect == effect.id ? .themeWhite : .primary)
                                
                                Text(effect.name)
                                    .font(.caption)
                                    .foregroundColor(selectedEffect == effect.id ? .themeWhite : .primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                selectedEffect == effect.id ? 
                                Color.darkGray : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedEffect == effect.id ? 
                                        Color.orbGlow4 : Color.alabaster.opacity(0.6), 
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.appSurfacePrimary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // Helper function to get appropriate SF Symbol for effect names
    private func effectIcon(for effectName: String) -> String {
        let name = effectName.lowercased()
        
        if name.contains("solid") || name.contains("static") {
            return "circle.fill"
        } else if name.contains("blink") || name.contains("strobe") {
            return "bolt.fill"
        } else if name.contains("breath") || name.contains("fade") {
            return "lungs.fill"
        } else if name.contains("rainbow") {
            return "rainbow"
        } else if name.contains("chase") || name.contains("running") {
            return "arrow.right.circle.fill"
        } else if name.contains("twinkle") || name.contains("sparkle") {
            return "sparkles"
        } else if name.contains("fire") || name.contains("flame") {
            return "flame.fill"
        } else if name.contains("wave") || name.contains("ripple") {
            return "water.waves"
        } else if name.contains("meteor") || name.contains("comet") {
            return "star.fill"
        } else if name.contains("android") {
            return "smartphone"
        } else if name.contains("police") {
            return "light.beacon.max.fill"
        } else if name.contains("christmas") || name.contains("holiday") {
            return "tree.fill"
        } else {
            return "waveform"
        }
    }
}

// MARK: - Preview

struct WLEDView_Previews: PreviewProvider {
    static var previews: some View {
        WLEDView(chennalMac: "80b54ee8b228", chennelPosition: 2)
    }
}
