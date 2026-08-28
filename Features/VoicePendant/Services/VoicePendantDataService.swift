//
//  VoicePendantDataService.swift
//  Limi
//
//  Data access for the enhanced Voice Pendant screens (settings, status,
//  AI models, conversation memory and audio sharing).
//
//  Kept separate from `VoicePendantServicing` (scan/connect/command) so the
//  existing listing flow carries zero regression risk. Same pattern:
//    • DemoVoicePendantDataService — pseudo API, canned data + latency.
//    • LiveVoicePendantDataService — real backend via LimiHTTPClient.
//

import Foundation

// MARK: - Protocol

protocol VoicePendantDataServicing {
    // Settings / configuration
    func fetchSettings(for pendantID: String) async throws -> VoicePendantSettings
    func updateSettings(_ settings: VoicePendantSettings, for pendantID: String) async throws

    // Controls / monitoring
    func fetchStatus(for pendantID: String) async throws -> VoicePendantStatusSnapshot
    func fetchAIModels() async throws -> [AIModelOption]

    // Summary & memory
    func fetchConversations(for pendantID: String) async throws -> [VoicePendantConversation]
    func fetchSummaries(for pendantID: String) async throws -> [VoicePendantSummary]
    func fetchNotes(for pendantID: String) async throws -> [VoicePendantNote]
    func saveNote(_ content: String, for pendantID: String) async throws -> VoicePendantNote

    // Audio sharing
    func fetchVoiceNotes(for pendantID: String) async throws -> [VoiceNote]
    /// Sends a voice note to the pendant. `audioData` carries the raw bytes of
    /// the recorded/imported file (nil for demo/remote notes with no file).
    func shareAudio(note: VoiceNote, audioData: Data?, to pendantID: String) async throws -> VoicePendantCommandResponse
    func deleteVoiceNote(_ noteID: String, for pendantID: String) async throws
}

// MARK: - Active Selection

enum VoicePendantDataService {
    /// Flip to `LiveVoicePendantDataService()` when backend endpoints land.
    static var current: VoicePendantDataServicing = DemoVoicePendantDataService()
}

// MARK: - Endpoints (real API scaffold)

enum VoicePendantDataEndpoints {
    private static var base: String { APIConstants.baseURL }
    private static func pendant(_ id: String) -> String { base + "client/voice-pendants/\(id)" }

    static func settings(_ id: String) -> String { pendant(id) + "/settings" }
    static func status(_ id: String) -> String { pendant(id) + "/status" }
    static var aiModels: String { base + "client/voice-pendants/ai-models" }
    static func conversations(_ id: String) -> String { pendant(id) + "/conversations" }
    static func summaries(_ id: String) -> String { pendant(id) + "/summaries" }
    static func notes(_ id: String) -> String { pendant(id) + "/notes" }
    static func voiceNotes(_ id: String) -> String { pendant(id) + "/voice-notes" }
    static func shareAudio(_ id: String) -> String { pendant(id) + "/share-audio" }
    static func voiceNote(_ id: String, noteID: String) -> String { pendant(id) + "/voice-notes/\(noteID)" }
}

// MARK: - Demo (Pseudo) Service

final class DemoVoicePendantDataService: VoicePendantDataServicing {

    /// In-memory per-pendant settings store (seeded lazily).
    private var settingsStore: [String: VoicePendantSettings] = [:]
    private var notesStore: [String: [VoicePendantNote]] = [:]
    private var voiceNotesStore: [String: [VoiceNote]] = [:]

    private func seededSettings(for pendantID: String) -> VoicePendantSettings {
        VoicePendantSettings(
            displayName: "Living Room Pendant",
            room: "Living Room",
            volume: 0.6,
            micSensitivity: 0.7,
            wakeWordEnabled: true,
            aiModelID: "limi-voice-pro",
            language: "en-US",
            ledBrightness: 0.5,
            privacyMute: false
        )
    }

    // MARK: Settings

    func fetchSettings(for pendantID: String) async throws -> VoicePendantSettings {
        try await Task.sleep(nanoseconds: 500_000_000)
        if let existing = settingsStore[pendantID] { return existing }
        let seeded = seededSettings(for: pendantID)
        settingsStore[pendantID] = seeded
        return seeded
    }

