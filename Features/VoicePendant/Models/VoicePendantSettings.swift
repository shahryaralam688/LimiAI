//
//  VoicePendantSettings.swift
//  Limi
//
//  Models for the Voice Pendant device controls + settings screens:
//  volume, status monitoring, AI model selection and configuration.
//

import Foundation

// MARK: - Editable Settings / Configuration

/// Mutable configuration for a single pendant. Persisted via the backend.
struct VoicePendantSettings: Codable, Equatable {
    var displayName: String
    var room: String
    /// 0.0 ... 1.0
    var volume: Double
    /// 0.0 ... 1.0
    var micSensitivity: Double
    var wakeWordEnabled: Bool
    /// Selected AI model identifier (see `AIModelOption`).
    var aiModelID: String
    /// BCP-47 style language tag, e.g. "en-US".
    var language: String
    /// 0.0 ... 1.0 LED ring brightness.
    var ledBrightness: Double
    /// Hardware privacy switch — mutes the mic entirely.
    var privacyMute: Bool

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case room
        case volume
        case micSensitivity = "mic_sensitivity"
        case wakeWordEnabled = "wake_word_enabled"
        case aiModelID = "ai_model_id"
        case language
        case ledBrightness = "led_brightness"
        case privacyMute = "privacy_mute"
    }

    static let supportedLanguages: [(tag: String, label: String)] = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("ur-PK", "Urdu"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("es-ES", "Spanish")
    ]
}

// MARK: - AI Model Selection

/// An AI model the pendant can run for on-device / cloud conversations.
struct AIModelOption: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let provider: String
    let detail: String
    /// Relative latency / quality hint shown to the user.
    let tier: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case provider
        case detail
        case tier
    }
}

// MARK: - Live Status Monitoring

/// A point-in-time hardware status snapshot for the monitoring screen.
struct VoicePendantStatusSnapshot: Equatable, Codable {
    var batteryLevel: Int
    var isCharging: Bool
    var signalStrength: Int
    var temperatureC: Double
    var uptimeHours: Int
    var firmwareVersion: String
    /// Human-readable current activity, e.g. "Idle", "Listening", "Playing".
    var activity: String
    var storageUsedMB: Int
    var storageTotalMB: Int

    enum CodingKeys: String, CodingKey {
        case batteryLevel = "battery_level"
        case isCharging = "is_charging"
        case signalStrength = "signal_strength"
        case temperatureC = "temperature_c"
        case uptimeHours = "uptime_hours"
        case firmwareVersion = "firmware_version"
        case activity
        case storageUsedMB = "storage_used_mb"
        case storageTotalMB = "storage_total_mb"
    }

    var storageUsedFraction: Double {
        guard storageTotalMB > 0 else { return 0 }
        return Double(storageUsedMB) / Double(storageTotalMB)
    }
}
