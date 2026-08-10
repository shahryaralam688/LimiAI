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
                            .font(LimiTypography.headline)
                        Text(device.id)
                            .font(LimiTypography.caption)
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
                                .font(LimiTypography.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(viewModel.statusText)
                                .font(LimiTypography.subheadline)
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

struct BLETestView: View {
    @StateObject private var viewModel = BLETestViewModel()
    private let grid = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 32) {
            Text("Test Controls")
                .font(LimiTypography.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bar 1 (Cool/Warm)")
                    Spacer()
                    Text(String(format: "%.0f", viewModel.slider1 * 100))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.slider1, in: 0...1, step: 0.01)
                    .onChange(of: viewModel.slider1) { _, newValue in
                        viewModel.sendValue(index: 1, value: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bar 2 (Cool/Warm)")
                    Spacer()
                    Text(String(format: "%.0f", viewModel.slider2 * 100))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.slider2, in: 0...1, step: 0.01)
                    .onChange(of: viewModel.slider2) { _, newValue in
                        viewModel.sendValue(index: 2, value: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Solid Colors")
                    .font(LimiTypography.headline)
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(viewModel.presets) { preset in
                        Button(action: {
                            viewModel.sendPreset(preset)
                        }) {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 36, height: 36)
                                Text(preset.name)
                                    .font(LimiTypography.caption)
                                    .foregroundColor(.appTextPrimary)
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
            viewModel.handleAppear()
        }
    }
}
