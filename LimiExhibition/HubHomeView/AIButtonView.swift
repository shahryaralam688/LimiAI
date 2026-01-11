import SwiftUI

struct AIButtonView: View {
    let hub: Hub
    @Binding var isAIModeActive: Bool
    @Binding var warmCold: Double
    @Binding var brightness: Double
    @Binding var isOn: Bool
    
    @State private var timer: Timer? = nil
    @State private var showToast = false
    
    var body: some View {
        VStack {
            Button(action: {
                isAIModeActive.toggle()
                showToast = isAIModeActive
                
                if isAIModeActive {
                    // Make sure the light is on when AI mode starts
                    if !isOn {
                        isOn = true
                    }
                    startAIMode()
                } else {
                    stopAIMode()
                }
            }) {
                HStack {
                    Image(systemName: isAIModeActive ? "stop.circle.fill" : "waveform.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isAIModeActive ? .red : .white)
                    
                    Text(isAIModeActive ? "Stop AI" : "Limi")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isAIModeActive ? Color.red.opacity(0.3) : Color.black.opacity(0.5))
                        .shadow(color: isAIModeActive ? .red.opacity(0.6) : .black.opacity(0.3), radius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isAIModeActive ? Color.red : Color.white.opacity(0.5), lineWidth: 1)
                )
                .opacity(isOn ? 1.0 : 0.5) // Show as faded when disabled
            }
            .padding(.top, 8)
            
            if showToast {
                Text("AI adjusting environment...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
    }
    
    private func startAIMode() {
        // Create a timer that fires every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Generate random values for warmCold and brightness with animation
            withAnimation(.easeInOut(duration: 1.0)) {
                self.warmCold = Double.random(in: 0...100)
                self.brightness = Double.random(in: 30...100) // Keeping minimum brightness at 30%
            }
            
            // Send the random values to the device
            sendRandomLightSettings(warmCold: warmCold, brightness: brightness)
        }
    }
    
    private func stopAIMode() {
        // Invalidate and clear the timer
        timer?.invalidate()
        timer = nil
    }
    
    private func sendRandomLightSettings(warmCold: Double, brightness: Double) {
        let intensityValue = Int(warmCold)
        let intensityValue2: Int = abs(intensityValue - 100)
        let brightnessValue = Int(brightness)
        
        let byteArray: [UInt8] = [
            0x01,
            UInt8(intensityValue & 0xFF),
            UInt8(intensityValue2 & 0xFF),
            UInt8(brightnessValue & 0xFF)
        ]
        
        // Send the command to the device
        if let connectedDevice = BluetoothManager.shared.connectedDevices[hub.id] {
            BluetoothManager.shared.sendMessageToDevice(to: hub.id, message: byteArray)
            
            // Log the command (optional)
            let hexString = byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            print("AI Mode - Sending: \(hexString)")
            
            // Store in history
            StoreHistory().addElement(hub: hub, byteArray: byteArray)
        }
    }
}

