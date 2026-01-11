//
//  DataRGBView.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//

import SwiftUI

struct DataRGBView: View {
    @AppStorage("lampRGB") private var isOn: Bool = false
    @AppStorage("RGBBrightness") private var RGBBrightness: Double = 50
    @AppStorage("selectedColorHex") private var selectedColorHex: String = "#50C878" // Default emerald hex
    private var hexColor: Color {
        Color(hex: selectedColorHex)
    }
    @State private var selectedColor: Color = Color(hex: UserDefaults.standard.string(forKey: "selectedColorHex") ?? "#50C878")
    @State private var showingColorPicker = false
    @State private var selectedMode: ColorMode = .solid
    @State private var colorValue: Double = 0.0 // Represents position on rainbow slider
    @State private var redValue: Int = 0
    @State private var greenValue: Int = 0
     
    @State private var blueValue: Int = 0
    @State private var brightnessValue: Double = 1.0 // Brightness value ranging from 0.0 to 1.0
    @ObservedObject var sharedDevice = SharedDevice.shared
    
    @State private var wireHeight: CGFloat = 300 // Initial height of the wire image
    @State private var led2Brightness: Double = 50
    
    @State private var showPopup = false
    @State private var navigateToHome = false
    let selectColorObj = BluetoothManager.shared
    let hub: Hub
    @State private var backgroundImage: String = "name2"
    @State private var showSolidColor: Bool = true // State variable to toggle between sliders
    
    @State private var showAlert = false
    
    enum ColorMode: String, CaseIterable, Identifiable {
        case solid = "Solid"
        case rainbow = "Rainbow"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack{
//            //Background image
//            Image(backgroundImage)
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//                .blur(radius: 20) // Adjust the blur radius as needed (1-20)
//                .edgesIgnoringSafeArea(.all)
            Color(hex:"#24262B").ignoresSafeArea()
            VStack {
                
                RoundedRectangle(cornerRadius: UIScreen.main.bounds.height * 0.02 , style: .continuous)
                    .fill(Color.black)
                    .frame(height: UIScreen.main.bounds.height * 0.55) // 70% of height
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            
            VStack{
                Image("wire")
                    .resizable()
                    .frame(width: 50, height: wireHeight)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                        }
                    }
                
                ZStack {
                    
                    
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 220, height: 220)
                        .opacity(isOn ? 0.15 : 0.0) // Adjust opacity based on brightness
                        .blur(radius: 10)
                        .padding(.top, 60)
                    
                    Image("CeilingControlling")
                        .resizable()
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 234, height: 162)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                            }
                        }
                        .shadow(color:.white, radius: 4)
                    
                    
                    
                    
                    
                }
                .padding(.top, -120)
                
                

            }
            .offset(y: -UIScreen.main.bounds.height / 2 + 125) // Adjust this value to fine-tune the position
            .offset(x: 60)
                        
            VStack{
                HStack {
//                    Text("RGB LED")
//                        .font(.title)
//                        .fontWeight(.bold)
//                        .foregroundColor(.alabaster)
//                        .padding(.top)
//                    
//                        .shadow(color:.gray, radius: 6)
                    Spacer()
                    
                    Toggle(isOn: $isOn) {}
                        .shadow(color:.gray, radius: 6)
                    
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: isOn) { oldValue, newValue in
                            backgroundImage = newValue ? "name2" : "name3"  // Switch between name1 and name2
                            
                            withAnimation {
                                wireHeight = newValue ? 500 : 300 // Animate height change
                            }
                            sendLampState()
                        }
                        .onAppear {
                            withAnimation {
                                wireHeight = isOn ? 500 : 300 // Animate height change
                            }
                            sendLampState()
                        }
                }
                .padding(.horizontal)
                
                // Modified Brightness Control Section
                HStack {

                    VStack {
//                        Text("\(Int(RGBBrightness))%")
//                            .bold()
//                            .font(.title2)
//                            .foregroundColor(.alabaster)
//                            .padding(.bottom, 5)


                        VerticalSlider(value: $RGBBrightness, isEnabled: isOn) { newValue in
                            updateBrightness(newValue, selectedColor: selectedColor)
                        }
                        .frame(width: 51, height: 295)
                        Spacer() // Push the VStack to the left

                    }
                    Spacer()
                }
                .disabled(!isOn)

                Spacer()
                
                VStack {
                    HStack{
                        Spacer()
                        Text("Select Color")
                            .font(.title2)
                            .foregroundColor(.alabaster)
                            .padding(.top)
                        Spacer()
//                        Button(action: {
//                            pasteColor()
//                        }) {
//                            Text("Paste Colour")
//                                .font(.title2)
//                                .padding(8)
//                                .bold()
//                                .background(!showSolidColor ? Color.yellow : selectedColor)
//                                .foregroundColor(.white)
//                                .cornerRadius(8)
//                        }
//                        .padding(.top)
//                        .disabled(!isOn)
//                        .opacity(isOn ? 1.0 : 0.4)
                    }
                    
                    
                    
                    // Toggle buttons for Solid Color and Rainbow Color
                    HStack {
                        Button(action: {
                            showSolidColor = true
                        }) {
                            Text("Solid Color")
                                .padding(8)
                                .background(showSolidColor ? Color.emerald : Color.eton.opacity(0.4))
                                .foregroundColor(.alabaster)
                                .cornerRadius(8)
                        }
                        .disabled(!isOn)
                        .opacity(isOn ? 1.0 : 0.4)
                        
                        Button(action: {
                            showSolidColor = false
                        }) {
                            Text("Rainbow Color")
                                .padding(8)
                                .background(!showSolidColor ? Color.emerald : Color.eton.opacity(0.4))
                                .foregroundColor(.white)
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
                                sendHapticFeedback()
                                // Haptic feedback on value change
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                            .simultaneousGesture(DragGesture().onEnded { _ in
                                // Send color only when user releases the slider
                                sendColorToLED(selectedColor)
                                // Print the final selected color after slider is released
                                print("Final Selected Color: \(selectedColor)")
                            })
                            .disabled(!isOn)
                            .opacity(isOn ? 1.0 : 0.4)
                    }
                    
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                )
                .padding(.bottom, 20)
                
                
            }
