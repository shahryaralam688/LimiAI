//
//  VoicePendantService.swift
//  Limi
//
//  Networking layer for the Voice Pendant Scan module.
//
//  Two implementations are provided behind a single protocol:
//    • DemoVoicePendantService  — pseudo API (no network), returns canned data.
//    • LiveVoicePendantService  — real backend calls via LimiHTTPClient.
//
//  Swap the active implementation through `VoicePendantService.current`.
//  Today it defaults to the demo service so the UI works end-to-end before
//  the backend endpoints exist.
//

import Foundation

// MARK: - Service Protocol

protocol VoicePendantServicing {
    /// Fetch the list of pendants the backend knows about.
    func fetchPendants() async throws -> [VoicePendant]

    /// Ask the backend to "connect" to a pendant (link / open a session).
    func connect(to pendantID: String) async throws

    /// Relay a command to a pendant. Backend forwards it to the hardware.
    @discardableResult
    func sendCommand(_ command: VoicePendantCommand, to pendantID: String) async throws -> VoicePendantCommandResponse
}

// MARK: - Active Service Selection

enum VoicePendantService {
    /// Live list from `/api/devices`; connect/command still use demo until those APIs land.
    static var current: VoicePendantServicing = LiveVoicePendantService()
}

// MARK: - Backend Endpoints (real API)

/// Centralised endpoint strings for the module. Built on the shared base URL
/// so we don't have to touch the global `APIConstants`. Adjust the paths to
/// match the real backend contract when it lands.
enum VoicePendantEndpoints {
    /// GET — all devices; voice pendants are filtered client-side (`device_type == voice_pendant`).
    static let list = "http://69.62.125.138:8000/api/devices"

    private static var base: String { APIConstants.baseURL }

    /// POST — open/link a session to a pendant.
    static func connect(_ pendantID: String) -> String {
        base + "client/voice-pendants/\(pendantID)/connect"
    }

    /// POST — relay a command to a pendant's hardware.
    static func command(_ pendantID: String) -> String {
        base + "client/voice-pendants/\(pendantID)/command"
    }
}

// MARK: - Demo (Pseudo) Service

/// Simulates the backend with in-memory data and artificial latency.
/// Useful for building/testing the UI before the API exists.
final class DemoVoicePendantService: VoicePendantServicing {

    private var pendants: [VoicePendant] = [
        VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                     status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2"),
        VoicePendant(id: "pendant-002", name: "Kitchen Pendant", room: "Kitchen",
                     status: .online, batteryLevel: 67, signalStrength: 3, firmwareVersion: "1.4.2"),
        VoicePendant(id: "pendant-003", name: "Bedroom Pendant", room: "Bedroom",
                     status: .pairing, batteryLevel: 45, signalStrength: 2, firmwareVersion: "1.3.9"),
        VoicePendant(id: "pendant-004", name: "Studio Pendant", room: "Studio",
                     status: .offline, batteryLevel: nil, signalStrength: 0, firmwareVersion: "1.3.0")
    ]

    func fetchPendants() async throws -> [VoicePendant] {
        // Simulate network round-trip.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        return pendants
    }

    func connect(to pendantID: String) async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
        guard let index = pendants.firstIndex(where: { $0.id == pendantID }) else {
            throw LimiAPIError.backend(message: "Pendant not found.")
        }
        guard pendants[index].status.isConnectable else {
            throw LimiAPIError.backend(message: "Pendant is offline and can't be connected.")
        }
        pendants[index].status = .online
    }

    @discardableResult
    func sendCommand(_ command: VoicePendantCommand, to pendantID: String) async throws -> VoicePendantCommandResponse {
        try await Task.sleep(nanoseconds: 600_000_000)
        guard pendants.contains(where: { $0.id == pendantID }) else {
            throw LimiAPIError.backend(message: "Pendant not found.")
        }
        print("🎚️ [DemoVoicePendant] Relaying \(command.action) -> \(pendantID): \(command.payload)")
        return VoicePendantCommandResponse(
            success: true,
            message: "Queued: \(command.displayDescription)",
            commandID: UUID().uuidString
        )
    }
}

// MARK: - Live Service (real backend)

/// Real implementation using the shared authenticated HTTP client.
/// Endpoints are best-effort guesses — align with backend before going live.
final class LiveVoicePendantService: VoicePendantServicing {

    func fetchPendants() async throws -> [VoicePendant] {
        let data = try await LimiHTTPClient.get(
            urlString: VoicePendantEndpoints.list,
            auth: .none
        )
        let response = try LimiHTTPClient.decode(VoicePendantDevicesAPIResponse.self, from: data)
        let voicePendants = response.devices.filter { $0.deviceType == "voice_pendant" }
        return voicePendants.enumerated().map { index, dto in
            VoicePendantPlaceholderDefaults.pendant(from: dto, listIndex: index)
        }
    }

    func connect(to pendantID: String) async throws {
        _ = try await LimiHTTPClient.get(
            urlString: VoicePendantVoiceConfiguration.healthURL.absoluteString,
            auth: .none
        )
    }

    @discardableResult
    func sendCommand(_ command: VoicePendantCommand, to pendantID: String) async throws -> VoicePendantCommandResponse {
        var body: [String: Any] = ["action": command.action]
        body.merge(command.payload) { current, _ in current }

        let data = try await LimiHTTPClient.postJSON(
            urlString: VoicePendantEndpoints.command(pendantID),
            body: body,
            auth: .requiredBearer
        )
        return try LimiHTTPClient.decode(VoicePendantCommandResponse.self, from: data)
    }
}
