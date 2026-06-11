//
//  ManagerAPI.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 12/11/2025.
//
import Foundation

struct APIConstants {
    // MARK: - Base URL
    static let baseURL = "https://dev.api.limitless-lighting.co.uk/"
    static let secondaryBaseURL = "https://dev.api.limitless-lighting.co.uk/"
    
    // Auth
    static let loginGoogle = baseURL + "client/google/login"
    /// Apple Sign-In: POST JSON `{ "identity_token": "<jwt>", "user": "<apple user id>" }` → same token shape as Google login.
    static let loginApple = baseURL + "client/apple/login"
    static let LoginInstallerUser = baseURL + "client/installer_user"
    static let sendOTP = baseURL + "client/send_otp"
    static let verifyOTP = baseURL + "client/verify_otp"
    static let productionUser = baseURL + "client/verify_production"
    
    // AI Voice Assistant
    static let webHook = baseURL + "limi-ai/webhook"
    
    // Device
    static let deviceUser = baseURL + "client/devices/device_user" // add a device configurations
    static let addDeviceInfo = baseURL + "admin/add_master_controller_hub_device"
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
    static let transcribeAudio = baseURL + "limi-ai/transcribe-audio"
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
        static let weatherAPI = "https://api.openweathermap.org/data/2.5/weather"
        static let googleScopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/contacts.readonly"
        ]

        static func openAIRealtime(model: String) -> String {
            "https://api.openai.com/v1/realtime?model=\(model)"
        }
    }

    enum Web {
        static let mainWebsite = "https://limiai.co/"
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