//            .padding(.horizontal)
            .padding()
            
            .onChange(of: selectedColor) { oldValue, newValue in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                selectedColorHex = newValue.toHex()
            }
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(selectedColor: $selectedColor)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Device Disconnected"), message: Text("Please reconnect your device."), dismissButton: .default(Text("OK")))
            }
            .onChange(of: selectColorObj.isConnected) { oldValue, newValue in
                if !newValue {
                    showAlert = true
                }
            }
            .onChange(of: sharedDevice.connectedDevice) { oldValue, newValue in
                if newValue == nil {
                    showPopup = true // Show alert if the device is disconnected
                }
            }
            .alert("Device Disconnected", isPresented: $showPopup) {
                Button("Go to Home") {
                    navigateToHome = true
                }
            } message: {
                Text("Your device has been disconnected.")
            }
            .fullScreenCover(isPresented: $navigateToHome) {
//                HomeView()
                HotelHomeView()
            }
        }
        
//        .background(
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color.charlestonGreen, // Eton
//                    
//                    Color.alabaster  // Alabaster
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        )
        
    }
    

    
    // Function to paste color and change the button's background
    func pasteColor() {
        if let pastedText = UIPasteboard.general.string {
            if let newColor = colorFromHex(pastedText) {
                selectedColor = newColor
                print("Pasted color: \(pastedText)")
            } else {
                print("Invalid color code")
            }
        } else {
            print("Clipboard is empty")
        }
    }
    func updateBrightness(_ brightness: Double, selectedColor: Color) {
        // Normalize brightness (range 0-1)
        let normalizedBrightness = brightness / 100.0
        // Extract RGB components from the selected color
        let uiColor = UIColor(selectedColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Adjust color values based on brightness
        let adjustedRed = UInt8(min(red * normalizedBrightness * 255, 255))
        let adjustedGreen = UInt8(min(green * normalizedBrightness * 255, 255))
        let adjustedBlue = UInt8(min(blue * normalizedBrightness * 255, 255))
        
        // Create byte array with correct length and protocol format
        let byteArray: [UInt8] = [0x02, adjustedRed, adjustedGreen, adjustedBlue]
        
        // Send device info to the API
        sendMessage(hub: hub, message: byteArray)
    }

    
    
    // Function to convert hex string to Color
    func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
    
    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    // Function to map slider value to a color
    func getColorFromSlider(_ value: Double) -> Color {
        let hue = value / 100.0
        return Color(hue: hue, saturation: 1, brightness: 1)
    }
    
    func sendColorToLED(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let redByte = UInt8(red * 255)
        let greenByte = UInt8(green * 255)
        let blueByte = UInt8(blue * 255)
        
        // Create byte array with correct length and protocol format
        let byteArray: [UInt8] = [0x02, redByte, greenByte, blueByte]
        
        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
        
        sendDeviceInfo(deviceInfo: combinedString)
        sendMessage(hub: hub, message: byteArray)
    }
    
    func sendColorToLED(red: Int, green: Int, blue: Int) {
        let redByte = UInt8(red)
        let greenByte = UInt8(green)
        let blueByte = UInt8(blue)
        
        // Create byte array with correct length and protocol format
        let byteArray: [UInt8] = [0x02, redByte, greenByte, blueByte]
        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
        
        sendDeviceInfo(deviceInfo: combinedString)
        sendMessage(hub: hub, message: byteArray)
    }
    
    private func checkAndSendColor() {
        if redValue > 0 && greenValue > 0 && blueValue > 0 {
            sendColorToLED(red: redValue, green: greenValue, blue: blueValue)
        }
    }
    
    private func sendLampState() {
        if isOn {
            let byteArray: [UInt8] = [0x02, 0xFF, 0xFF, 0x00]
            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            
            // Send device info to the API
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
            
            sendDeviceInfo(deviceInfo: combinedString)
            sendMessage(hub: hub, message: byteArray)
        } else {
            let byteArray: [UInt8] = [0x02, 0x00, 0x00, 0x00]
            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            
            // Send device info to the API
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
            
            sendDeviceInfo(deviceInfo: combinedString)
            sendMessage(hub: hub, message: byteArray)
        }
    }
    
    private func sendMessage(hub: Hub, message: [UInt8]) {
        if selectColorObj.connectedDevices[hub.id] != nil {
            let data = Data(message)
            selectColorObj.sendMessageToDevice(to: hub.id, message: [UInt8](data)) // Convert Data back to [UInt8]
        } else {
            print("Device not connected")
        }
    }
    
    
    
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
struct ColorCircleSlider: View {
    @Binding var selectedColor: Color
    let colors: [Color] = [.darkRed, .orange, .yellow, .darkGreen, .darkBlue, .indigo, .purple, .pink]
    
    // Instead of @State, make it computed from the binding
    var selectedIndex: Int {
        colors.firstIndex(where: { $0.description == selectedColor.description }) ?? 0
    }
    let circleSize: CGFloat = 30
    let selectedScale: CGFloat = 1.3
    let spacing: CGFloat = 10


    var body: some View {
        HStack(spacing: spacing) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .opacity(index == selectedIndex ? 1 : 0.6)
                    )
                    .scaleEffect(index == selectedIndex ? selectedScale : 1.0)
                    .shadow(color: colors[index].opacity(0.5), radius: 4)
                    .animation(.spring(response: 0.3), value: selectedIndex)
                    .onTapGesture {
                        selectedColor = colors[index]
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
            }
        }
        .padding(.horizontal)
    }
}

