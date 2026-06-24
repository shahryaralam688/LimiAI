import SwiftUI

struct BLETestView: View {
    @StateObject private var viewModel = BLETestViewModel()
    private let grid = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 32) {
            Text("Test Controls")
                .font(.title2)
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
                    .font(.headline)
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
            viewModel.handleAppear()
        }
    }
}

#Preview {
    NavigationStack { BLETestView() }
}
