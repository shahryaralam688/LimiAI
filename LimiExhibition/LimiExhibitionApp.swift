//
//  LimiExhibitionApp.swift
//  LimiExhibition
//
//  Created by Mac Mini on 25/02/2025.
//

import SwiftUI
import SwiftData

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared BackgroundLogic instance for the whole app
    @State private var bgLogic = BackgroundLogic()
    @State private var languageRefreshID = UUID()

    init() {
        LanguageSettings.applyRuntimeLanguage()
        BluetoothManager.shared.enableBackgroundScan()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .id(languageRefreshID)
                .environment(bgLogic)
                .environment(\.locale, Locale(identifier: LanguageSettings.currentLanguage().rawValue == AppLanguage.system.rawValue ? Locale.current.identifier : LanguageSettings.currentLanguage().rawValue))
                .environment(\.layoutDirection, LanguageSettings.currentLanguage().isRTL ? .rightToLeft : .leftToRight)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
                    languageRefreshID = UUID()
                }
        }
        .modelContainer(for: [WarmCoolSliderPreference.self, DeviceNamePreference.self])
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
