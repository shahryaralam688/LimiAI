//
//  :Send.swift
//  Limi
//
//  Created by Mac Mini on 12/03/2025.
//
class HubSend: Codable {
    
    var hubName: Int = 1  // Identify Hub first
    var mode: Int         // Identify which device is used
    var pwnColour: Int    // PWM Colour which create two colour Warm and cold
    var brightness: Int   // Fixed spelling from "birthness" to "brightness"
    
    init(mode: Int, pwnColour: Int, brightness: Int) {
        self.mode = mode
        self.pwnColour = pwnColour
        self.brightness = brightness
    }
    
    func pwmDevice(pwmColour: Int, brightness: Int) {
        let hubID = hubName
        let intensityValue = pwmColour // warm Colour
        let intensityValue2: Int = abs(intensityValue - 100) // Cold colour
        let brightnessValue = brightness // Perivous Birthness
        
        print("\nHub \(hubID) PWM Device: Intensity \(intensityValue), Adjusted Intensity \(intensityValue2), Brightness \(brightnessValue)\n")
        
    }
}

class DeviceController {
    
    var hubSend: HubSend
    
    init(mode: Int, pwnColour: Int, brightness: Int) {
        self.hubSend = HubSend(mode: mode, pwnColour: pwnColour, brightness: brightness)
    }
    
    func configureDevice(newPwmColour: Int, newBrightness: Int) {
        hubSend.pwmDevice(pwmColour: newPwmColour, brightness: newBrightness)
    }
    
}


// Output:
// Hub 1 PWM Device: Intensity 70, Adjusted Intensity 30, Brightness 90