struct ColorPresetButton: View {
    let color: Color
    @Binding var selectedColor: Color
    var action: () -> Void  // Explicitly require an action closure

    
    var body: some View {
        Button(action: {
            selectedColor = color
        }) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
                .overlay(
                    Circle()
                        .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                )
                .onTapGesture {
                    selectedColor = color
                    action()  // Call the action when the button is tapped
                }
        }
    }
}

struct RainbowView: View {
    @State private var animationOffset: CGFloat = 0
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple, .red]
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: -animationOffset * geometry.size.width)
            .frame(width: geometry.size.width * 2)
            .onAppear {
                withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                    animationOffset = 1
                }
            }
        }
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                ColorPicker("Select Color", selection: $selectedColor)
                    .padding()
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedColor)
                    .frame(height: 100)
                    .padding()
                    .shadow(color: selectedColor.opacity(0.3), radius: 10, x: 0, y: 0)
                
                Spacer()
            }
            .navigationTitle("Color Picker")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// Wifi connection
struct DataRGBWifiView: View {
    @AppStorage("lampRGB") private var isOn: Bool = false
    @AppStorage("RGBBrightness") private var RGBBrightness: Double = 50
    @AppStorage("selectedColorHex") private var selectedColorHex: String = "#50C878" // Default emerald hex
    private var hexColor: Color {
        Color(hex: selectedColorHex)
    }
    @State private var selectedColor: Color = Color(hex: UserDefaults.standard.string(forKey: "selectedColorHex") ?? "#50C878")
    @State private var showingColorPicker = false
    @State private var selectedMode: ColorMode = .solid
    @State private var colorValue: Double = 0.0 // Represents position on rainbow slider
    @State private var redValue: Int = 0
    @State private var greenValue: Int = 0
     
