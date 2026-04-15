import SwiftUI

struct PWM2LEDView: View {
    let hub: Hub
    @AppStorage("led1WarmCold") private var led1warmCold: Double = 50
    @AppStorage("led2Brightness") private var led2Brightness: Double = 50
    @AppStorage("lampPWM") private var isOn: Bool = false
    @ObservedObject var sharedDevice = SharedDevice.shared
    @State private var isAIModeActive = false
    @State private var backgroundImage: String = "name2"
    @State private var showPopup = false
    @State private var navigateToHome = false
    @State private var wireHeight: CGFloat = 300 // Initial height of the wire image
    @ObservedObject private var storeHistory = StoreHistory() // Add this line

    var body: some View {
        ZStack{
            Color.appSurfacePrimary.ignoresSafeArea()
            VStack {
                
                RoundedRectangle(cornerRadius: UIScreen.main.bounds.height * 0.02 , style: .continuous)
                    .fill(Color.themeBlack)
                    .frame(height: UIScreen.main.bounds.height * 0.55) // 70% of height
                    .frame(maxWidth: .infinity)
                Spacer()
            }
//            .background(
//                Rectangle()
//                    .fill(Color.themeBlack)
//                    .opacity(1)
//                    .cornerRadius(22)
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//            )
             //Background image
//            Image(backgroundImage)
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//                .blur(radius: 60) // Adjust the blur radius as needed (1-20)
//                .edgesIgnoringSafeArea(.all)

//            ElegantGradientBackgroundView()
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
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow).opacity(0.3),
                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow).opacity(0.3)
                            ]),
                            startPoint: .center,
                            endPoint: .trailing
                        ))
                        .frame(width: 220, height: 145)
                        .opacity(isOn ? led2Brightness / 100 : 0)

//                        .opacity(led2Brightness/100)
                        .blur(radius: 15)
                        .padding(.top, 80)
                    
                    Image("CeilingControlling")
                        .resizable()
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 234, height: 162)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                            }
                        }
                        .shadow(color:.themeWhite, radius: 4)
//                    Ellipse()
//                        .fill(LinearGradient(
//                            gradient: Gradient(colors: [
//                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow),
//                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow).opacity(0.4)
//                            ]),
//                            startPoint: .center,
//                            endPoint: .trailing
//                        ))
//                        .frame(width: 120, height: 45)
//                        .opacity(isOn ? led2Brightness / 100 : 0)
//                        .blur(radius: 12)
//                        .padding(.top, 100)
                }
                .padding(.top, -120)
                
                

            }
            .offset(y: -UIScreen.main.bounds.height / 2 + 125) // Adjust this value to fine-tune the position
            .offset(x: 60)
            
            ZStack(alignment: .topLeading) {
                // Main content
                VStack{
                    // LED 1 Control
                    PendantLampControlView(
                        title: "Bela Lampe",
                        warmCold: $led1warmCold,
                        brightness: $led2Brightness,
                        color: .emerald,
                        hub: hub,
                        wireHeight: $wireHeight,
                        backgroundImage: $backgroundImage,
                        isOn: $isOn,
                        isAIModeActive: $isAIModeActive
                    )
                }
                .allowsHitTesting(!isAIModeActive) // Disable only the lamp controls during AI mode
                .opacity(isAIModeActive ? 1.0 : 1.0) // Fade only the lamp controls during AI mode
                
//                // AI Button positioned at top left
//                AIButtonView(
//                    hub: hub,
//                    isAIModeActive: $isAIModeActive,
//                    warmCold: $led1warmCold,
//                    brightness: $led2Brightness,
//                    isOn: $isOn
//                )
//                .disabled(!isOn) // Disable AI button when light is off
//                .padding(.top, 100) // Position under where a back button would be
//                .padding(.leading, 16)
//                .allowsHitTesting(true) // Always allow interaction with AI button
//                .opacity(1.0) // Always show at full opacity
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
            }
            message: {
                Text("Your device has been disconnected.")
            }
            .fullScreenCover(isPresented: $navigateToHome) {
//                HomeView()
                HotelHomeView()
            }
            // Removed the allowsHitTesting and opacity modifiers from here
        }

    }
}

import SwiftUI

struct PendantLampControlView: View {
    let title: String
    @Binding var warmCold: Double
    @Binding var brightness: Double
    let color: Color
    let hub: Hub
    @Binding var wireHeight: CGFloat
    @Binding var backgroundImage: String
    @Binding var isOn: Bool
    @Binding var isAIModeActive: Bool

    @State private var isEditingSliderBrightness = false
    @State private var isEditingSliderColor = false

