//
//  ManagerAPI.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 12/11/2025.
//
import Foundation

enum LimiAPIConfiguration {
    private static let devFallback = "https://dev.api.limitless-lighting.co.uk/"
    private static let productionFallback = "https://api.limitless-lighting.co.uk/"

    /// Resolved from `LIMI_API_BASE_URL` in Info.plist (set per build configuration in `Config/*.xcconfig`).
    static let baseURL: String = resolvedBaseURL()

    static var baseURLValue: URL {
        if let url = URL(string: baseURL) {
            return url
        }
        print("⚠️ Invalid LIMI_API_BASE_URL '\(baseURL)'; using build fallback")
        #if DEBUG
        return URL(string: devFallback)!
        #else
        return URL(string: productionFallback)!
        #endif
    }

    private static func resolvedBaseURL() -> String {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "LIMI_API_BASE_URL") as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               !trimmed.contains("$("),
               trimmed.lowercased().hasPrefix("https://") {
                return normalizeBaseURL(trimmed)
            }
        }

        #if DEBUG
        return normalizeBaseURL(devFallback)
        #else
        return normalizeBaseURL(productionFallback)
        #endif
    }

    private static func normalizeBaseURL(_ value: String) -> String {
        value.hasSuffix("/") ? value : value + "/"
    }
}

struct APIConstants {
    // MARK: - Base URL
    static let baseURL = LimiAPIConfiguration.baseURL
    static let secondaryBaseURL = LimiAPIConfiguration.baseURL

    // MARK: - Auth (see LimiAPIAuthPolicy for REST vs webhook vs Socket.IO rules)

    // Auth — login / OTP (no session required)
    static let loginGoogle = baseURL + "client/google/login"
    /// Apple Sign-In: POST JSON `{ "identity_token": "<jwt>", "user": "<apple user id>" }` → same token shape as Google login.
    static let loginApple = baseURL + "client/apple/login"
    static let LoginInstallerUser = baseURL + "client/installer_user"
    static let sendOTP = baseURL + "client/send_otp"
    static let verifyOTP = baseURL + "client/verify_otp"
    static let productionUser = baseURL + "client/verify_production"

    // AI Voice Assistant — session: Bearer; webhook: raw JWT (see LimiAPIAuthPolicy)
    static let webHook = baseURL + "limi-ai/webhook"
    static let limiAISession = baseURL + "limi-ai/session"

    // Device — Bearer JWT
    static let deviceUser = baseURL + "client/devices/device_user" // add a device configurations
    static let getLinkDevices = baseURL + "client/devices/get_link_devices"
    static let processDeviceData = baseURL +  "client/devices/process_device_data"

    // AR 3d models download
    static let download3D = baseURL + "client/3d-models/web-configurator/download/"

    // RoomScan 3D model
    static let uploadRoom3DModel = baseURL + "client/3d-models"
    //get span for download 3d model
    static let lightConfigs = secondaryBaseURL + "admin/products/light-configs/"
    static let lightConfigsCheck = secondaryBaseURL + "admin/products/users/light-configs/check"
    // User Data
    static let userData = baseURL + "client/send_user_data"
    static let editProfile = baseURL + "client/update_profile"
    static let sendUserPreference = baseURL + "sendUserPreference"
    static let roomPlanScans = baseURL + "api/scans"

    static func webConfiguratorDownload(_ downloadId: String) -> String {
        download3D + downloadId
    }

    static func lightConfig(_ spanID: String) -> String {
        lightConfigs + "\(spanID)?filter=true"
    }
}

struct AppURLs {
    enum External {
        /// Active weather provider (no API key). See `WeatherService`.
        static let openMeteoForecast = "https://api.open-meteo.com/v1/forecast"
        static let googleScopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/contacts.readonly"
        ]

        static func openAIRealtime(model: String) -> String {
            "https://api.openai.com/v1/realtime?model=\(model)"
        }

        static func whatsAppURL(phoneDigits: String, message: String) -> URL? {
            let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://wa.me/\(phoneDigits)?text=\(encoded)")
        }
    }

    enum Web {
        static let mainWebsite = "https://limiai.co/"

        static var mainWebsiteURL: URL {
            URL(string: mainWebsite) ?? URL(string: "https://limiai.co/")!
        }
        private static let configuratorV1Base = "https://limi-configurator-ios.vercel.app/configurator"
        private static let configuratorV2Base = "https://limi-configurator-ios-version-2.vercel.app/configurator"
        private static let arPortalBase = "https://limi-configurator-ios.vercel.app/ar_view"

        static func configurator(token: String? = nil) -> String {
            AppURLs.buildURL(base: configuratorV1Base, queryItems: [
                URLQueryItem(name: "token", value: token)
            ])
        }

        static func configuratorV2(token: String? = nil) -> String {
            AppURLs.buildURL(base: configuratorV2Base, queryItems: [
                URLQueryItem(name: "token", value: token)
            ])
        }

        static func arPortal(token: String) -> String {
            AppURLs.buildURL(base: arPortalBase, queryItems: [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "inApp", value: "1")
            ])
        }
    }

    enum Settings {
        static let bluetooth = "App-Prefs:root=Bluetooth"
    }

    /// Per-device LAN transport (local network, not Limi cloud API).
    enum Device {
        static let webSocketPath = "/ws"

        /// `ws://<ip>/ws` — firmware LAN door when MQTT is not active.
        static func webSocketURL(ip: String, port: Int? = nil, secure: Bool = false) -> URL? {
            URL(string: webSocketURLString(ip: ip, port: port, secure: secure))
        }

        static func webSocketURLString(ip: String, port: Int? = nil, secure: Bool = false) -> String {
            let scheme = secure ? "wss" : "ws"
            if let port {
                return "\(scheme)://\(ip):\(port)\(webSocketPath)"
            }
            return "\(scheme)://\(ip)\(webSocketPath)"
        }
    }

    /// Cloud realtime transports (same host as Limi REST unless noted).
    enum Realtime {
        /// Socket.IO server — uses `LimiAPIConfiguration.baseURL` (HTTPS origin).
        static var socketIOBaseURL: String { LimiAPIConfiguration.baseURL }

        static var socketIOURL: URL {
            URL(string: socketIOBaseURL) ?? LimiAPIConfiguration.baseURLValue
        }
    }

    enum WLED {
        static let localHost = "http://wled-01.local"

        static func deviceBase(ip: String, port: Int? = nil) -> String {
            if let port {
                return "http://\(ip):\(port)"
            }
            return "http://\(ip)"
        }

        static func deviceInfo(ip: String, port: Int? = nil) -> String {
            deviceBase(ip: ip, port: port) + "/json/info"
        }
    }

    private static func buildURL(base: String, queryItems: [URLQueryItem]) -> String {
        guard var components = URLComponents(string: base) else {
            return base
        }

        let filteredQueryItems = queryItems.filter {
            guard let value = $0.value else { return false }
            return !value.isEmpty
        }

        components.queryItems = filteredQueryItems.isEmpty ? nil : filteredQueryItems
        return components.string ?? base
    }
}
