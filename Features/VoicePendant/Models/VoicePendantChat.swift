//
//  VoicePendantChat.swift
//  Limi
//
//  Models for the backend-connected Cloud AI Chat thread inside the Voice
//  Pendant module. A conversation is a chronological list of `ChatMessage`s
//  exchanged with the Limi cloud assistant via `POST /limi-ai/chat`.
//

import Foundation

// MARK: - Chat Message

/// One turn in a cloud conversation thread (user or assistant).
struct PendantChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: String
    let role: Role
    var text: String
    let createdAt: Date
    /// True while the assistant reply is still streaming/in-flight (placeholder bubble).
    var isPending: Bool

    init(id: String = UUID().uuidString,
         role: Role,
         text: String,
         createdAt: Date = Date(),
         isPending: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isPending = isPending
    }
}

// MARK: - Chat Turn Result

/// Result of a single `/limi-ai/chat` round-trip.
struct ChatTurnResult: Equatable {
    /// Backend-assigned conversation id (persist + resend on next turn).
    let conversationID: String?
    /// The assistant's reply text.
    let assistantText: String
}

// MARK: - Backend DTOs (`POST /limi-ai/chat`)

/// Top-level envelope: `{ "success": true, "data": { ... } }`.
struct LimiChatResponse: Codable {
    let success: Bool?
    let message: String?
    let data: LimiChatData?
}

struct LimiChatData: Codable {
    let conversationID: String?
    let assistantMessage: LimiChatAssistantMessage?
    /// Some backends return the reply text at the top level instead of nested.
    let reply: String?

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case assistantMessage = "assistant_message"
        case reply
    }

    /// Best-effort extraction of the assistant reply across response shapes.
    var resolvedReply: String? {
        if let content = assistantMessage?.content, !content.isEmpty { return content }
        if let reply, !reply.isEmpty { return reply }
        return nil
    }
}

struct LimiChatAssistantMessage: Codable {
    let role: String?
    let content: String?
}