    @ObservedObject var storeHistory = StoreHistory()

    @State private var isGlowing = false
    @StateObject private var pwmIntensityObj = BluetoothManager.shared
    @State private var showAlert = false
    @State private var showAIButton = false

    var body: some View {
        VStack {
            HStack {
//                Text(title)
//                    .font(.title)
//                    .fontWeight(.bold)
//                    .foregroundColor(.appTextPrimary)
//                    .padding(.top)
//                    .shadow(color: .gray, radius: 6)
                Spacer()
                Toggle(isOn: $isOn) {}
                    .shadow(color: .gray, radius: 6)
                    .toggleStyle(SwitchToggleStyle(tint: .emerald))
                    .onChange(of: isOn) { oldValue, newValue in
                        backgroundImage = newValue ? "name2" : "name3"
                        withAnimation {
                            wireHeight = newValue ? 500 : 300
                        }
                        sendLampState()
                    }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            // Modified Brightness Control Section
            HStack {

                VStack {
//                    Text("\(Int(brightness))%")
//                        .bold()
//                        .font(.title2)
//                        .foregroundColor(.appTextPrimary)
//                        .padding(.bottom, 5)

                    VerticalSlider(value: $brightness, isEnabled: isOn) { newValue in
                        sendIntensity()
                    }
                    .frame(width: 51, height: 295)


                }
                Spacer() // Push the VStack to the left

                
            }
            .disabled(!isOn)
            .padding(.top, 20)
            .padding(.horizontal)
            Spacer()
            VStack(spacing: 5 ) {
                Text("Color")
                    .font(.system(size: 20, weight: .semibold, design: .rounded)) // font-family + size
                    .fontWeight(.medium)                       // weight 500
                    .foregroundColor(.appTextPrimary)               // color
                    .kerning(-0.15)                            // letter-spacing
                    .lineSpacing(0)                            // no extra line spacing
                    .padding(.bottom,24)
                
                    ZStack {
                        CurvedSlider(
                            value: $warmCold,
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 133)
                    .padding(.horizontal, 10)
                    .padding(.bottom,24)


                    HStack{
                        Text("Warm")
                            .font(.system(size: 16, weight: .medium, design: .rounded)) // custom font + size
                            .fontWeight(.medium)                       // weight 500 (medium)
                            .foregroundColor(.appTextPrimary)               // custom color
                            .lineSpacing(0)                            // no extra line spacing
                            .kerning(-0.15)                            // letter-spacing

                        
                        
                        Spacer()
                        
                        Text("Cool")
                            .font(.system(size: 16, weight: .medium, design: .rounded)) // custom font + size
                            .fontWeight(.medium)                       // weight 500 (medium)
                            .foregroundColor(.appTextPrimary)               // custom color
                            .lineSpacing(0)                            // no extra line spacing
                            .kerning(-0.15)                            // letter-spacing

                        
                    }
                    .padding(.horizontal, 25)

                



            }
            .onChange(of: brightness) {
                sendHapticFeedback()
            }
            .frame(height: 243)
            .background(
                Rectangle()
                    .fill(Color.themeBlack)
                    .opacity(1)
                    .cornerRadius(22)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            )

            // AI Button
        }
        .padding(.top, 20)
//        .ignoresSafeArea()
        .cornerRadius(16)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Device Disconnected"), message: Text("Please reconnect your device."), dismissButton: .default(Text("OK")))
        }
        .onChange(of: pwmIntensityObj.isConnected) { _, newValue in
            if !newValue {
                showAlert = true
            }
        }
        .onAppear {
            withAnimation {
                wireHeight = isOn ? 500 : 300
            }
            showAIButton = storeHistory.isQueueFull
        }
        .onReceive(storeHistory.objectWillChange) {
            showAIButton = storeHistory.isQueueFull
        }
        .opacity(isAIModeActive ? 0.5 : 1.0)
        .allowsHitTesting(!isAIModeActive)
    }

    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func sendLampState() {
        DispatchQueue.main.async {
            if isOn {
                sendIntensity()
            } else {
                sendOff()
            }
        }
    }

    private func sendOn() {
        let byteArray: [UInt8] = [0x01, 0x00, 0x00, 0x00]
        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")

        sendMessage(hub: hub, message: byteArray)
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

        sendDeviceInfo(deviceInfo: combinedString)
        storeHistory.addElement(hub: hub, byteArray: byteArray)
    }

    private func sendOff() {
        let byteArray: [UInt8] = [0x01, 0x00, 0x00, 0x00]
        sendMessage(hub: hub, message: byteArray)
        
        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")

        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

        sendDeviceInfo(deviceInfo: combinedString)
        storeHistory.addElement(hub: hub, byteArray: byteArray)
    }

    private func sendColor() {
        let intensityValue = Int(warmCold)
        let intensityValue2: Int = abs(intensityValue - 100)
        let brightnessValue = Int(brightness)

        let byteArray: [UInt8] = [
            0x01,
            UInt8(intensityValue & 0xFF),
            UInt8(intensityValue2 & 0xFF),
            UInt8(brightnessValue & 0xFF)
        ]

        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        print("Sending Data: \(hexString)") // Debug output

        sendMessage(hub: hub, message: byteArray)
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

        sendDeviceInfo(deviceInfo: combinedString)
        storeHistory.addElement(hub: hub, byteArray: byteArray)
    }

    private func sendIntensity() {
        let currentBrightness = Int(brightness)
        
        let previousBrightness =  UserDefaults.standard.integer(forKey: "previousBrightness")
        
        let intensityValue = Int(warmCold)
        let intensityValue2: Int = abs(intensityValue - 100)

        // Calculate step size (divide difference into 4 parts)
        let steps = 4

        print("previousBrightness:\(previousBrightness)")
        print("currentBrightness:\(currentBrightness)")

        let difference = currentBrightness - previousBrightness
        print("defference:\(difference)")
        let stepSize = difference / steps
        print("stepSize:\(stepSize)")

        // Send values gradually with delay
        for i in 1...steps {
            let delayTime = Double(i - 1) * 0.15 // 150ms delay between steps

            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                let intermediateValue = (stepSize * i) + previousBrightness
                print("\(intermediateValue)")

                let byteArray: [UInt8] = [
                    0x01,
                    UInt8(intensityValue & 0xFF),
                    UInt8(intensityValue2 & 0xFF),
                    UInt8(intermediateValue & 0xFF)
                ]

                let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
                print("Step \(i): \(hexString)")
                
                
                self.sendMessage(hub: self.hub, message: byteArray)
                // Send device info to the API
                let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
                let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

                sendDeviceInfo(deviceInfo: combinedString)
                self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)
            }
            
        }
        
