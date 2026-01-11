//
//  MiniControllerView.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//

import SwiftUI

class LEDStateManager: ObservableObject {
    @Published var visiblePWMLEDs: Set<Int> = []
    @Published var visibleRGBLEDs: Set<Int> = []
    
    func processDeviceMessage(_ bytes: [UInt8]) {
        guard bytes.count == 2 else { return }
        
        let controlByte = bytes[1]
        updateLEDVisibility(fromByte: controlByte)
    }
    
    private func updateLEDVisibility(fromByte byte: UInt8) {
        visiblePWMLEDs.removeAll()
        visibleRGBLEDs.removeAll()
        
        // Process last 7 bits (5 PWM + 2 RGB LEDs)
        for i in 0..<7 {
            let isOn = (byte & (1 << i)) != 0
            
            if isOn {
                if i < 5 {
                    // PWM LEDs (0-4 indices map to LEDs 1-5)
                    visiblePWMLEDs.insert(i + 1)
                } else {
                    // RGB LEDs (5-6 indices map to LEDs 1-2)
                    visibleRGBLEDs.insert(i - 4)
                }
            }
        }
    }
}


struct MiniControllerView: View {
    @StateObject private var ledStateManager = LEDStateManager()

    
    // Add this property to track active PWM LED ellipses
    @State private var activePWMLEDs: Set<Int> = []
    @AppStorage("lampPWM") private var isOn: Bool = false
    @State private var mode: String = "CCT"
    @State private var wireHeight: CGFloat = 500 // Initial height of the wire image
    let hub: Hub
    @Binding var brightness: Double
    @Binding var warmCold: Double

    @State private var selectedColor: Color = .emerald // Default color
    @State private var colorValue: Double = 0.0 // Represents position on rainbow slider
    @State private var backgroundImage: String = "name3"

    @State private var selectedPWM: Int? = nil
    @State private var selectedRGB: Int? = nil
    @ObservedObject var miniPwmIntensityObj = BluetoothManager.shared  // Observing BluetoothManager

    let selectColorObj = BluetoothManager()
    
    // AppStorage properties for each LED brightness
    @AppStorage("led1Brightness") private var led1Brightness: Double = 50.0
    @AppStorage("led2Brightness") private var led2Brightness: Double = 50.0
    @AppStorage("led3Brightness") private var led3Brightness: Double = 50.0
    @AppStorage("led4Brightness") private var led4Brightness: Double = 50.0
    @AppStorage("led5Brightness") private var led5Brightness: Double = 50.0

    // Array to store brightness values for each PWM LED
    @State private var pwmBrightness: [Double] = []
    
    // Animation states
    @State private var isAppearing = false

    var body: some View {
        ZStack {
            Color(hex:"#24262B").ignoresSafeArea()
            VStack {
                
                RoundedRectangle(cornerRadius: UIScreen.main.bounds.height * 0.02 , style: .continuous)
                    .fill(Color.black)
                    .frame(height: UIScreen.main.bounds.height * 0.55) // 70% of height
                    .frame(maxWidth: .infinity)
                Spacer()
            }.ignoresSafeArea()

            
            VStack{
                Image("wire")
                    .resizable()
                    .frame(width: 50, height: wireHeight)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                        }
                    }
                
                ZStack {
                    
                    Ellipse()
                        .fill(mode == "RGB" ? (selectedRGB != nil ? selectedColor : .white) : .white)
                        .frame(width: 235, height: 135)
                        .opacity(
                            mode == "RGB"
                            ? (selectedRGB != nil ? 0.8 : 0.3)  // RGB mode opacity
                            : (selectedPWM != nil ? (pwmBrightness[selectedPWM! - 1] / 100.0) : 0.3)  // PWM mode opacity
                        )
                        .blur(radius: 15)
                        .padding(.top, 80)
                        .animation(.easeInOut(duration: 0.3), value: mode)
                        .animation(.easeInOut(duration: 0.3), value: selectedRGB)
                        .animation(.easeInOut(duration: 0.3), value: selectedColor)
                        .animation(.easeInOut(duration: 0.3), value: selectedPWM)
                        .animation(.easeInOut(duration: 0.3), value: pwmBrightness)
                    
                    Image("CeilingControlling")
                        .resizable()
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 234, height: 162)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                            }
                        }
                        .shadow(color:.white, radius: 4)
