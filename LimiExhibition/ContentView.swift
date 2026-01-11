import SwiftUI



struct ContentView: View {
    @State private var selectedTab = 0
    @State private var toggles: [Bool] = Array(repeating: false, count: 7)
    @StateObject private var sharedDevice = SharedDevice.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // First Tab - LED Control View
            MainLEDView(toggles: $toggles, sharedDevice: sharedDevice)
                .tabItem {
                    VStack {
                        Image(systemName: "slider.horizontal.3")
                            .environment(\.symbolVariants, .fill)
                        Text("Setting")
                    }
                }
                .tag(0)
            
            // Second Tab - Testing View
            TestingView()
                .tabItem {
                    VStack {
                        Image(systemName: "gear")
                            .environment(\.symbolVariants, .fill)
                        Text("Testing")
                    }
                }
                .tag(1)
        }
        .accentColor(.charlestonGreen)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGray6
            
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.charlestonGreen.opacity(0.6))
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.charlestonGreen)]
            
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Main LED Control View
struct MainLEDView: View {
    @Binding var toggles: [Bool]
    @ObservedObject var sharedDevice: SharedDevice
    @State private var showGetStartScreen = false // State variable to control the presentation
    // Bluetooth Manager
    @StateObject private var bluetoothManager = BluetoothManager.shared

    var byteRepresentation: String {
        let byte = createByte(from: toggles)
        return String(byte, radix: 2).leftPadding(toLength: 8, withPad: "0")
    }
    
    private func updateTogglesFromByte() {
        if sharedDevice.lastReceivedBytes.count == 2 {
            let flagsByte = sharedDevice.lastReceivedBytes[1]
            for i in 0..<7 {
                toggles[i] = (flagsByte & (1 << i)) != 0  // Ascending order (right to left)
            }
        }
    }
    
    var body: some View {
        ZStack {
            ElegantGradientBackgroundView()
            
            VStack(spacing: 20) {
                Text("Mini Controller Setting")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.alabaster)
                    .shadow(color:.alabaster, radius: 5)

                
                VStack(spacing: 16) {
                    ForEach(0..<7, id: \.self) { index in
                        LEDToggleButton(index: index, toggles: $toggles)
                    }
                }
                .padding()
                
                SendButton(toggles: toggles, byteRepresentation: byteRepresentation)
                    .padding()
                HStack {
                    Spacer() // Pushes the button to the center

                    Button(action: {
                        bluetoothManager.disconnectCurrentDevice()
                        showGetStartScreen = true // Set state variable to true
                        
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.charlestonGreen.opacity(0.1))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "arrow.left.square.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.charlestonGreen.opacity(0.8))
                            }

                            Text("Logout")
                                .font(.headline)
                                .foregroundColor(.charlestonGreen.opacity(0.8))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)


                    Spacer() // Pushes the button to the center
                }
            }
            .padding()
        }
        .onAppear {
            updateTogglesFromByte()
        }
        .onChange(of: sharedDevice.lastReceivedBytes) { oldValue, newValue in
            updateTogglesFromByte()
        }
        .fullScreenCover(isPresented: $showGetStartScreen) {
            GetStart() // Replace with your GetStart screen view
        }
    }
    
    func createByte(from toggles: [Bool]) -> UInt8 {
        guard toggles.count == 7 else {
            fatalError("Exactly 7 toggle states are required.")
        }
        var byte: UInt8 = 0
        for (index, isEnabled) in toggles.enumerated() {
            if isEnabled {
                byte |= (1 << index)  // Ascending order (right to left)
            }
        }
        return byte
    }
}

// Testing View
struct TestingView: View {
    @State private var brightness: Double = 0.5
    @State private var warmCold: Double = 0.5
    @ObservedObject private var bluetoothManager = BluetoothManager.shared

    var body: some View {
        Group {
            if let firstHub = bluetoothManager.storedHubs.first {
                MiniControllerView(
                    hub: firstHub,
                    brightness: $brightness,
                    warmCold: $warmCold
                )
            } else {
                VStack {
                    Text("No devices available")
                        .font(.headline)
                        .foregroundColor(.alabaster)
                    
                    Text("Please connect a device first")
                        .font(.subheadline)
                        .foregroundColor(.alabaster.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ElegantGradientBackgroundView())
            }
        }
    }
}

// Helper Button Views
struct LEDToggleButton: View {
    let index: Int
    @Binding var toggles: [Bool]
    
    private var buttonLabel: String {
        if index < 5 {
            return "PWM \(index + 1)"
        } else {
            return "RGB \(index - 4)"
        }
    }
    
    var body: some View {
        Button(action: {
            toggles[index].toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack {
                Text(buttonLabel)
                    .foregroundColor(.charlestonGreen)
                    .font(.headline)
                    .frame(width: 60, alignment: .leading)
                
                Toggle("", isOn: $toggles[index])
                    .labelsHidden()
                    .tint(.eton)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: toggles[index])
                    .scaleEffect(toggles[index] ? 1.1 : 1.0)
                    .overlay(
                        Circle()
                            .fill(toggles[index] ? Color.eton.opacity(0.3) : Color.clear)
                            .scaleEffect(toggles[index] ? 1.5 : 0)
                            .animation(.easeOut(duration: 0.3), value: toggles[index])
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}
struct SendButton: View {
    let toggles: [Bool]
    let byteRepresentation: String
    @State private var showingSaveMessage = false
    @State private var isInteractionDisabled = false

    var body: some View {
        ZStack {
            Button(action: {
                let firstByte: UInt8 = 91
                let secondByte = createByte(from: toggles)
                let messageBytes: [UInt8] = [firstByte, secondByte]
                
                print("Sending bytes: \(messageBytes)")
                print("Generated Byte: \(byteRepresentation)")
                
                BluetoothManager.shared.writeValue(messageBytes)
                BluetoothManager.shared.readValue()
                
                // Disable interaction and show save message
                isInteractionDisabled = true
                showingSaveMessage = true
                
                // Re-enable interaction and hide message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isInteractionDisabled = false
                    showingSaveMessage = false
                }
            }) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.alabaster)
                    .padding()
                    .frame(width: 200)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.gray, .charlestonGreen]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(15)
                    .shadow(color: .alabaster, radius: 5)
            }
            .allowsHitTesting(!isInteractionDisabled)
            
            if showingSaveMessage {
                Text("Setting Saved")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.charlestonGreen.opacity(0.8))
                    .cornerRadius(10)
                    .offset(y: -220)
                    .transition(.opacity)
                    .animation(.easeInOut, value: showingSaveMessage)
            }
        }
        .allowsHitTesting(!isInteractionDisabled)
    }
    
    private func createByte(from toggles: [Bool]) -> UInt8 {
        guard toggles.count == 7 else {
            fatalError("Exactly 7 toggle states are required.")
        }
        var byte: UInt8 = 0
        for (index, isEnabled) in toggles.enumerated() {
            if isEnabled {
                byte |= (1 << index)
            }
        }
        return byte
    }
}

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        return String(repeating: character, count: max(0, toLength - self.count)) + self
    }
}




import SwiftUI

struct PartHomeView: View {
    @ObservedObject var bluetoothManager = BluetoothManager.shared  // ✅ Use singleton

    var body: some View {
        VStack {
            Text("Connected Devices")
                .font(.headline)
            
            List(bluetoothManager.storedHubs, id: \.id) { hub in
                Button(action: {
                    
                }) {
                    Text(hub.name)
                        .foregroundColor(.blue)
                        .padding()
                }
            }
        }
    }

}

struct MyCustomView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