        // Send final step after all intermediate steps are done
        let finalDelay = Double(steps) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            let byteArray: [UInt8] = [
                0x01,
                UInt8(intensityValue & 0xFF),
                UInt8(intensityValue2 & 0xFF),
                UInt8(currentBrightness & 0xFF)
            ]

            print("Final current brightness: \(currentBrightness)")
            self.sendMessage(hub: self.hub, message: byteArray)

            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
            sendDeviceInfo(deviceInfo: combinedString)
            self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)
            UserDefaults.standard.set(currentBrightness, forKey: "previousBrightness")

        }

    }

    private func sendMessage(hub: Hub, message: [UInt8]) {
        if pwmIntensityObj.connectedDevices[hub.id] != nil {
            let data = Data(message)
            pwmIntensityObj.sendMessageToDevice(to: hub.id, message: [UInt8](data)) // Convert Data back to [UInt8]
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

struct PWM2LEDWifiView: View {
//    let channelCount: Int?
    let channelMac: String?

    @AppStorage("led1WarmCold") private var led1warmCold: Double = 50
    @AppStorage("led2Brightness") private var led2Brightness: Double = 50
    @AppStorage("lampPWM") private var isOn: Bool = false
    @ObservedObject var sharedDevice = SharedDevice.shared
    @State private var isAIModeActive = false
    @State private var backgroundImage: String = "name2"
    @State private var showPopup = false
    @State private var navigateToHome = false
    @State private var wireHeight: CGFloat = 300 // Initial height of the wire image
    @ObservedObject private var storeHistory = StoreHistory() // Add this line

    var body: some View {
        ZStack{
            Color.appSurfacePrimary.ignoresSafeArea()
            VStack {
                
                RoundedRectangle(cornerRadius: UIScreen.main.bounds.height * 0.02 , style: .continuous)
                    .fill(Color.themeBlack)
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
                    
                    Ellipse()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow).opacity(0.3),
                                (led1warmCold <= 50 ? Color.themeWhite : Color.appWarmGlow).opacity(0.3)
                            ]),
                            startPoint: .center,
                            endPoint: .trailing
                        ))
                        .frame(width: 220, height: 145)
                        .opacity(isOn ? led2Brightness / 100 : 0)

//                        .opacity(led2Brightness/100)
                        .blur(radius: 15)
                        .padding(.top, 80)
                    
                    Image("CeilingControlling")
                        .resizable()
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 234, height: 162)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                            }
                        }
                        .shadow(color:.themeWhite, radius: 4)

                }
                .padding(.top, -120)
                
                

            }
            .offset(y: -UIScreen.main.bounds.height / 2 + 125) // Adjust this value to fine-tune the position
            .offset(x: 60)
            
            ZStack(alignment: .topLeading) {
                // Main content

                VStack{
//                     LED 1 Control
                    PendantLampControlWifiView(

                        channelMac: String(channelMac ?? ""),
                        warmCold: $led1warmCold,
                        brightness: $led2Brightness,
                        color: .emerald,
                        wireHeight: $wireHeight,
                        backgroundImage: $backgroundImage,
                        isOn: $isOn,
                        isAIModeActive: $isAIModeActive
                    )
                    Text(String(sharedDevice.connectedDevice?.id ?? ""))

                }
                .allowsHitTesting(!isAIModeActive) // Disable only the lamp controls during AI mode
                .opacity(isAIModeActive ? 1.0 : 1.0) // Fade only the lamp controls during AI mode

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
            }
            message: {
                Text("Your device has been disconnected.")
            }
            .fullScreenCover(isPresented: $navigateToHome) {
//                HomeView()
                HotelHomeView()
            }
            // Removed the allowsHitTesting and opacity modifiers from here
        }
        .onAppear(

        )

    }
}
struct PendantLampControlWifiView: View {

