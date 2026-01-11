//
//  WLEDView.swift
//  Limi
//
//  Created by Mac Mini on 02/10/2025.
//

import SwiftUI
import Foundation

// MARK: - WLED API Manager



// MARK: - Color Extension for RGB Conversion



// MARK: - Main WLED View

struct CCTLEDView: View {
    @StateObject private var apiManager = WLEDAPIManager()
    @State private var selectedHue: Double = 0.0

    /// Slider drives 0…255 for UI/thumblocation
    @State private var brightness: Double = 128

    @State private var selectedEffect = 0
    @State private var showingColorPicker = false

    // Rainbow Color Bar Variable
    @AppStorage("RGBBrightness") private var RGBBrightness: Double = 50 // kept for backwards-compat, not used to send
    @State private var colorValue: Double = 0.0 // Represents position on rainbow slider
    @AppStorage("selectedColorHex") private var selectedColorHex: String = "#50C878" // Default emerald hex
    @State private var selectedColor: Color = Color(hex: UserDefaults.standard.string(forKey: "selectedColorHex") ?? "#50C878")
    private var hexColor: Color { Color(hex: selectedColorHex) }

    // Global Variable
    let chennalMac: String?

    // PWM
    @AppStorage("led1WarmCold") private var led1warmCold: Double = 50
    /// This is the ONLY brightness value we send to the device (0…100)
    @AppStorage("led2Brightness") private var led2Brightness: Double = 50
    @AppStorage("lampPWM") private var isOn: Bool = false

    @State private var isEditingSliderBrightness = false
    @State private var isEditingSliderColor = false
    @State private var selectedTopTab: Int = 0 // 0 = Offline, 1 = Customize
    @State private var isOnline: Bool = true
    @State private var showToast: Bool = false

    
    let pwmIntensityObj = LightControllingSocket.shared
    @State private var showSolidColor: Bool = true // State variable to toggle between sliders

