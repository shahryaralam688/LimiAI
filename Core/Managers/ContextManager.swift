import Foundation
import SwiftUI

extension Notification.Name {
    /// Posted when `ContextManager.updateContext` runs so the voice client can push fresh screen context on an active session.
    static let limiScreenContextDidChange = Notification.Name("limiScreenContextDidChange")
    /// Realtime tool `personalize_set_field` (or equivalent) — update Personalize flow fields from voice.
    static let limiPersonalizeToolUpdate = Notification.Name("limiPersonalizeToolUpdate")
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
    Short replies unless the user asks for detail. \
    WhatsApp: The app registers the Realtime tool `send_whatsapp_message` on connect (and opens WhatsApp with a draft; user taps Send). \
    You MUST call it when the user asks to send a WhatsApp—do not say you cannot send WhatsApp.
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
    /// One-shot keys merged into Home voice context (e.g. first visit welcome after Personalize). Survives `updateContext(HomeView, [:])` until cleared.
    private var homeOverlayMetadata: [String: String] = [:]

    private init() {}

    /// Keys stored in `homeOverlayMetadata` when passed into `updateContext` for `HomeView`.
    private static let homeOverlayKeys: Set<String> = [
        "first_home_after_personalize",
        "welcome_user_name",
        "welcome_use_case",
        "welcome_goals",
        "assistant_behavior"
    ]

    func updateContext(screen: String, metadata: [String: String] = [:]) {
        lock.lock()
        if screen == "HomeView" {
            mergeHomeFields(into: metadata)
            for (k, v) in metadata where Self.homeOverlayKeys.contains(k) {
                homeOverlayMetadata[k] = v
            }
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
    Main home scroll (above the bottom bar): weather card at top; below that a two-by-two module grid when the user has added modules — tiles are Device Manager, Configurator, AR View, and Room Scan (tap a tile to open that feature). \
    Do not say the center + button opens Configurator, Device Manager, or Room Scan; those are on the module grid, not the + menu.

    Bottom glass bar — five tap areas left-to-right: \
    (1) Home — house icon, returns to main feed; \
    (2) AR — cube icon, opens AR portal sheet when LiDAR is supported (otherwise a brief no-LiDAR message); \
    (3) Center + button — tap to fan open three radial shortcuts around the +: \
    left = stacked-layers icon closes the menu; \
    center-top = brain icon opens in-app voice chat; \
    right = desktop icon opens AR portal (same LiDAR rule as AR tab); \
    (4) Web — globe icon, opens embedded web/configurator sheet; \
    (5) Profile — person icon, opens profile/settings sheet. \
    A draggable floating neural orb (when shown) toggles the global realtime AI voice session.
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
        for (k, v) in homeOverlayMetadata where Self.homeOverlayKeys.contains(k) {
            m[k] = v
        }
        return m
    }

    /// Removes first-visit welcome overlay fields so later Home sessions use normal context only.
    func clearHomeWelcomeOverlay() {
        lock.lock()
        for k in Self.homeOverlayKeys {
            homeOverlayMetadata.removeValue(forKey: k)
        }
        if currentContext.viewControllerName == "HomeView" {
            currentContext = ScreenContext(
                viewControllerName: "HomeView",
                metadata: mergedHomeMetadataLocked(),
                timestamp: Date()
            )
        }
        lock.unlock()
        NotificationCenter.default.post(name: .limiScreenContextDidChange, object: nil)
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

// MARK: - First Home after Personalize (UserDefaults keys)

extension ContextManager {
    enum PendingHomeWelcome {
        static let pendingFlag = "pendingFirstHomeWelcomeAfterPersonalize"
        static let nameKey = "pendingHomeWelcomeName"
        static let useCaseKey = "pendingHomeWelcomeUseCase"
        static let goalsKey = "pendingHomeWelcomeGoals"
    }
}
