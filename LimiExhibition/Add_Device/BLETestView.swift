import SwiftUI

struct BLETestView: View {
    @State private var slider1: Double = 0.5
    @State private var slider2: Double = 0.5
    @ObservedObject private var bluetooth = BluetoothManager.shared
    private let grid = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private struct SolidPreset: Identifiable { let id = UUID(); let name: String; let color: Color; let cool: UInt8; let warm: UInt8; let third: UInt8 }
    private let presets: [SolidPreset] = [
        .init(name: "Sunrise", color: .orange, cool: 148, warm: 107, third: 20),
        .init(name: "Cool", color: .blue, cool: 0, warm: 0, third: 255),
        .init(name: "Warm", color: .red, cool: 255, warm: 0, third: 0),
        .init(name: "Neutral", color: .gray, cool: 127, warm: 127, third: 20),
        .init(name: "Mint", color: .mint, cool: 170, warm: 85, third: 20),
        .init(name: "Amber", color: .yellow, cool: 90, warm: 180, third: 20),
        .init(name: "Sky", color: .cyan, cool: 180, warm: 75, third: 20),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Text("Test Controls")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bar 1 (Cool/Warm)")
                    Spacer()
                    Text(String(format: "%.0f", slider1 * 100))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $slider1, in: 0...1, step: 0.01)
                    .onChange(of: slider1) { _, newValue in
                        sendValue(index: 1, value: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bar 2 (Cool/Warm)")
                    Spacer()
                    Text(String(format: "%.0f", slider2 * 100))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $slider2, in: 0...1, step: 0.01)
                    .onChange(of: slider2) { _, newValue in
                        sendValue(index: 2, value: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Solid Colors")
                    .font(.headline)
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(presets) { preset in
                        Button(action: {
                            let message = "\(preset.cool);\(preset.warm);\(preset.third)\n"
                            print("Solid \(preset.name) sending: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
                            bluetooth.BLESend(message: message)
                        }) {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 36, height: 36)
                                Text(preset.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Test View")
        .onAppear {
            // Send initial values on appear so device has a baseline
            sendValue(index: 1, value: slider1)
            sendValue(index: 2, value: slider2)
        }
    }

    private func sendValue(index: UInt8, value: Double) {
        // Map 0.0...1.0 -> 0...255 for cool/warm split
        let cool = UInt8(max(0, min(255, Int(round(value * 255)))))
        _ = UInt8(255 &- cool) // complementary

        switch index {
        case 1:
            // Bar 1 format: (cool,warm,20)
            let message = "20\n"
            print("Bar1 sending string: \(message)")
            bluetooth.writeString(message)
        case 2:
            // Bar 2 format: (cool,warm,20,100)
            let message = "40\n"
            print("Bar2 sending string: \(message)")
            bluetooth.writeString(message)
        default:
            break
        }
    }
}

#Preview {
    NavigationStack { BLETestView() }
}

