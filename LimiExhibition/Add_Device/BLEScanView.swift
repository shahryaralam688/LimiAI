import SwiftUI
import CoreBluetooth

struct BLEScanView: View {
    @StateObject private var bluetooth = AddDeviceBluetoothAdapter()
    @StateObject private var viewModel = BLEScanViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if viewModel.isScanning {
                    ProgressView("Scanning for BLE devices...")
                        .progressViewStyle(.circular)
                }

                List(viewModel.discovered, id: \.id) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.handleDeviceSelection(
                            device,
                            stopScan: { bluetooth.stopScanning() },
                            connect: { bluetooth.connectToDevice(deviceId: $0) }
                        )
                    }
                }
                .overlay {
                    if viewModel.discovered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(viewModel.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.isNavigating) {
                BLETestView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.handleAppear(isBluetoothOn: bluetooth.isBluetoothOn) {
                    startScan()
                }
            }
            .onDisappear {
                viewModel.handleDisappear {
                    bluetooth.stopScanning()
                }
            }
            .onChange(of: bluetooth.isBluetoothOn) { _, poweredOn in
                viewModel.handleBluetoothStateChanged(poweredOn) {
                    startScan()
                }
            }
            .onChange(of: bluetooth.isConnected) { _, connected in
                viewModel.handleConnectionChanged(connected)
            }
        }
    }

    private func startScan() {
        viewModel.startScan(isBluetoothOn: bluetooth.isBluetoothOn) { completion in
            bluetooth.startScanning(completion: completion)
        }
    }
}

#Preview {
    NavigationStack { BLEScanView() }
}