    let channelMac: String?
    @Binding var warmCold: Double
    @Binding var brightness: Double
    let color: Color
    
    @Binding var wireHeight: CGFloat
    @Binding var backgroundImage: String
    @Binding var isOn: Bool
    @Binding var isAIModeActive: Bool

    @State private var isEditingSliderBrightness = false
    @State private var isEditingSliderColor = false

    @ObservedObject var storeHistory = StoreHistory()

    @State private var isGlowing = false
    @StateObject private var pwmIntensityObj = LightControllingSocket.shared

    
    @State private var showAlert = false
    @State private var showAIButton = false

    var body: some View {
        VStack {
            HStack {

                Spacer()
                Toggle(isOn: $isOn) {}
                    .shadow(color: .gray, radius: 6)
                    .toggleStyle(SwitchToggleStyle(tint: .emerald))
                    .onChange(of: isOn) { oldValue, newValue in
                        backgroundImage = newValue ? "name2" : "name3"
                        withAnimation {
                            wireHeight = newValue ? 500 : 300
                        }
                        sendLampState()
                    }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            // Modified Brightness Control Section
            HStack {

                VStack {


                    VerticalSlider(value: $brightness, isEnabled: isOn) { newValue in
                        sendIntensity()
                    }
                    .frame(width: 51, height: 295)


                }
                Spacer() // Push the VStack to the left

                
            }
            .disabled(!isOn)
            .padding(.top, 20)
            .padding(.horizontal)
            Spacer()
            VStack(spacing: 5 ) {
                Text("Color")
                    .font(.system(size: 20, weight: .semibold, design: .rounded)) // font-family + size
                    .fontWeight(.medium)                       // weight 500
                    .foregroundColor(.appTextPrimary)               // color
                    .kerning(-0.15)                            // letter-spacing
                    .lineSpacing(0)                            // no extra line spacing
                    .padding(.bottom,24)
                
                    ZStack {
                        CurvedSlider(
                            value: $warmCold,
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 133)
                    .padding(.horizontal, 10)
                    .padding(.bottom,24)


                    HStack{
                        Text("Warm")
                            .font(.system(size: 16, weight: .medium, design: .rounded)) // custom font + size
                            .fontWeight(.medium)                       // weight 500 (medium)
                            .foregroundColor(.appTextPrimary)               // custom color
                            .lineSpacing(0)                            // no extra line spacing
                            .kerning(-0.15)                            // letter-spacing

                        
                        
                        Spacer()
                        
                        Text("Cool")
                            .font(.system(size: 16, weight: .medium, design: .rounded)) // custom font + size
                            .fontWeight(.medium)                       // weight 500 (medium)
                            .foregroundColor(.appTextPrimary)               // custom color
                            .lineSpacing(0)                            // no extra line spacing
                            .kerning(-0.15)                            // letter-spacing

                        
                    }
                    .padding(.horizontal, 25)

                



            }
            .onChange(of: brightness) {
                sendHapticFeedback()
            }
            .frame(height: 243)
            .background(
                Rectangle()
                    .fill(Color.themeBlack)
                    .opacity(1)
                    .cornerRadius(22)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            )

            // AI Button
        }
        .padding(.top, 20)
//        .ignoresSafeArea()
        .cornerRadius(16)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Device Disconnected"), message: Text("Please reconnect your device."), dismissButton: .default(Text("OK")))
        }
//        .onChange(of: pwmIntensityObj.isConnected) { _, newValue in
//            if !newValue {
//                showAlert = true
//            }
//        }
        .onAppear {
            pwmIntensityObj.connect()

            withAnimation {
                wireHeight = isOn ? 500 : 300
            }
            showAIButton = storeHistory.isQueueFull
        }
        .onReceive(storeHistory.objectWillChange) {
            showAIButton = storeHistory.isQueueFull
        }
        .opacity(isAIModeActive ? 0.5 : 1.0)
        .allowsHitTesting(!isAIModeActive)
    }

    func sendHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func sendLampState() {
        DispatchQueue.main.async {
            if isOn {
                sendIntensity()
            } else {
                sendOff()
            }
        }
    }

//    private func sendOn() {
//        let byteArray: [UInt8] = [0x01, 0x00, 0x00, 0x00]
//        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
//
//        sendMessage(message: byteArray)
//        // Send device info to the API
//        let deviceInfo = channelMac
//        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
//
//        sendDeviceInfo(deviceInfo: combinedString)
////        storeHistory.addElement(hub: hub, byteArray: byteArray)
//    }

    private func sendOff() {
        let byteArray: [String] = [channelMac ?? "", "0", "0", "0"]
        pwmIntensityObj.sendLightControl(message: byteArray)
        
        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")

        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

        sendDeviceInfo(deviceInfo: combinedString)
//        storeHistory.addElement(hub: hub, byteArray: byteArray)
    }

    private func sendColor() {
        let intensityValue = Int(warmCold)
        let intensityValue2: Int = abs(intensityValue - 100)
        let brightnessValue = Int(brightness)

        let byteArray: [String] = [
            String(channelMac ?? ""),
            String(intensityValue),
            String(intensityValue2),
            String(brightnessValue)
        ]
        

        let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        print("Sending Data: \(hexString)") // Debug output

        pwmIntensityObj.sendLightControl(message: byteArray)
        // Send device info to the API
        let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
        let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"

        sendDeviceInfo(deviceInfo: combinedString)
//        storeHistory.addElement(hub: hub, byteArray: byteArray)
    }

    private func sendIntensity() {
        let currentBrightness = Int(brightness)
        
        let previousBrightness =  UserDefaults.standard.integer(forKey: "previousBrightness")
        
        let intensityValue = Int(warmCold)
        let intensityValue2: Int = abs(intensityValue - 100)

        // Calculate step size (divide difference into 4 parts)
        let steps = 4

        print("previousBrightness:\(previousBrightness)")
        print("currentBrightness:\(currentBrightness)")

        let difference = currentBrightness - previousBrightness
        print("defference:\(difference)")
        let stepSize = difference / steps
        print("stepSize:\(stepSize)")

        // Send values gradually with delay
        for i in 1...steps {
            let delayTime = Double(i - 1) * 0.15 // 150ms delay between steps

            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                let intermediateValue = (stepSize * i) + previousBrightness
                print("\(intermediateValue)")

                let byteArray: [String] = [
                    String(channelMac ?? ""),
                    String(intensityValue),
                    String(intensityValue2) ,
                    String(intermediateValue)
                ]

                let hexString = byteArray
                print("Step \(i): \(hexString)")
                
                
                pwmIntensityObj.sendLightControl(message: byteArray)
//                // Send device info to the API
//                let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
//                let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
//
//                sendDeviceInfo(deviceInfo: combinedString)
//                self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)
            }
            
        }
        
        // Send final step after all intermediate steps are done
        let finalDelay = Double(steps) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {

            let byteArray: [String] = [
                String(channelMac ?? ""),
                String(intensityValue),
                String(intensityValue2) ,
                String(currentBrightness)
            ]

            print("Final current brightness: \(currentBrightness)")
//            self.sendMessage(hub: self.hub, message: byteArray)

            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            let deviceInfo = String(describing: SharedDevice.shared.connectedDevice)
            let combinedString = "\(deviceInfo) | Hex Data: [\(hexString)]"
            sendDeviceInfo(deviceInfo: combinedString)
//            self.storeHistory.addElement(hub: self.hub, byteArray: byteArray)
            UserDefaults.standard.set(currentBrightness, forKey: "previousBrightness")

        }

    }

    private func sendMessage(message: [String] ) {
            pwmIntensityObj.connect()
            
            pwmIntensityObj.sendLightControl(message: message) // Convert Data back to [UInt8]
        
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
    PWM2LEDWifiView(channelMac: "xyz")
}
