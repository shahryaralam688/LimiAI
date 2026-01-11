import SwiftUI
import CoreBluetooth

struct BLEScanView: View {
    @StateObject private var bluetooth = BluetoothManager.shared
    @State private var discovered: [(name: String, id: String)] = []
    @State private var isNavigating = false
    @State private var isScanning = false
    @State private var statusText: String = "Preparing Bluetooth..."

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isScanning {
                    ProgressView("Scanning for BLE devices...")
                        .progressViewStyle(.circular)
                }

                List(discovered, id: \.id) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        bluetooth.stopScanning()
                        isScanning = false
                        statusText = "Connecting to \(device.name)..."
                        bluetooth.connectToDevice(deviceId: device.id)
                    }
                }
                .overlay {
                    if discovered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $isNavigating) {
                BLETestView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if bluetooth.isBluetoothOn {
                    startScan()
                } else {
                    statusText = "Waiting for Bluetooth to power on..."
                }
            }
            .onDisappear {
                bluetooth.stopScanning()
                isScanning = false
            }
            .onChange(of: bluetooth.isBluetoothOn) { _, poweredOn in
                if poweredOn {
                    startScan()
                } else {
                    statusText = "Bluetooth is off. Please enable it."
                    isScanning = false
                    discovered.removeAll()
                }
            }
            .onChange(of: bluetooth.isConnected) { _, connected in
                if connected {
                    isNavigating = true
                }
            }
        }
    }
 private func startScan() {
        guard bluetooth.isBluetoothOn else { return }
        statusText = "Scanning for BLE devices..."
        isScanning = true
        bluetooth.startScanning { devices in
            DispatchQueue.main.async {
                self.discovered = devices
                if devices.isEmpty {
                    self.statusText = "No devices found yet..."
                } else {
                    self.statusText = "Tap a device to connect"
                }
            }
        }
    }
}

#Preview {
    NavigationStack { BLEScanView() }
}

