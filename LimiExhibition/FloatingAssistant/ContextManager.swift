import Foundation
import SwiftUI

extension Notification.Name {
    /// Posted when `ContextManager.updateContext` runs so the voice client can push fresh screen context on an active session.
    static let limiScreenContextDidChange = Notification.Name("limiScreenContextDidChange")
    /// Posted when `globalUserLocation` / address is saved so Home voice context can refresh.
    static let limiUserLocationDidChange = Notification.Name("limiUserLocationDidChange")
}

// MARK: - ContextManager

final class ContextManager {
    static let shared = ContextManager()

    /// Lightweight client hint sent inside `[System Context]`. Full persona + rules should live in **backend** Realtime `instructions` (`BACKEND_OPENAI_REALTIME_INSTRUCTIONS.md`) to avoid duplicate/conflicting prompts.
    static let baselineAssistantInstructions = """
    [Client] Primary persona is set in server Realtime instructions. \
    Obey the latest Screen + metadata in this message. \
    Use `ui_guide` for “where is…?”; describe labels/positions, not pixels; never invent controls. \
    Short replies unless the user asks for detail.
    """

    struct ScreenContext {
        let viewControllerName: String
        let metadata: [String: String]
        let timestamp: Date
    }

    private let lock = NSLock()
    private(set) var currentContext = ScreenContext(
        viewControllerName: "Unknown",
        metadata: [:],
        timestamp: Date()
    )

    /// Home hub: merged when tab, weather, or profile updates (avoids losing fields).
    private var homeTabIndex: String = "0"
    private var homeUserDisplayName: String = ""
    private var homeWeatherLine: String = ""
    private var homeCity: String = ""
    /// Optional: which Home modal/sheet is open (devices, configurator, ar, room_scan, modules, voice).
    private var homeSheetFlow: String = ""

    private init() {}

    func updateContext(screen: String, metadata: [String: String] = [:]) {
        lock.lock()
        if screen == "HomeView" {
            mergeHomeFields(into: metadata)
        }
        let meta = screen == "HomeView" ? mergedHomeMetadataLocked() : metadata
        currentContext = ScreenContext(
            viewControllerName: screen,
            metadata: meta,
            timestamp: Date()
        )
        lock.unlock()
        NotificationCenter.default.post(name: .limiScreenContextDidChange, object: nil)
    }

    /// Updates main shell tab index for Home (0…n) and refreshes Home context for the voice layer.
    func updateHomeTab(_ index: Int) {
        lock.lock()
        homeTabIndex = "\(index)"
        publishHomeContextLocked()
        lock.unlock()
    }

    /// Call when the weather widget loads or refreshes (from `WeatherWidgetView`).
    func updateHomeWeather(city: String, condition: String, tempC: Int, feelsLikeC: Int) {
        lock.lock()
        homeCity = city
        homeWeatherLine = "\(condition), \(tempC)°C (feels like \(feelsLikeC)°C) in \(city.isEmpty ? "current location" : city)"
        publishHomeContextLocked()
        lock.unlock()
    }

    /// Call when profile / user data loads (`UserDataManager`).
    func updateHomeUserDisplayName(_ name: String?) {
        lock.lock()
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        homeUserDisplayName = trimmed
        publishHomeContextLocked()
        lock.unlock()
    }

    private func mergeHomeFields(into metadata: [String: String]) {
        for (k, v) in metadata {
            switch k {
            case "tab": homeTabIndex = v
            case "user", "username", "display_name": homeUserDisplayName = v
            case "weather": homeWeatherLine = v
            case "city": homeCity = v
            case "sheet_flow": homeSheetFlow = v
            default: break
            }
        }
    }

    /// Plain-language map of the main Home shell (see `EnhancedBottomNavigationView`) so voice can guide users without “seeing” the UI.
    private static let homeShellUIGuide = """
    Main home shell: bottom glass bar has five tap areas left-to-right: \
    (1) Home — house icon, main feed; \
    (2) AR — cube icon, opens AR portal when the device supports LiDAR depth/mesh (otherwise a brief “no LiDAR” style message may appear); \
    (3) Center — large circular + button; tap to fan open three radial shortcuts: layers icon dismisses the menu, brain icon opens in-app voice chat, desktop icon opens AR portal (same LiDAR rule); \
    (4) Web — globe icon, opens embedded web / configurator content in a sheet; \
    (5) Profile — person icon, opens profile/settings sheet. \
    A draggable floating neural orb (when shown) toggles the global realtime AI voice session. \
    Weather sits in the main scroll area when loaded.
    """

    private func mergedHomeMetadataLocked() -> [String: String] {
        var m: [String: String] = [
            "tab": homeTabIndex,
            "surface": "main_home",
            "ui_guide": Self.homeShellUIGuide
        ]
        if !homeUserDisplayName.isEmpty {
            m["user"] = homeUserDisplayName
            m["greeting"] = "Welcome back, \(homeUserDisplayName)"
        }
        if !homeWeatherLine.isEmpty {
            m["weather"] = homeWeatherLine
        }
        if !homeCity.isEmpty {
            m["city"] = homeCity
        }
        if !homeSheetFlow.isEmpty {
            m["sheet_flow"] = homeSheetFlow
        }
        let udLoc = UserDefaults.standard.string(forKey: "globalUserLocation")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !udLoc.isEmpty {
            m["user_location"] = udLoc
        }
        let udAddr = UserDefaults.standard.string(forKey: "globalUserAddress")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !udAddr.isEmpty {
            m["user_address"] = udAddr
        }
        return m
    }

    private func publishHomeContextLocked() {
        // Only publish when the user is actually on Home; otherwise weather/profile updates
        // would overwrite context for Configurator, AR, etc.
        guard currentContext.viewControllerName == "HomeView" else { return }
        currentContext = ScreenContext(
            viewControllerName: "HomeView",
            metadata: mergedHomeMetadataLocked(),
            timestamp: Date()
        )
        NotificationCenter.default.post(name: .limiScreenContextDidChange, object: nil)
    }

    /// Builds a dictionary suitable for injecting into a `conversation.item.create` payload.
    func contextPayload() -> [String: Any] {
        lock.lock()
        let ctx = currentContext
        lock.unlock()

        var payload: [String: Any] = [
            "current_screen": ctx.viewControllerName,
            "timestamp": ISO8601DateFormatter().string(from: ctx.timestamp)
        ]
        if !ctx.metadata.isEmpty {
            payload["metadata"] = ctx.metadata
        }
        payload["baseline_instructions"] = Self.baselineAssistantInstructions
        return payload
    }

    /// Returns a human-readable summary for the AI system prompt injection.
    func contextSummary() -> String {
        lock.lock()
        let ctx = currentContext
        lock.unlock()

        var parts: [String] = ["[Limi baseline] \(Self.baselineAssistantInstructions)", "Screen: \(ctx.viewControllerName)"]
        for (key, value) in ctx.metadata.sorted(by: { $0.key < $1.key }) {
            parts.append("\(key): \(value)")
        }
        return parts.joined(separator: " | ")
    }
}

// MARK: - SwiftUI View Modifier

struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    let metadata: [String: String]

    func body(content: Content) -> some View {
        content
            .onAppear {
                ContextManager.shared.updateContext(
                    screen: screenName,
                    metadata: metadata
                )
            }
    }
}

extension View {
    func trackScreen(_ name: String, metadata: [String: String] = [:]) -> some View {
        modifier(ScreenTrackingModifier(screenName: name, metadata: metadata))
    }
}