    func updateSettings(_ settings: VoicePendantSettings, for pendantID: String) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
        settingsStore[pendantID] = settings
    }

    // MARK: Status / Models

    func fetchStatus(for pendantID: String) async throws -> VoicePendantStatusSnapshot {
        try await Task.sleep(nanoseconds: 400_000_000)
        return VoicePendantStatusSnapshot(
            batteryLevel: Int.random(in: 60...95),
            isCharging: Bool.random(),
            signalStrength: Int.random(in: 2...4),
            temperatureC: Double.random(in: 28...36).rounded(),
            uptimeHours: Int.random(in: 12...240),
            firmwareVersion: "1.4.2",
            activity: ["Idle", "Listening", "Playing"].randomElement() ?? "Idle",
            storageUsedMB: 1840,
            storageTotalMB: 4096
        )
    }

    func fetchAIModels() async throws -> [AIModelOption] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return [
            AIModelOption(id: "limi-voice-lite", name: "Limi Voice Lite", provider: "Limi",
                          detail: "Fast, on-device responses for quick commands.", tier: "Fastest"),
            AIModelOption(id: "limi-voice-pro", name: "Limi Voice Pro", provider: "Limi",
                          detail: "Balanced quality and latency for daily use.", tier: "Recommended"),
            AIModelOption(id: "gpt-realtime", name: "GPT Realtime", provider: "OpenAI",
                          detail: "Most capable conversations with richer context.", tier: "Highest quality"),
            AIModelOption(id: "claude-voice", name: "Claude Voice", provider: "Anthropic",
                          detail: "Thoughtful, long-form reasoning.", tier: "High quality")
        ]
    }

    // MARK: Memory

    func fetchConversations(for pendantID: String) async throws -> [VoicePendantConversation] {
        try await Task.sleep(nanoseconds: 700_000_000)
        let now = Date()
        return [
            VoicePendantConversation(id: "conv-1", title: "Morning routine",
                                     startedAt: now.addingTimeInterval(-3600 * 2), durationSeconds: 184,
                                     messageCount: 12, preview: "Set the lights to warm and read out today's calendar…"),
            VoicePendantConversation(id: "conv-2", title: "Grocery list",
                                     startedAt: now.addingTimeInterval(-3600 * 26), durationSeconds: 96,
                                     messageCount: 7, preview: "Add milk, eggs and coffee to the shopping list…"),
            VoicePendantConversation(id: "conv-3", title: "Dinner ideas",
                                     startedAt: now.addingTimeInterval(-3600 * 50), durationSeconds: 240,
                                     messageCount: 18, preview: "Suggest a quick pasta recipe for two people…"),
            VoicePendantConversation(id: "conv-4", title: "Focus session",
                                     startedAt: now.addingTimeInterval(-3600 * 73), durationSeconds: 320,
                                     messageCount: 9, preview: "Play focus music and start a 25 minute timer…")
        ]
    }

    func fetchSummaries(for pendantID: String) async throws -> [VoicePendantSummary] {
        try await Task.sleep(nanoseconds: 600_000_000)
        let now = Date()
        return [
            VoicePendantSummary(id: "sum-1", conversationID: "conv-1", title: "Morning routine",
                                summary: "Adjusted lighting to warm white and reviewed the day's three calendar events.",
                                createdAt: now.addingTimeInterval(-3600 * 2),
                                highlights: ["Lights set to warm", "3 meetings today", "Reminder set for 5pm"]),
            VoicePendantSummary(id: "sum-2", conversationID: "conv-3", title: "Dinner ideas",
                                summary: "Discussed quick dinner options; settled on a 15-minute garlic pasta.",
                                createdAt: now.addingTimeInterval(-3600 * 50),
                                highlights: ["Garlic pasta chosen", "Added pasta + garlic to list"])
        ]
    }

    func fetchNotes(for pendantID: String) async throws -> [VoicePendantNote] {
        try await Task.sleep(nanoseconds: 500_000_000)
        if let stored = notesStore[pendantID] { return stored }
        let now = Date()
        let seeded = [
            VoicePendantNote(id: "note-1", conversationID: "conv-2", content: "Buy milk, eggs and coffee.",
                             createdAt: now.addingTimeInterval(-3600 * 26), isPinned: true),
            VoicePendantNote(id: "note-2", conversationID: "conv-3", content: "Garlic pasta recipe for two.",
                             createdAt: now.addingTimeInterval(-3600 * 50), isPinned: false)
        ]
        notesStore[pendantID] = seeded
        return seeded
    }

    func saveNote(_ content: String, for pendantID: String) async throws -> VoicePendantNote {
        try await Task.sleep(nanoseconds: 350_000_000)
        let note = VoicePendantNote(id: "note-\(UUID().uuidString.prefix(6))", conversationID: nil,
                                    content: content, createdAt: Date(), isPinned: false)
        notesStore[pendantID, default: []].insert(note, at: 0)
        return note
    }

    // MARK: Audio

    func fetchVoiceNotes(for pendantID: String) async throws -> [VoiceNote] {
        try await Task.sleep(nanoseconds: 500_000_000)
        if let stored = voiceNotesStore[pendantID] { return stored }
        let now = Date()
        let seeded = [
            VoiceNote(id: "vn-1", title: "Welcome message", durationSeconds: 8, createdAt: now.addingTimeInterval(-3600 * 5), sharedToPendant: true),
            VoiceNote(id: "vn-2", title: "Dinner reminder", durationSeconds: 5, createdAt: now.addingTimeInterval(-3600 * 12), sharedToPendant: false),
            VoiceNote(id: "vn-3", title: "Goodnight note", durationSeconds: 11, createdAt: now.addingTimeInterval(-3600 * 30), sharedToPendant: false)
        ]
        voiceNotesStore[pendantID] = seeded
        return seeded
    }

    func shareAudio(note: VoiceNote, audioData: Data?, to pendantID: String) async throws -> VoicePendantCommandResponse {
        try await Task.sleep(nanoseconds: 900_000_000)
        if let index = voiceNotesStore[pendantID]?.firstIndex(where: { $0.id == note.id }) {
            voiceNotesStore[pendantID]?[index].sharedToPendant = true
        }
        let sizeInfo = audioData.map { "\($0.count) bytes (\(note.source.label))" } ?? "no local audio (demo note)"
        let message = audioData != nil
            ? "Sent “\(note.title)” (\(byteString(audioData!.count))) to pendant."
            : "Sent “\(note.title)” to pendant."
        return VoicePendantCommandResponse(success: true, message: message, commandID: UUID().uuidString)
    }

    private func byteString(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    func deleteVoiceNote(_ noteID: String, for pendantID: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        voiceNotesStore[pendantID]?.removeAll { $0.id == noteID }
    }
}

