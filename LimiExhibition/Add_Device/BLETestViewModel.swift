import SwiftUI

struct BLETestSolidPreset: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let cool: UInt8
    let warm: UInt8
    let third: UInt8
}

protocol BLETestTransporting {
    func sendString(_ message: String)
    func sendBLEMessage(_ message: String)
}

struct DefaultBLETestTransport: BLETestTransporting {
    private let bluetoothManager: BluetoothManager

    init(bluetoothManager: BluetoothManager = .shared) {
        self.bluetoothManager = bluetoothManager
    }

    func sendString(_ message: String) {
        bluetoothManager.writeString(message)
    }

    func sendBLEMessage(_ message: String) {
        bluetoothManager.BLESend(message: message)
    }
}

final class BLETestViewModel: ObservableObject {
    @Published var slider1: Double = 0.5
    @Published var slider2: Double = 0.5

    let presets: [BLETestSolidPreset] = [
        .init(name: "Sunrise", color: .orange, cool: 148, warm: 107, third: 20),
        .init(name: "Cool", color: .blue, cool: 0, warm: 0, third: 255),
        .init(name: "Warm", color: .red, cool: 255, warm: 0, third: 0),
        .init(name: "Neutral", color: .gray, cool: 127, warm: 127, third: 20),
        .init(name: "Mint", color: .mint, cool: 170, warm: 85, third: 20),
        .init(name: "Amber", color: .yellow, cool: 90, warm: 180, third: 20),
        .init(name: "Sky", color: .cyan, cool: 180, warm: 75, third: 20)
    ]

    private let transport: BLETestTransporting

    init(transport: BLETestTransporting = DefaultBLETestTransport()) {
        self.transport = transport
    }

    func handleAppear() {
        sendValue(index: 1, value: slider1)
        sendValue(index: 2, value: slider2)
    }

    func sendPreset(_ preset: BLETestSolidPreset) {
        let message = "\(preset.cool);\(preset.warm);\(preset.third)\n"
        transport.sendBLEMessage(message)
    }

    func sendValue(index: UInt8, value: Double) {
        let cool = UInt8(max(0, min(255, Int(round(value * 255)))))
        _ = UInt8(255 &- cool)

        switch index {
        case 1:
            transport.sendString("20\n")
        case 2:
            transport.sendString("40\n")
        default:
            break
        }
    }
}
