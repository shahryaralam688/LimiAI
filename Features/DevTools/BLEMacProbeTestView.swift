//
//  BLEMacProbeTestView.swift
//  Limi
//
//  TESTING-ONLY screen for BLEMacProbeTester. Shows a live, timestamped log of
//  connect → read F001 → disconnect for every discovered LIMI hub, plus a
//  running summary (discovered / probed / failed / avg ms).
//

import SwiftUI

struct BLEMacProbeTestView: View {
    @StateObject private var tester = BLEMacProbeTester()

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Divider()
            logList
        }
        .navigationTitle("BLE MAC Probe (Test)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        tester.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(tester.isRunning)

                    Button {
                        tester.isRunning ? tester.stop() : tester.start()
                    } label: {
                        Label(tester.isRunning ? "Stop" : "Start",
                              systemImage: tester.isRunning ? "stop.fill" : "play.fill")
                    }
                    .tint(tester.isRunning ? .red : .green)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { controlBar }
        .onDisappear { tester.stop() }
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            stat("Found", "\(tester.discoveredCount)", .blue)
            stat("OK", "\(tester.probedCount)", .green)
            stat("Failed", "\(tester.failedCount)", .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(tester.logs) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(timeString(line.stamp))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(line.text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(line.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: tester.logs.count) { _, _ in
                if let last = tester.logs.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                tester.isRunning ? tester.stop() : tester.start()
            } label: {
                Label(tester.isRunning ? "Stop" : "Start",
                      systemImage: tester.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tester.isRunning ? .red : .green)

            Button {
                tester.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(tester.isRunning)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        // Lift the controls above the app's floating tab bar so Start is tappable.
        .padding(.bottom, 96)
        .background(.ultraThinMaterial)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }
}