//                    
//                    Ellipse()
//                        .fill(mode == "RGB" ? (selectedRGB != nil ? selectedColor : .white) : .white)
//                        .frame(width: 120, height: 45)
//                        .opacity(
//                            mode == "RGB"
//                            ? (selectedRGB != nil ? 0.8 : 0.3)  // RGB mode opacity
//                            : (selectedPWM != nil ? (pwmBrightness[selectedPWM! - 1] / 100.0) : 0.3)  // PWM mode opacity
//                        )
//                        .blur(radius: 12)
//                        .padding(.top, 100)
//                        .animation(.easeInOut(duration: 0.3), value: mode)
//                        .animation(.easeInOut(duration: 0.3), value: selectedRGB)
//                        .animation(.easeInOut(duration: 0.3), value: selectedColor)
//                        .animation(.easeInOut(duration: 0.3), value: selectedPWM)
//                        .animation(.easeInOut(duration: 0.3), value: pwmBrightness)


                }
                .padding(.top, -60)

            }
            .offset(y: -UIScreen.main.bounds.height / 2 + 125) // Adjust this value to fine-tune the position
            VStack {

                Spacer()
                // Selected LED Controls
                if selectedPWM != nil || selectedRGB != nil {
                    GeometryReader { geometry in
                        VStack(alignment: .leading, spacing: 20) {
                            // PWM Controls
                            if mode == "CCT" && selectedPWM != nil {
                                if let pwm = selectedPWM {
                                    Spacer()

                                    HStack {
                                        Text("CCT LED \(pwm)")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(.alabaster)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(pwmBrightness[pwm - 1]))%")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.emerald)
                                    }
                                    
                                    // Brightness Slider
                                    HStack(spacing: 12) {
                                        Image(systemName: "sun.min.fill")
                                            .foregroundColor(.emerald.opacity(0.7))
                                        
                                        Slider(value: $pwmBrightness[pwm - 1], in: 0...100, step: 1, onEditingChanged: { isEditing in
                                            if isEditing {
                                                sendHapticFeedback()
                                            } else {
                                                sendHapticFeedback()
                                                sendIntensity(pwmled: pwm, brightness: pwmBrightness[pwm - 1])
                                            }
                                        })
                                        .onChange(of: pwmBrightness[pwm - 1]) { _, newValue in
                                            // Animate opacity change when brightness changes
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                // Update happens automatically through binding
                                            }
                                        }
                                        .accentColor(.emerald)
                                        
                                        Image(systemName: "sun.max.fill")
                                            .foregroundColor(.emerald)
                                    }
                                }
                            }
                            
                            // RGB Controls
                            if mode == "RGB" && selectedRGB != nil {
                                if let lednumber = selectedRGB {
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Text("RGB LED \(lednumber)")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(.charlestonGreen)
                                            
                                            Spacer()
                                            
                                            Circle()
                                                .fill(selectedColor)
                                                .frame(width: 24, height: 24)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        }
                                        
                                        // Rainbow Color Picker
                                        VStack(spacing: 8) {
                                            RainbowSlider(value: $colorValue, selectedColor: $selectedColor)
                                                .frame(height: 40)
                                                .cornerRadius(12)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2))
                                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                                .onChange(of: colorValue) { oldValue, newValue in
                                                    selectedColor = getColorFromSlider(newValue)
                                                    sendHapticFeedback()
                                                }
                                                .simultaneousGesture(DragGesture().onEnded { _ in
                                                    sendColorToLED(selectedColor, ledNumber: lednumber)
                                                })
                                            
                                            // Color presets
                                            HStack(spacing: 12) {
                                                ForEach([Color.red, Color.green, Color.blue, Color.yellow, Color.purple], id: \.self) { color in
                                                    Circle()
                                                        .fill(color)
                                                        .frame(width: 30, height: 30)
                                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                                        .onTapGesture {
                                                            selectedColor = color
                                                            sendColorToLED(color, ledNumber: lednumber)
                                                            sendHapticFeedback()
                                                        }
                                                }
                                            }
                                            .padding(.top, 8)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .offset(y: selectedPWM != nil || selectedRGB != nil ? 0 : geometry.size.height)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedPWM)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedRGB)
                    }
                    .transition(.move(edge: .bottom))
                }
                VStack(spacing: 20) {
                    // Mode Selection Buttons (CCT/RGB) - Capsule Style
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                mode = "CCT"
                            }
                        }) {
                            Text("CCT")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(mode == "CCT" ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(mode == "CCT" ? Color(hex:"#24262B") : Color.clear)
                        )
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                mode = "RGB"
                            }
                        }) {
                            Text("RGB")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(mode == "RGB" ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(mode == "RGB" ? Color(hex:"#24262B") : Color.clear)
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black)
                            .stroke(Color.black, lineWidth: 5)
                    )
                    .padding(.horizontal, 20)
                    
                    // LED Buttons in Horizontal ScrollView
                    if mode == "CCT" {
                        // PWM LED Buttons
                        VStack(alignment: .leading, spacing: 8) {
//                            HStack {
//                                Text("CCT LEDs")
//                                    .font(.system(size: 16, weight: .medium))
//                                    .foregroundColor(.alabaster)
//                                Spacer()
//                            }
//                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { index in
                                        MiniButton(
                                            title: "LED \(index)",
                                            isSelected: selectedPWM == index,
                                            color: .emerald,
                                            action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    selectedPWM = (selectedPWM == index) ? nil : index
                                                }
                                            }
                                        )
                                        .transition(.scale)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.horizontal, 20)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // RGB LED Buttons
                        VStack(alignment: .leading, spacing: 8) {
//                            HStack {
//                                Text("RGB LEDs")
//                                    .font(.system(size: 16, weight: .medium))
//                                    .foregroundColor(.alabaster)
//                                Spacer()
//                            }
//                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(1...2, id: \.self) { index in
                                        MiniButton(
                                            title: "RGB \(index)",
                                            isSelected: selectedRGB == index,
                                            color: .eton,
                                            selectedColor: selectedRGB == index ? selectedColor : nil,
                                            action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    selectedRGB = (selectedRGB == index) ? nil : index
                                                }
                                            }
                                        )
                                        .transition(.scale)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }

        }
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isAppearing = true
                }
            }
        }
        .onReceive(SharedDevice.shared.$lastReceivedBytes) { bytes in
            ledStateManager.processDeviceMessage(bytes)
        }
        
        .onAppear {
            // Load brightness values from AppStorage
            pwmBrightness = [led1Brightness, led2Brightness, led3Brightness, led4Brightness, led5Brightness]
        }
        
        // Update the brightness values in AppStorage when they change
        .onChange(of: pwmBrightness) { _, newValues in
            led1Brightness = newValues[0]
            led2Brightness = newValues[1]
            led3Brightness = newValues[2]
            led4Brightness = newValues[3]
            led5Brightness = newValues[4]
        }
    }

    // Function to send color to LED
    func sendColorToLED(_ color: Color, ledNumber: Int) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let redByte = UInt8(red * 255)
        let greenByte = UInt8(green * 255)
        let blueByte = UInt8(blue * 255)

        var byteArray: [UInt8] = [0x03, 0x00, 0x00, 0x00]

        if let po = UInt8(exactly: ledNumber + 5) {
            byteArray[1] = po
            byteArray[2] = redByte
            byteArray[3] = greenByte
            byteArray.append(blueByte)

            sendMessage(hub: hub, message: byteArray)
                
            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")

            // Send device info to the API
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

            sendDeviceInfo(deviceInfo: combinedString)
            print("Sending LED number:", ledNumber, "Color:", byteArray)
        } else {
            print("Error: LED number out of range!")
        }
    }

    // Function to map slider value to a color
    func getColorFromSlider(_ value: Double) -> Color {
        let hue = value / 100.0
        return Color(hue: hue, saturation: 1, brightness: 1)
    }

    private func sendIntensity(pwmled: Int, brightness: Double) {
        let targetBrightness = Int(brightness)
        let ledNumber = Int(pwmled)
        
        let key = "previousBrightness_LED\(ledNumber)"
        let previousBrightness = UserDefaults.standard.integer(forKey: key)

        let steps = 4
        let difference = targetBrightness - previousBrightness
        print("previousBrightness:\(previousBrightness)")
        print("currentBrightness:\(targetBrightness)")
        print("defference:\(difference)")

        let stepSize = difference / steps
        print("stepSize:\(stepSize)")
        
        for i in 1...steps {
            let delayTime = Double(i - 1) * 0.15 // 150ms delay between steps
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                let intermediateValue = previousBrightness + (stepSize * i)
                
                let byteArray: [UInt8] = [
                    0x03,
                    UInt8(ledNumber & 0xFF),
                    UInt8(intermediateValue & 0xFF)
                ]
                
                let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
                print("Step \(i) - LED \(ledNumber): \(hexString) (\(intermediateValue)%)")
                
                let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
                let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
                sendDeviceInfo(deviceInfo: combinedString)

                self.sendMessage(hub: self.hub, message: byteArray)
//                self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)
            }
        }

        let finalDelay = Double(steps) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            let byteArray: [UInt8] = [
                0x03,
                UInt8(ledNumber & 0xFF),
                UInt8(targetBrightness & 0xFF)
            ]

            self.sendMessage(hub: self.hub, message: byteArray)

            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
            sendDeviceInfo(deviceInfo: combinedString)
