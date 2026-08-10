//
//  LimiApp.swift
//  Limi
//
//  Created by Mac Mini on 25/02/2025.
//

import SwiftUI
import SwiftData

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    // Shared BackgroundLogic instance for the whole app
    @State private var bgLogic = BackgroundLogic()
    @State private var languageRefreshID = UUID()

    init() {
        LanguageSettings.applyRuntimeLanguage()
        BluetoothManager.shared.enableBackgroundScan()

        // Force-init the three-door transport stack so it starts listening to
        // Bonjour reachability and Socket.IO presence at app launch.
        _ = LimiTransport.shared
        _ = DeviceTransportRegistry.shared
    }

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .id(languageRefreshID)
                .environment(\.appEnvironment, .live)
                .environmentObject(LimiTransport.shared)
                .environment(bgLogic)
                .environment(\.locale, Locale(identifier: LanguageSettings.currentLanguage().rawValue == AppLanguage.system.rawValue ? Locale.current.identifier : LanguageSettings.currentLanguage().rawValue))
                .environment(\.layoutDirection, LanguageSettings.currentLanguage().isRTL ? .rightToLeft : .leftToRight)
                .preferredColorScheme(.dark)
                .cloudOfflineLocalSwitchAlert()
                .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
                    languageRefreshID = UUID()
                }
        }
        .modelContainer(for: [WarmCoolSliderPreference.self, DeviceNamePreference.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                BluetoothManager.shared.resumeBackgroundDiscoveryIfNeeded()
            } else if phase == .background {
                BLECloudFallbackService.shared.cancelAllPreparing()
                BluetoothManager.shared.pauseBackgroundDiscovery()
            }
        }
    }
}



//struct StartView: View {
//    @State private var isActive = false
//    @StateObject private var locationManager = LocationManager()
//
//    var body: some View {
//        if isActive {
//            HomeView()
//                .environmentObject(locationManager)
//                .onAppear {
//                    locationManager.requestLocationPermission()
//                }
//
//        } else {
//            VStack {
//                Text("LIMI AI")
//                Text("First Time Launch")
//            }
//        }
//    }
//}
