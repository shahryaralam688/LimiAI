//
//  VoicePendantAudio.swift
//  Limi
//
//  Models for the Audio Sharing screen: sending audio from the mobile app
//  to a pendant, playback controls and voice note management.
//

import Foundation

// MARK: - Voice Note

/// Where a voice note originated from.
enum VoiceNoteSource: String, Codable, Equatable {
    /// Recorded in-app via the microphone.
    case recorded
    /// Imported from Files / another app (share sheet, storage).
    case imported
    /// Seeded/remote demo note with no local audio file.
    case remote

    var icon: String {
        switch self {
        case .recorded: return "mic.fill"
        case .imported: return "square.and.arrow.down.fill"
        case .remote: return "icloud.fill"
        }
    }

    var label: String {
        switch self {
        case .recorded: return "Recorded"
        case .imported: return "Imported"
        case .remote: return "Library"
        }
    }
}

/// A recorded/imported voice note that can be shared to a pendant.
struct VoiceNote: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    let durationSeconds: Double
    let createdAt: Date
    /// Whether this note has already been pushed to the pendant.
    var sharedToPendant: Bool
    var source: VoiceNoteSource
    /// Local audio file on disk (for recorded/imported notes). Not sent to
    /// the backend as JSON — the raw bytes are uploaded separately.
    var fileURL: URL? = nil

    init(
        id: String,
        title: String,
        durationSeconds: Double,
        createdAt: Date,
        sharedToPendant: Bool,
        source: VoiceNoteSource = .remote,
        fileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.sharedToPendant = sharedToPendant
        self.source = source
        self.fileURL = fileURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
        case sharedToPendant = "shared_to_pendant"
        case source
    }

    /// True when there is real audio on disk to play/upload.
    var hasLocalAudio: Bool { fileURL != nil }

    var formattedDuration: String {
        let total = Int(durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Playback

enum AudioPlaybackState: Equatable {
    case idle
    case playing(noteID: String)
    case paused(noteID: String)

    var activeNoteID: String? {
        switch self {
        case .idle: return nil
        case .playing(let id), .paused(let id): return id
        }
    }

    func isPlaying(_ noteID: String) -> Bool {
        if case .playing(let id) = self { return id == noteID }
        return false
    }
}