// MARK: - Live Service (real backend scaffold)

final class LiveVoicePendantDataService: VoicePendantDataServicing {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func fetchSettings(for pendantID: String) async throws -> VoicePendantSettings {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.settings(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode(VoicePendantSettings.self, from: data, decoder: decoder)
    }

    func updateSettings(_ settings: VoicePendantSettings, for pendantID: String) async throws {
        let body: [String: Any] = [
            "display_name": settings.displayName,
            "room": settings.room,
            "volume": settings.volume,
            "mic_sensitivity": settings.micSensitivity,
            "wake_word_enabled": settings.wakeWordEnabled,
            "ai_model_id": settings.aiModelID,
            "language": settings.language,
            "led_brightness": settings.ledBrightness,
            "privacy_mute": settings.privacyMute
        ]
        _ = try await LimiHTTPClient.perform(
            urlString: VoicePendantDataEndpoints.settings(pendantID),
            method: "PUT",
            body: body,
            auth: .requiredBearer
        )
    }

    func fetchStatus(for pendantID: String) async throws -> VoicePendantStatusSnapshot {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.status(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode(VoicePendantStatusSnapshot.self, from: data, decoder: decoder)
    }

    func fetchAIModels() async throws -> [AIModelOption] {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.aiModels, auth: .requiredBearer)
        return try LimiHTTPClient.decode([AIModelOption].self, from: data, decoder: decoder)
    }

    func fetchConversations(for pendantID: String) async throws -> [VoicePendantConversation] {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.conversations(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode([VoicePendantConversation].self, from: data, decoder: decoder)
    }

    func fetchSummaries(for pendantID: String) async throws -> [VoicePendantSummary] {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.summaries(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode([VoicePendantSummary].self, from: data, decoder: decoder)
    }

    func fetchNotes(for pendantID: String) async throws -> [VoicePendantNote] {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.notes(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode([VoicePendantNote].self, from: data, decoder: decoder)
    }

    func saveNote(_ content: String, for pendantID: String) async throws -> VoicePendantNote {
        let data = try await LimiHTTPClient.postJSON(
            urlString: VoicePendantDataEndpoints.notes(pendantID),
            body: ["content": content],
            auth: .requiredBearer
        )
        return try LimiHTTPClient.decode(VoicePendantNote.self, from: data, decoder: decoder)
    }

    func fetchVoiceNotes(for pendantID: String) async throws -> [VoiceNote] {
        let data = try await LimiHTTPClient.get(urlString: VoicePendantDataEndpoints.voiceNotes(pendantID), auth: .requiredBearer)
        return try LimiHTTPClient.decode([VoiceNote].self, from: data, decoder: decoder)
    }

    func shareAudio(note: VoiceNote, audioData: Data?, to pendantID: String) async throws -> VoicePendantCommandResponse {
        var body: [String: Any] = [
            "voice_note_id": note.id,
            "title": note.title,
            "duration_seconds": note.durationSeconds,
            "source": note.source.rawValue
        ]
        // Attach the raw audio (base64) when we have a local file. For large
        // files prefer a multipart/presigned-URL upload — swap here when the
        // backend contract is finalised.
        if let audioData {
            body["audio_base64"] = audioData.base64EncodedString()
            body["mime_type"] = note.fileURL?.pathExtension == "wav" ? "audio/wav" : "audio/m4a"
        }
        let data = try await LimiHTTPClient.postJSON(
            urlString: VoicePendantDataEndpoints.shareAudio(pendantID),
            body: body,
            auth: .requiredBearer
        )
        return try LimiHTTPClient.decode(VoicePendantCommandResponse.self, from: data, decoder: decoder)
    }

    func deleteVoiceNote(_ noteID: String, for pendantID: String) async throws {
        _ = try await LimiHTTPClient.perform(
            urlString: VoicePendantDataEndpoints.voiceNote(pendantID, noteID: noteID),
            method: "DELETE",
            auth: .requiredBearer
        )
    }
}
