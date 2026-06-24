//
//  VoicePendantMemory.swift
//  Limi
//
//  Models for the Summary & Memory screens: conversation history,
//  AI summaries, notes generated from conversations and a searchable
//  memory timeline.
//

import Foundation

// MARK: - Conversation History

/// A single conversation captured by the pendant.
struct VoicePendantConversation: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let startedAt: Date
    let durationSeconds: Int
    let messageCount: Int
    /// Short preview of the transcript.
    let preview: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startedAt = "started_at"
        case durationSeconds = "duration_seconds"
        case messageCount = "message_count"
        case preview
    }
}

// MARK: - AI Summaries

/// An AI-generated summary of a conversation.
struct VoicePendantSummary: Identifiable, Equatable, Codable {
    let id: String
    let conversationID: String
    let title: String
    let summary: String
    let createdAt: Date
    /// Optional bullet highlights / action items.
    let highlights: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case title
        case summary
        case createdAt = "created_at"
        case highlights
    }
}

// MARK: - Notes

/// A note generated from (or attached to) a conversation.
struct VoicePendantNote: Identifiable, Equatable, Codable {
    let id: String
    let conversationID: String?
    var content: String
    let createdAt: Date
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case content
        case createdAt = "created_at"
        case isPinned = "is_pinned"
    }
}

// MARK: - Unified Timeline

enum MemoryItemKind: String, CaseIterable, Equatable {
    case conversation
    case summary
    case note

    var displayName: String {
        switch self {
        case .conversation: return "Conversations"
        case .summary: return "Summaries"
        case .note: return "Notes"
        }
    }

    var icon: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .summary: return "doc.text.fill"
        case .note: return "note.text"
        }
    }
}

/// A normalized item for the searchable memory timeline.
struct MemoryTimelineItem: Identifiable, Equatable {
    let id: String
    let kind: MemoryItemKind
    let title: String
    let detail: String
    let timestamp: Date

    /// Lowercased haystack used for in-memory search.
    var searchHaystack: String {
        "\(title) \(detail)".lowercased()
    }
}
