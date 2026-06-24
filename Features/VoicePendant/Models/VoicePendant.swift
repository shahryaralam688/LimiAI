//
//  VoicePendant.swift
//  Limi
//
//  Self-contained "Voice Pendant Scan" module.
//  Domain models for pendants discovered/returned by the backend.
//
//  NOTE: This module is intentionally isolated — it does not modify any
//  existing app code. The flow is:
//    1. Fetch pendant list from backend (demo = pseudo call for now).
//    2. Connect to a pendant via the backend.
//    3. Send commands (voice package / play song) -> backend -> hardware.
//

import Foundation

// MARK: - Pendant Model

/// A voice pendant returned by the backend listing API.
struct VoicePendant: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var name: String
    /// Friendly location / space the pendant lives in (e.g. "Living Room").
    var room: String
    var status: VoicePendantStatus
    /// 0...100, optional because not every backend payload includes it.
    var batteryLevel: Int?
    /// Wi-Fi / mesh signal bars 0...4, optional.
    var signalStrength: Int?
    var firmwareVersion: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case room
        case status
        case batteryLevel = "battery_level"
        case signalStrength = "signal_strength"
        case firmwareVersion = "firmware_version"
    }
}

// MARK: - Pendant Status

enum VoicePendantStatus: String, Codable, Equatable {
    case online
    case offline
    /// Reachable on the network but not yet linked to this account/session.
    case pairing

    var displayName: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .pairing: return "Pairing"
        }
    }

    var isConnectable: Bool {
        self != .offline
    }
}

// MARK: - Commands (App -> Backend -> Hardware)

/// A command the app asks the backend to relay to a pendant's hardware.
enum VoicePendantCommand: Equatable {
    /// Stream/queue a recorded voice package to the pendant.
    case voicePackage(packageID: String)
    /// Ask the pendant to play a song/track.
    case playSong(trackID: String, title: String)
    /// Stop whatever is currently playing.
    case stop

    /// Backend action identifier.
    var action: String {
        switch self {
        case .voicePackage: return "voice_package"
        case .playSong: return "play_song"
        case .stop: return "stop"
        }
    }

    /// JSON payload relayed to the backend (which forwards to hardware).
    var payload: [String: Any] {
        switch self {
        case .voicePackage(let packageID):
            return ["package_id": packageID]
        case .playSong(let trackID, let title):
            return ["track_id": trackID, "title": title]
        case .stop:
            return [:]
        }
    }

    var displayDescription: String {
        switch self {
        case .voicePackage(let packageID): return "Voice package \(packageID)"
        case .playSong(_, let title): return "Play \"\(title)\""
        case .stop: return "Stop playback"
        }
    }
}

// MARK: - Backend DTOs

/// Wrapper matching a typical backend listing response:
/// `{ "success": true, "pendants": [ ... ] }`
struct VoicePendantListResponse: Codable {
    let success: Bool?
    let pendants: [VoicePendant]
}

/// GET `/api/devices` — voice pendant registry.
struct VoicePendantDevicesAPIResponse: Codable {
    let total: Int?
    let devices: [VoicePendantDeviceDTO]
}

struct VoicePendantDeviceDTO: Codable {
    let deviceID: String
    let name: String
    let deviceType: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case name
        case deviceType = "device_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Fills UI fields the devices API does not return yet.
enum VoicePendantPlaceholderDefaults {
    private struct Profile {
        let room: String
        let status: VoicePendantStatus
        let battery: Int?
        let signal: Int
        let firmware: String
    }

    private static let profiles: [Profile] = [
        Profile(room: "Living Room", status: .online, battery: 92, signal: 4, firmware: "1.4.2"),
        Profile(room: "Kitchen", status: .online, battery: 67, signal: 3, firmware: "1.4.2"),
        Profile(room: "Bedroom", status: .pairing, battery: 45, signal: 2, firmware: "1.3.9"),
        Profile(room: "Studio", status: .offline, battery: nil, signal: 0, firmware: "1.3.0")
    ]

    static func pendant(from dto: VoicePendantDeviceDTO, listIndex: Int) -> VoicePendant {
        let profile = profiles[listIndex % profiles.count]
        return VoicePendant(
            id: dto.deviceID,
            name: dto.name,
            room: inferredRoom(from: dto.name) ?? profile.room,
            status: profile.status,
            batteryLevel: profile.battery,
            signalStrength: profile.signal,
            firmwareVersion: profile.firmware
        )
    }

    private static func inferredRoom(from name: String) -> String? {
        let lowered = name.lowercased()
        if lowered.contains("living") { return "Living Room" }
        if lowered.contains("kitchen") { return "Kitchen" }
        if lowered.contains("bedroom") { return "Bedroom" }
        if lowered.contains("studio") { return "Studio" }
        return nil
    }
}

/// Acknowledgement returned after relaying a command to hardware.
struct VoicePendantCommandResponse: Codable {
    let success: Bool
    let message: String?
    /// Backend command/job id, useful for status polling later.
    let commandID: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case commandID = "command_id"
    }
}

// MARK: - Preview sample data (matches `/api/devices` response)

#if DEBUG
extension VoicePendant {
    /// Sample voice pendants shaped like the live API + placeholder UI fields.
    static let previewFromAPI: [VoicePendant] = {
        let dtos: [VoicePendantDeviceDTO] = [
            VoicePendantDeviceDTO(
                deviceID: "pendant-001",
                name: "Living Room Pendant",
                deviceType: "voice_pendant",
                createdAt: "2026-06-24T09:54:55.670000",
                updatedAt: "2026-06-24T09:54:55.670000"
            ),
            VoicePendantDeviceDTO(
                deviceID: "pendant-test-001",
                name: "Kitchen Pendant",
                deviceType: "voice_pendant",
                createdAt: "2026-06-24T09:31:14.257000",
                updatedAt: "2026-06-24T09:31:14.257000"
            ),
            VoicePendantDeviceDTO(
                deviceID: "pendant-debug-001",
                name: "Test Pendant",
                deviceType: "voice_pendant",
                createdAt: "2026-06-24T09:53:27.327000",
                updatedAt: "2026-06-24T09:53:27.327000"
            ),
            VoicePendantDeviceDTO(
                deviceID: "ext-test-138",
                name: "External Test",
                deviceType: "voice_pendant",
                createdAt: "2026-06-24T09:53:59.159000",
                updatedAt: "2026-06-24T09:53:59.159000"
            )
        ]
        return dtos.enumerated().map { index, dto in
            VoicePendantPlaceholderDefaults.pendant(from: dto, listIndex: index)
        }
    }()
}
#endif
