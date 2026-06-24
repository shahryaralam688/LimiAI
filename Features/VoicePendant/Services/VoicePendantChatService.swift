//
//  VoicePendantChatService.swift
//  Limi
//
//  Networking for the backend-connected Cloud AI Chat thread.
//
//  Two implementations behind one protocol (same pattern as the rest of the
//  module):
//    • DemoVoicePendantChatService — canned, offline replies for previews.
//    • LiveVoicePendantChatService — real cloud calls to `POST /limi-ai/chat`.
//
//  Multi-turn context is preserved by persisting the backend `conversation_id`
//  and resending it on every subsequent request.
//

import Foundation

// MARK: - Protocol

protocol VoicePendantChatServicing {
    /// Sends a user prompt to the Limi cloud assistant.
    /// - Parameters:
    ///   - userPrompt: Raw user text (voice transcript or typed).
    ///   - conversationID: Existing backend conversation id, or `nil` to start a new one.
    /// - Returns: The assistant reply + (possibly new) conversation id.
    func send(userPrompt: String, conversationID: String?) async throws -> ChatTurnResult
}

// MARK: - Active Selection

enum VoicePendantChatService {
    /// Live cloud chat by default; previews inject the demo service.
    static var current: VoicePendantChatServicing = LiveVoicePendantChatService()
}

// MARK: - Endpoints

enum VoicePendantChatEndpoints {
    /// `POST` — multi-turn cloud chat. Body: `{ "user_prompt": "...", "conversation_id": "<optional>" }`.
    static var chat: String { APIConstants.baseURL + "limi-ai/chat" }
    /// `POST` — message sync for history. Body: role/text/source/conversation_id.
    static var messages: String { APIConstants.baseURL + "messages" }
}

// MARK: - Demo Service

/// Offline echo-style assistant. Keeps a fake conversation id stable across turns.
final class DemoVoicePendantChatService: VoicePendantChatServicing {

    func send(userPrompt: String, conversationID: String?) async throws -> ChatTurnResult {
        try await Task.sleep(nanoseconds: 900_000_000)
        let id = conversationID ?? "demo-conv-\(UUID().uuidString.prefix(8))"
        let reply: String
        let lowered = userPrompt.lowercased()
        if lowered.contains("light") || lowered.contains("لائٹ") {
            reply = "Sure — I can adjust your lights. Which room and what mood would you like?"
        } else if lowered.contains("hello") || lowered.contains("hi") || lowered.contains("salam") {
            reply = "Hey! I'm Limi. How can I help with your pendant today?"
        } else {
            reply = "Got it. You said: “\(userPrompt)”. (Demo mode — connect to the cloud for full answers.)"
        }
        return ChatTurnResult(conversationID: id, assistantText: reply)
    }
}

// MARK: - Live Service

/// Talks to the Limi cloud chat endpoint and persists the returned conversation id
/// (handled by the caller / view model) for multi-turn context.
final class LiveVoicePendantChatService: VoicePendantChatServicing {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func send(userPrompt: String, conversationID: String?) async throws -> ChatTurnResult {
        var body: [String: Any] = ["user_prompt": userPrompt]
        if let conversationID, !conversationID.isEmpty {
            body["conversation_id"] = conversationID
        }

        let data = try await LimiHTTPClient.postJSON(
            urlString: VoicePendantChatEndpoints.chat,
            body: body,
            auth: .requiredBearer
        )

        let response = try LimiHTTPClient.decode(LimiChatResponse.self, from: data, decoder: decoder)
        guard let reply = response.data?.resolvedReply else {
            throw LimiAPIError.backend(message: response.message ?? "Limi did not return a reply.")
        }
        return ChatTurnResult(
            conversationID: response.data?.conversationID ?? conversationID,
            assistantText: reply
        )
    }
}

// MARK: - Message Sync (best-effort, fire-and-forget)

enum VoicePendantMessageSync {
    /// Syncs a single turn to `POST /messages`. Failures are swallowed (best effort).
    static func sync(role: PendantChatMessage.Role, text: String, conversationID: String?) {
        var body: [String: Any] = [
            "role": role.rawValue,
            "text": text,
            "source": "voice_pendant_chat"
        ]
        if let conversationID, !conversationID.isEmpty {
            body["conversationId"] = conversationID
        }
        Task {
            _ = try? await LimiHTTPClient.postJSON(
                urlString: VoicePendantChatEndpoints.messages,
                body: body,
                auth: .requiredBearer
            )
        }
    }
}
