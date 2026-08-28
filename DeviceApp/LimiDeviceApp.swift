//
//  LimiDeviceApp.swift
//  LIMI AI Device
//
//  Entry point for the device-focused companion app.
//  Soft UI (Home UI 1). Heavy BLE/transport warm-up is deferred to first frame
//  so force-quit → relaunch does not race UIKit scene restore.
//

import SwiftUI
import SwiftData

@main
struct LimiDeviceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeModelContainer()
        DeviceScheduleEngine.shared.configure(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            DeviceRootView()
                .environment(\.appEnvironment, .live)
                .environmentObject(LimiTransport.shared)
                .tint(HomeUI1Color.accentGreen)
                .preferredColorScheme(.dark)
                // First paint = Soft UI canvas (not system white).
                .background(HomeUI1Color.canvas.ignoresSafeArea())
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                DeviceScheduleEngine.shared.checkNow()
            } else if phase == .background {
                BLECloudFallbackService.shared.cancelAllPreparing()
            }
        }
    }

    /// Recover from SwiftData migration failures after terminate (common crash cause).
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            WarmCoolSliderPreference.self,
            DeviceNamePreference.self,
            DeviceRoomAssignment.self,
            DeviceSchedule.self,
            RememberedLimiDevice.self,
            VirtualDeviceGroup.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Wipe incompatible store once, then retry — better than fatalError white crash.
            #if DEBUG
            print("[LimiDeviceApp] ModelContainer failed (\(error)). Resetting store…")
            #endif
            Self.deleteDefaultStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                #if DEBUG
                print("[LimiDeviceApp] ModelContainer retry failed (\(error)). Using in-memory store.")
                #endif
                let memory = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [memory])
                } catch {
                    fatalError("Failed to create model container: \(error)")
                }
            }
        }
    }

    private static func deleteDefaultStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let candidates = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]
        for name in candidates {
            let url = appSupport.appendingPathComponent(name)
            try? fm.removeItem(at: url)
        }
    }
}

/// Legacy accent used by older DeviceApp rows. Soft UI prefers `HomeUI1Color.accentGreen`.
enum DeviceTheme {
    /// LIMI Emerald #54BB74.
    static let accent = Color(red: 0x54 / 255.0, green: 0xBB / 255.0, blue: 0x74 / 255.0)
}