    @State private var blueValue: Int = 0
    @State private var brightnessValue: Double = 1.0 // Brightness value ranging from 0.0 to 1.0
    @ObservedObject var sharedDevice = SharedDevice.shared
    
    @State private var wireHeight: CGFloat = 300 // Initial height of the wire image
    @State private var led2Brightness: Double = 50
    
    @State private var showPopup = false
    @State private var navigateToHome = false
    let selectColorObj =  LightControllingSocket.shared
    let chennalMac: String?
    @State private var backgroundImage: String = "name2"
    @State private var showSolidColor: Bool = true // State variable to toggle between sliders
    
    @State private var showAlert = false
    
    enum ColorMode: String, CaseIterable, Identifiable {
        case solid = "Solid"
        case rainbow = "Rainbow"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack{

            Color(hex:"#24262B").ignoresSafeArea()
            VStack {
                
                RoundedRectangle(cornerRadius: UIScreen.main.bounds.height * 0.02 , style: .continuous)
                    .fill(Color.black)
                    .frame(height: UIScreen.main.bounds.height * 0.55) // 70% of height
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            
            VStack{
                Image("wire")
                    .resizable()
                    .frame(width: 50, height: wireHeight)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                        }
                    }
                
                ZStack {
                    
                    
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 220, height: 220)
                        .opacity(isOn ? 0.15 : 0.0) // Adjust opacity based on brightness
                        .blur(radius: 10)
                        .padding(.top, 60)
                    
                    Image("CeilingControlling")
                        .resizable()
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 234, height: 162)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                            }
                        }
                        .shadow(color:.white, radius: 4)
                    
                    
                    
                    
                    
                }
                .padding(.top, -120)
                
                

            }
            .offset(y: -UIScreen.main.bounds.height / 2 + 125) // Adjust this value to fine-tune the position
            .offset(x: 60)
                        
            VStack{
                HStack {

                    Spacer()
                    
                    Toggle(isOn: $isOn) {}
                        .shadow(color:.gray, radius: 6)
                    
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: isOn) { oldValue, newValue in
                            backgroundImage = newValue ? "name2" : "name3"  // Switch between name1 and name2
                            
                            withAnimation {
                                wireHeight = newValue ? 500 : 300 // Animate height change
                            }
                            sendLampState()
                        }
                        .onAppear {
                            withAnimation {
                                wireHeight = isOn ? 500 : 300 // Animate height change
                            }
                            sendLampState()
                        }
                }
                .padding(.horizontal)
                
                // Modified Brightness Control Section
                HStack {

                    VStack {



                        VerticalSlider(value: $RGBBrightness, isEnabled: isOn) { newValue in
                            updateBrightness(newValue, selectedColor: selectedColor)
                        }
                        .frame(width: 51, height: 295)
                        Spacer() // Push the VStack to the left

                    }
                    Spacer()
                }
                .disabled(!isOn)

                Spacer()
                
                VStack {
                    HStack{
                        Spacer()
                        Text("Select Color")
                            .font(.title2)
                            .foregroundColor(.alabaster)
                            .padding(.top)
                        Spacer()

                    }
                    
                    
                    
                    // Toggle buttons for Solid Color and Rainbow Color
                    HStack {
                        Button(action: {
                            showSolidColor = true
                        }) {
                            Text("Solid Color")
                                .padding(8)
                                .background(showSolidColor ? Color.emerald : Color.eton.opacity(0.4))
                                .foregroundColor(.alabaster)
                                .cornerRadius(8)
                        }
                        .disabled(!isOn)
                        .opacity(isOn ? 1.0 : 0.4)
                        
                        Button(action: {
                            showSolidColor = false
                        }) {
                            Text("Rainbow Color")
                                .padding(8)
                                .background(!showSolidColor ? Color.emerald : Color.eton.opacity(0.4))
                                .foregroundColor(.white)
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
                                sendHapticFeedback()
                                // Haptic feedback on value change
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                            .simultaneousGesture(DragGesture().onEnded { _ in
                                // Send color only when user releases the slider
                                sendColorToLED(selectedColor)
                                // Print the final selected color after slider is released
                                print("Final Selected Color: \(selectedColor)")
                            })
                            .disabled(!isOn)
                            .opacity(isOn ? 1.0 : 0.4)
                    }
                    
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                )
                .padding(.bottom, 20)
                
                
            }
            .padding()
            
            .onChange(of: selectedColor) { oldValue, newValue in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                selectedColorHex = newValue.toHex()
            }
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(selectedColor: $selectedColor)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Device Disconnected"), message: Text("Please reconnect your device."), dismissButton: .default(Text("OK")))
            }
            .alert("Device Disconnected", isPresented: $showPopup) {
                Button("Go to Home") {
                    navigateToHome = true
                }
            } message: {
                Text("Your device has been disconnected.")
            }
            .fullScreenCover(isPresented: $navigateToHome) {
                HotelHomeView()
            }
        }
        .onAppear {
            selectColorObj.connect()
        }
        

        
    }
    

    
    // Function to paste color and change the button's background
    func pasteColor() {
        if let pastedText = UIPasteboard.general.string {
            if let newColor = colorFromHex(pastedText) {
                selectedColor = newColor
                print("Pasted color: \(pastedText)")
            } else {
                print("Invalid color code")
            }
        } else {
            print("Clipboard is empty")
        }
    }
    func updateBrightness(_ brightness: Double, selectedColor: Color) {
        // Extract RGB components from the selected color
        let uiColor = UIColor(selectedColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert RGB to 0-255 range
        let redValue = Int(red * 255)
        let greenValue = Int(green * 255)
        let blueValue = Int(blue * 255)
        
        // Convert brightness to 0-100 range
        let brightnessValue = Int(brightness)
        
        // Create byte array with RGB (0-255) and brightness (0-100)
        let byteArray: [String] = [
            String(chennalMac ?? ""), 
            String(redValue), 
            String(greenValue), 
            String(blueValue),
            String(brightnessValue)
        ]
        
        // Send device info to the API
        sendMessage(message: byteArray)
    }

    
    
    // Function to convert hex string to Color
    func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
    
    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    // Function to map slider value to a color
    func getColorFromSlider(_ value: Double) -> Color {
        let hue = value / 100.0
        return Color(hue: hue, saturation: 1, brightness: 1)
    }
    
    func sendColorToLED(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert to 0-255 integer range
        let redValue = Int(red * 255)
        let greenValue = Int(green * 255)
        let blueValue = Int(blue * 255)
        
        // Convert brightness to 0-100 range
        let brightnessValue = Int(RGBBrightness)
        
        // Convert all to strings for message array
        let byteArray: [String] = [
            String(chennalMac ?? ""),
            String(redValue),
            String(greenValue),
            String(blueValue),
            String(brightnessValue)
        ]
        
        // Create readable hex string for console
        let hexString = [redValue, greenValue, blueValue]
            .map { String(format: "0x%02X", $0) }
            .joined(separator: ", ")
        
        // Prepare and send combined info
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)] | Brightness: \(brightnessValue)%"
        
        sendDeviceInfo(deviceInfo: combinedString)
        sendMessage(message: byteArray)
    }

    
    func sendColorToLED(red: Int, green: Int, blue: Int) {
        // Ensure RGB values are in 0-255 range
        let redValue = max(0, min(255, red))
        let greenValue = max(0, min(255, green))
        let blueValue = max(0, min(255, blue))
        
        // Convert brightness to 0-100 range
        let brightnessValue = Int(RGBBrightness)
        
        // Create byte array with RGB values in 0-255 range
        let byteArray: [String] = [
            String(chennalMac ?? ""), 
            String(redValue), 
            String(greenValue), 
            String(blueValue)
        ]
        
        let hexString = [redValue, greenValue, blueValue]
            .map { String(format: "0x%02X", $0) }
            .joined(separator: ", ")
        
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | RGB: [\(hexString)] | Brightness: \(brightnessValue)%"
        
        sendDeviceInfo(deviceInfo: combinedString)
        sendMessage(message: byteArray)
    }
    
    private func checkAndSendColor() {
        if redValue > 0 && greenValue > 0 && blueValue > 0 {
            sendColorToLED(red: redValue, green: greenValue, blue: blueValue)
        }
    }
    
    private func sendLampState() {
        if isOn {
            
            
            // When lamp is on, send current color with brightness
            let brightnessValue = Int(RGBBrightness) // 0-100 range
            let byteArray: [String] = [
                String(chennalMac ?? ""), 
                String(redValue), // R: 0
                String(greenValue), // G: 0
                String(blueValue),  // B: 0
                String(Int(RGBBrightness))  // B: 0
            ]
            
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Lamp ON | RGB: [0,0,0] | Brightness: \(brightnessValue)%"
            
            sendDeviceInfo(deviceInfo: combinedString)
            sendMessage(message: byteArray)
        } else {
            // When lamp is off, send off command
            let byteArray: [String] = [
                String(chennalMac ?? ""), 
                String(0), // R: 0
                String(0), // G: 0
                String(0),  // B: 0
                String(0)  // B: 0

            ]
            
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Lamp OFF | RGB: [0,0,0] | Brightness: 0%"
            
            sendDeviceInfo(deviceInfo: combinedString)
            sendMessage(message: byteArray)
        }
    }
    
    private func sendMessage( message: [String]) {
            selectColorObj.sendLightControlRGB( message: message) // Convert Data back to [UInt8]
    }
    
    
    
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


#Preview {
//    DataRGBView(hub: Hub(name: "Test Hub"))
    DataRGBWifiView( chennalMac: "80b54ee8b228")
}
