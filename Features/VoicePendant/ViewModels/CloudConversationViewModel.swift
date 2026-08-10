//
//  CloudConversationViewModel.swift
//  Limi
//
//  Drives the backend-connected Cloud AI Chat thread. Holds the message
//  history, persists the backend `conversation_id` so every turn continues
//  the same conversation, and syncs each turn to `POST /messages`.
//

import Foundation
import SwiftUI

@MainActor
final class CloudConversationViewModel: ObservableObject {

    @Published private(set) var messages: [PendantChatMessage] = []
    @Published private(set) var isAwaitingReply = false
    @Published var draft: String = ""
    @Published var errorMessage: String?

    /// Persisted backend conversation id — sent on every subsequent turn.
    private(set) var conversationID: String?

    private let pendant: VoicePendant
    private let service: VoicePendantChatServicing

    init(pendant: VoicePendant,
         service: VoicePendantChatServicing = VoicePendantChatService.current) {
        self.pendant = pendant
        self.service = service
        self.conversationID = Self.loadConversationID(for: pendant.id)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAwaitingReply
    }

    var pendantName: String { pendant.name }
    var pendantID: String { pendant.id }

    // MARK: - Sending

    /// Sends the current draft text.
    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        ingestUserText(text)
    }

    /// Shared entry for both typed and voice-transcribed user input.
    func ingestUserText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAwaitingReply else { return }

        let userMessage = PendantChatMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        VoicePendantMessageSync.sync(role: .user, text: trimmed, conversationID: conversationID)

        let placeholder = PendantChatMessage(role: .assistant, text: "", isPending: true)
        messages.append(placeholder)
        isAwaitingReply = true
        errorMessage = nil

        Task { await deliver(userPrompt: trimmed, placeholderID: placeholder.id) }
    }

    private func deliver(userPrompt: String, placeholderID: String) async {
        do {
            let result = try await service.send(userPrompt: userPrompt, conversationID: conversationID)
            if let newID = result.conversationID, newID != conversationID {
                conversationID = newID
                Self.saveConversationID(newID, for: pendant.id)
            }
            replacePlaceholder(placeholderID, with: result.assistantText, isError: false)
            VoicePendantMessageSync.sync(role: .assistant, text: result.assistantText, conversationID: conversationID)
        } catch {
            let message = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            replacePlaceholder(placeholderID, with: "⚠️ Couldn't reach Limi. Tap retry.", isError: true)
        }
        isAwaitingReply = false
    }

    private func replacePlaceholder(_ id: String, with text: String, isError: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        messages[index].isPending = false
    }

    /// Re-sends the last user message (after an error).
    func retryLast() {
        guard !isAwaitingReply,
              let lastUser = messages.last(where: { $0.role == .user }) else { return }
        // Drop a trailing failed assistant bubble if present.
        if let last = messages.last, last.role == .assistant {
            messages.removeLast()
        }
        ingestUserText(lastUser.text)
    }

    func clearError() { errorMessage = nil }

    // MARK: - Conversation id persistence

    private static func storageKey(for pendantID: String) -> String {
        "voicePendant.conversationID.\(pendantID)"
    }

    private static func loadConversationID(for pendantID: String) -> String? {
        UserDefaults.standard.string(forKey: storageKey(for: pendantID))
    }

    private static func saveConversationID(_ id: String, for pendantID: String) {
        UserDefaults.standard.set(id, forKey: storageKey(for: pendantID))
    }
}