//            self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)

            print("Final brightness (\(targetBrightness))")
            UserDefaults.standard.set(targetBrightness, forKey: key)
            
            switch pwmled {
            case 1:
                led1Brightness = brightness
            case 2:
                led2Brightness = brightness
            case 3:
                led3Brightness = brightness
            case 4:
                led4Brightness = brightness
            case 5:
                led5Brightness = brightness
            default:
                break
            }
        }
    }

    
    private func sendMessage(hub: Hub, message: [UInt8]) {
        if miniPwmIntensityObj.connectedDevices[hub.id] != nil {
            
            let data = Data(message)
            miniPwmIntensityObj.sendMessageToDevice(to: hub.id, message: [UInt8](data)) // Convert Data back to [UInt8]

        } else {
            print("Device not connected")
        }
    }
    
    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Function to send device information to the API
    // Function to send device information to the API
    private func sendDeviceInfo(deviceInfo: String) {
        guard let url = URL(string: APIConstants.processDeviceData) else {
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

struct MiniButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    var selectedColor: Color? = nil // Add this property
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon container with rounded square background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    // LED/Light icon
                    Image(systemName: title.contains("RGB") ? "lightbulb.fill" : "lamp.desk.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? (selectedColor ?? color) : Color.white.opacity(0.7))
                }
                
                // Text label below icon
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#24262B"))
                    .shadow(color: isSelected ? (selectedColor ?? color).opacity(0.3) : Color.black.opacity(0.1),
                            radius: isSelected ? 8 : 4,
                            x: 0,
                            y: isSelected ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? (selectedColor ?? color) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

struct MiniControllerPreviewWrapper: View {
    @State private var brightness: Double = 0.5
    @State private var warmCold: Double = 0.5

    var body: some View {
        // Provide a dummy Hub instance for preview purposes
        let dummyHub = Hub(name: "Dummy Hub")
        MiniControllerView(hub: dummyHub, brightness: $brightness, warmCold: $warmCold)
    }
}

#Preview {
    MiniControllerPreviewWrapper()
}