    /// Helper: percentage derived from 0…255 UI slider
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
                                       let url = URL(string: "https://limi-configurator-ios-version-2.vercel.app/configurator?token=\(token)") {
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
//                                        .foregroundColor((selectedTopTab == 1 ? Color.black : Color.white))
                                        .frame(width: 36, height: 36)
                                        .background((selectedTopTab == 1 ? Color.white : Color.gray.opacity(0.4)))
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
                    // rainbowColorBar

                    VStack {
                        HStack{
                            Text("Select Color")
                                .font(.custom("Poppins-Bold", size: 18))
                                .foregroundColor(.alabaster)
                                .kerning(0.9)
                                .lineSpacing(0)
                                .lineLimit(1)
                                .fixedSize()

                            Spacer()
                        }

                        ZStack {
                            HorizontalWarmCoolSlider(
                                value: $led1warmCold,
                                in: 0...100,
                                step: 1,
                                onEditingChanged: { isEditing in
                                    if isEditing {
                                        isEditingSliderColor = true
                                        sendHapticFeedback()
                                    } else if isEditingSliderColor {
                                        sendColor()
                                        isEditingSliderColor = false
                                    }
                                },
                                disabled: !isOn
                            )
                        }
                        .frame(height: 40)
                        .padding(.horizontal, 25)
                        .padding(.bottom,12)

                        HStack{
                            Text("Warm")
                                .font(.custom("Poppins-Medium", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.alabaster)
                                .lineSpacing(0)
                                .kerning(-0.15)

                            Spacer()

                            Text("Cool")
                                .font(.custom("Poppins-Medium", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.alabaster)
                                .lineSpacing(0)
                                .kerning(-0.15)
                        }
                        .padding(.horizontal, 25)
                        .onChange(of: brightness) { _, _ in
                            sendHapticFeedback()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#24262B"))
                    )
                    .padding(.bottom, 20)

//                    // Effects Horizontal Scroll
//                    effectsScrollView
                }
                .padding(.horizontal)

                // Bottom spacing for safe area
                Spacer(minLength: 30)
            }.padding()
        }
        .background(Color.fromHex("#111214"))
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if showToast {
                Text("Please connect to internet.")
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
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
                    self.brightness = Double(state.bri)              // 0…255 from WLED
                    self.led2Brightness = (Double(state.bri) / 255) * 100 // keep % aligned
                    self.selectedEffect = state.seg.first?.fx ?? 0
                }
            }
        }
        .onChange(of: selectedColor) { _, newValue in
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            selectedColorHex = newValue.toHex()
        }
        .onAppear {
            pwmIntensityObj.connect()
            print("connected connected")
            
        }
    }

    // MARK: - Device Senders

    private func sendColor() {
        let intensityValue = led1warmCold
        let intensityValue2: Double = abs(intensityValue - 100)
        let brightnessValue = Int((led2Brightness / 100.0) * 255.0)  // <-- use the single source of truth (0..100)

        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(Int(intensityValue)),
            String(Int(intensityValue2)),
            String(Int(brightnessValue))
        ]

        print("🔶 sendColor() -> warm=\(Int(intensityValue)) cool=\(Int(intensityValue2)) bri%=\(Int(brightnessValue))")
        pwmIntensityObj.sendLightControl(message: byteArray)
    }

    func sendColorToLED(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Convert to 0-255 integer range
        let redValue = Int(red * 255)
        let greenValue = Int(green * 255)
        let blueValue = Int(blue * 255)

        // Use led2Brightness as current brightness %
        let brightnessValue = Int((led2Brightness / 100.0) * 255.0) //Int((led2Brightness / 100.0) * 255.0)

        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(redValue),
            String(greenValue),
            String(blueValue),
            String(brightnessValue)
        ]

        print("🔷 sendColorToLED() -> RGB=(\(redValue),\(greenValue),\(blueValue)) bri%=\(brightnessValue)")
        sendMessage(message: byteArray)
    }

    /// IMPORTANT: now uses the parameter you pass (in %) and also updates AppStorage to keep it in sync.
    func updateBrightness(_ pct: Double) {
        let clamped =  pct
        led2Brightness = clamped

        let intensityValue = led1warmCold
        let intensityValue2: Double = abs(intensityValue - 100)

        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(Int(intensityValue)),
            String(Int(intensityValue2)),
            String(Int(clamped))  // send what user actually set
        ]
        print("🚚 updateBrightness() -> warm=\(Int(intensityValue)) cool=\(Int(intensityValue2)) bri%=\(Int(clamped))")
        pwmIntensityObj.sendLightControl(message: byteArray)
    }

    private func sendMessage(message: [String]) {
        pwmIntensityObj.sendLightControl(message: message)
    }

    // Function to map slider value to a color
    func getColorFromSlider(_ value: Double) -> Color {
        let hue = value / 100.0
        return Color(hue: hue, saturation: 1, brightness: 1)
    }

    // Haptic Feedback
    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - View Components

    private var powerToggleButton: some View {
        HStack{
            VStack(alignment: .leading, spacing: 4) {
                Text("Power")
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundColor(.alabaster)
                    .kerning(0.9)
                    .lineSpacing(0)
                    .lineLimit(1)
                    .fixedSize()

                Text("Turn OFF/ON")
                    .foregroundColor(.alabaster)
                    .font(.custom("Poppins-Regular", size: 15))
                    .kerning(0.75)
                    .lineSpacing(0)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                Spacer()

                Button(action: {
                    isOn.toggle()
                    print("🔌 User toggled power: \(isOn)")
                    sendLampState() // not async
                }) {
                    ZStack {
                        // Background pill
                        Rectangle()
                            .fill(isOn ? Color.white : Color.gray.opacity(0.3))
                            .frame(width: 50, height: 26)
                            .cornerRadius(100)

                        // Inner dot
                        Circle()
                            .fill(Color.black)
                            .frame(width: 20, height: 20)
                            .offset(x: isOn ? 12 : -12, y: 0)
                            .animation(.easeInOut(duration: 0.2), value: isOn)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(hex: "#24262B"), in: RoundedRectangle(cornerRadius: 16))
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

            // Use the same brightness source used by the slider (not RGBBrightness)
            let brightnessValue = Int(led2Brightness) // 0-100

            let byteArray: [String] = [
                String(chennalMac ?? ""),
                String(redValue),
                String(greenValue),
                String(brightnessValue)
            ]

            print("💡 Lamp ON -> RGB=(\(redValue),\(greenValue),\(blueValue)) bri%=\(brightnessValue)")
            sendMessage(message: byteArray)
        } else {
            // When lamp is off, send off command
            let byteArray: [String] = [
                String(chennalMac ?? ""),
                String(0),
                String(0),
                String(0),
                String(0)
            ]
            print("💤 Lamp OFF")
            sendMessage(message: byteArray)
        }
    }

    private var rainbowColorBar: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Color")
                .font(.custom("Poppins-Medium", size: 16))
                .foregroundColor(.alabaster)
                .lineSpacing(0)
                .kerning(0)
                .lineLimit(1)
                .fixedSize()

            GeometryReader { geometry in
                ZStack(alignment: .leading) {

                    // Rainbow gradient background - HSB spectrum
                    LinearGradient(
                        stops: [
                            .init(color: Color(hue: 0.0,  saturation: 1.0, brightness: 1.0), location: 0.0),   // Red
                            .init(color: Color(hue: 0.16, saturation: 1.0, brightness: 1.0), location: 0.16),  // Orange/Yellow
                            .init(color: Color(hue: 0.33, saturation: 1.0, brightness: 1.0), location: 0.33),  // Green
                            .init(color: Color(hue: 0.5,  saturation: 1.0, brightness: 1.0), location: 0.5),   // Cyan
                            .init(color: Color(hue: 0.66, saturation: 1.0, brightness: 1.0), location: 0.66),  // Blue
                            .init(color: Color(hue: 0.83, saturation: 1.0, brightness: 1.0), location: 0.83),  // Magenta
                            .init(color: Color(hue: 1.0,  saturation: 1.0, brightness: 1.0), location: 1.0)    // Red again
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
                                .stroke(Color.white, lineWidth: 3)
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

                            // Convert hue to RGB and send to WLED
                            let color = Color(hue: selectedHue, saturation: 1.0, brightness: 1.0)
                            let rgb = color.toRGB()

                            Task { await apiManager.setColor(red: rgb.red, green: rgb.green, blue: rgb.blue) }
                        }
                )
            }
            .frame(height: 40)
        }
        .padding()
        .background(Color(hex: "#24262B"), in: RoundedRectangle(cornerRadius: 16))
    }

    private var brightnessBar: some View {
        VStack( spacing: 15) {
            brightnessTitle
            brightnessSliderContainer
        }
        .padding()
        .background(Color(hex: "#24262B"), in: RoundedRectangle(cornerRadius: 16))
    }

    private var brightnessTitle: some View {
        Text("Brightness")
            .font(.custom("Poppins-Medium", size: 16))
            .foregroundColor(.alabaster)
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
            .fill(Color(hex: "#24262B"))
            .frame(width: 46, height: 46)
            .overlay(
                Text("0%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            )
    }

    private var rightCircle: some View {
        Circle()
            .fill(Color(hex: "#24262B"))
            .frame(width: 46, height: 46)
            .overlay(
                Text("\(Int(100))%")  // use computed %
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
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
                    colors: [Color.fromHex("#444444"), Color.fromHex("#999999")],
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
                    .fill(Color.white)
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
            .fill(Color.fromHex("#DDDDDD"))
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .overlay(
                Circle()
                    .fill(Color.fromHex("#202020"))
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

                // 0…255 for thumb/UI
                let newBrightness255 = max(0, min(255, ((clampedX - padding) / availableWidth) * 255))
                brightness = newBrightness255

                // 0…100 for device
                let pct = (newBrightness255 / 255.0) * 100.0
                led2Brightness = pct // keep AppStorage aligned
            }
            .onEnded { _ in
                // Send ONLY when user releases
                let pct = (brightness / 255.0) * 100.0
                updateBrightness(pct)
            }
    }

    private var sliderBackground: some View {
        Color.black.opacity(0.3)
            .cornerRadius(70)
    }

    private var sliderBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.black.opacity(0.68), lineWidth: 2)
            .shadow(color: Color.black.opacity(0.68), radius: 4, x: 0, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: 70))
    }

    private var effectsScrollView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Effects")
                .font(.headline)
                .foregroundColor(.alabaster)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(apiManager.effects) { effect in
                        Button(action: {
                            selectedEffect = effect.id
                            Task { await apiManager.setEffect(effect.id) }
                        }) {
                            VStack(spacing: 8) {
                                // Effect icon based on name
                                Image(systemName: effectIcon(for: effect.name))
                                    .font(.title2)
                                    .foregroundColor(selectedEffect == effect.id ? .white : .primary)

                                Text(effect.name)
                                    .font(.caption)
                                    .foregroundColor(selectedEffect == effect.id ? .white : .primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                selectedEffect == effect.id ? Color.blue : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedEffect == effect.id ?
                                        Color.blue : Color.alabaster.opacity(0.6),
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
        .background(Color(hex: "#24262B"), in: RoundedRectangle(cornerRadius: 16))
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

struct CCtLEDView_Previews: PreviewProvider {
    static var previews: some View {
        CCTLEDView(chennalMac: "80b54ee8b228")
    }
}

// MARK: - Horizontal Warm/Cool Slider

struct HorizontalWarmCoolSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var onEditingChanged: (Bool) -> Void
    var isDisabled: Bool

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, disabled: Bool = false) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.isDisabled = disabled
    }

    private let trackHeight: CGFloat = 14
    private let thumbSize: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let padding: CGFloat = thumbSize/2
            let usable = max(1, width - thumbSize)
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            let ratio = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
            let x = padding + CGFloat(ratio) * usable

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: trackHeight/2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.8), // warm
                                Color.white,
                                Color(red: 0.8, green: 0.9, blue: 1.0)   // cool
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackHeight)

                // Tick marks
                HStack {
                    ForEach(0..<10) { i in
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 3, height: 3)
                        if i < 9 { Spacer() }
                    }
                }

                // Thumb
                Circle()
                    .fill(Color.fromHex("#DDDDDD"))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(Color.black.opacity(0.9), lineWidth: 1))
                    .overlay(Circle().fill(Color.fromHex("#202020")).frame(width: 8, height: 8))
                    .position(x: x, y: geo.size.height/2)
                    .shadow(radius: 1)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                guard !isDisabled else { return }
                                let localX = min(max(g.location.x, padding), width - padding)
                                let newRatio = (localX - padding) / usable
                                let raw = range.lowerBound + Double(newRatio) * (range.upperBound - range.lowerBound)
                                let stepped = (raw / step).rounded() * step
                                value = min(max(stepped, range.lowerBound), range.upperBound)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
                    .allowsHitTesting(!isDisabled)
            }
        }
    }
}
