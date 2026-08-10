//
//  LimiDeviceApp.swift
//  LIMI AI Device
//
//  Entry point for the device-focused companion app.
//  System light/dark with LIMI Emerald accent. Devices home uses a
//  smart-home overview layout; control sheets stay native.
//

import SwiftUI
import SwiftData

@main
struct LimiDeviceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        // Companion app: BLE for control only — no random "Hub Found" popups / discovery bursts.
        BluetoothManager.shared.configureForDeviceCompanionApp()

        // Start the three-door transport stack (Bonjour + Socket.IO presence)
        // at launch, same as the main LIMI AI app.
        _ = LimiTransport.shared
        _ = DeviceTransportRegistry.shared

        do {
            modelContainer = try ModelContainer(
                for: WarmCoolSliderPreference.self,
                DeviceNamePreference.self,
                DeviceRoomAssignment.self,
                DeviceSchedule.self,
                RememberedLimiDevice.self
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }

        // Schedule engine shares the same store and fires due schedules.
        DeviceScheduleEngine.shared.configure(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            DeviceRootView()
                .environment(\.appEnvironment, .live)
                .environmentObject(LimiTransport.shared)
                .tint(DeviceTheme.accent)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            // Catch schedules that came due while the app was inactive
            // (e.g. user opened it from the schedule notification).
            if phase == .active {
                DeviceScheduleEngine.shared.checkNow()
            } else if phase == .background {
                BLECloudFallbackService.shared.cancelAllPreparing()
            }
        }
    }
}

/// The only brand color in this app. Everything else is system
/// black/white/gray so light & dark mode come from iOS directly.
enum DeviceTheme {
    /// LIMI Emerald #54BB74.
    static let accent = Color(red: 0x54 / 255.0, green: 0xBB / 255.0, blue: 0x74 / 255.0)
}
