//
//  VoicePendantSummaryService.swift
//  Limi
//
//  Produces a real, LLM-generated conversation summary for the pendant memory
//  screens. Strategy:
//    1. Preferred: `POST /memory/summary` (structured backend endpoint).
//    2. Fallback: ask the cloud chat LLM (`POST /limi-ai/chat`) to summarise
//       recent conversation text and return structured JSON.
//    3. Local cache: last successful summary per (pendant, range) is cached so
//       the screen still shows something offline.
//
//  Demo implementation returns canned structured data for previews/offline.
//

import Foundation

// MARK: - Protocol

protocol VoicePendantSummaryServicing {
    /// Generates (or regenerates) an AI summary for a pendant over a time range.
    /// `recentTranscript` is optional context used by the chat fallback.
    func generateSummary(for pendantID: String,
                         range: SummaryRange,
                         recentTranscript: String?) async throws -> VoicePendantAISummary
}

// MARK: - Active Selection

enum VoicePendantSummaryService {
    static var current: VoicePendantSummaryServicing = LiveVoicePendantSummaryService()
}

// MARK: - Endpoints

enum VoicePendantSummaryEndpoints {
    /// `POST` — structured memory summary. Body: `{ "pendant_id": ..., "range": "day|week|month" }`.
    static var summary: String { APIConstants.baseURL + "memory/summary" }
}

// MARK: - Local Cache

enum VoicePendantSummaryCache {
    private static func key(pendantID: String, range: SummaryRange) -> String {
        "voicePendant.aiSummary.\(pendantID).\(range.rawValue)"
    }

    static func load(pendantID: String, range: SummaryRange) -> VoicePendantAISummary? {
        guard let data = UserDefaults.standard.data(forKey: key(pendantID: pendantID, range: range)) else {
            return nil
        }
        return try? JSONDecoder().decode(VoicePendantAISummary.self, from: data)
    }

    static func save(_ summary: VoicePendantAISummary, pendantID: String) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: key(pendantID: pendantID, range: summary.range))
    }
}

// MARK: - Demo Service

final class DemoVoicePendantSummaryService: VoicePendantSummaryServicing {

    func generateSummary(for pendantID: String,
                         range: SummaryRange,
                         recentTranscript: String?) async throws -> VoicePendantAISummary {
        try await Task.sleep(nanoseconds: 1_100_000_000)
        switch range {
        case .day:
            return VoicePendantAISummary(
                overview: "Aaj din mein lighting aur calendar ke around baat hui. Limi ne lights warm white set kiye aur 3 meetings review karwayin.",
                keyPoints: ["Lights set to warm white", "Reviewed 3 calendar events", "Reminder set for 5pm"],
                actionItems: ["Buy milk, eggs and coffee", "Confirm 5pm reminder"],
                topics: ["Lighting", "Calendar", "Reminders"],
                generatedAt: Date(),
                range: range
            )
        case .week:
            return VoicePendantAISummary(
                overview: "Is hafte conversations mostly home automation, grocery planning aur dinner ideas par thi. Routines establish huin aur kuch shopping items add huay.",
                keyPoints: ["Daily lighting routine tuned", "Grocery list built up over 3 days", "Garlic pasta chosen for dinner", "Focus sessions scheduled"],
                actionItems: ["Restock pantry on weekend", "Try the 15-min pasta recipe"],
                topics: ["Home Automation", "Groceries", "Cooking", "Focus"],
                generatedAt: Date(),
                range: range
            )
        case .month:
            return VoicePendantAISummary(
                overview: "Is mahine ka overall theme productivity + comfort raha. Aap ne morning/evening routines automate kiye, regularly groceries plan kiye aur focus time track kiya.",
                keyPoints: ["Morning and evening automations set", "Consistent grocery planning", "Several focus sessions completed", "Recurring dinner suggestions"],
                actionItems: ["Review automation schedule", "Plan next month's meals"],
                topics: ["Productivity", "Routines", "Groceries", "Wellbeing"],
                generatedAt: Date(),
                range: range
            )
        }
    }
}

// MARK: - Live Service

final class LiveVoicePendantSummaryService: VoicePendantSummaryServicing {

    private let chatService: VoicePendantChatServicing
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(chatService: VoicePendantChatServicing = VoicePendantChatService.current) {
        self.chatService = chatService
    }

    func generateSummary(for pendantID: String,
                         range: SummaryRange,
                         recentTranscript: String?) async throws -> VoicePendantAISummary {
        // 1. Preferred structured endpoint.
        do {
            let summary = try await fetchStructuredSummary(pendantID: pendantID, range: range)
            VoicePendantSummaryCache.save(summary, pendantID: pendantID)
            return summary
        } catch {
            // 2. Fallback to the chat LLM.
            do {
                let summary = try await summariseViaChat(range: range, transcript: recentTranscript)
                VoicePendantSummaryCache.save(summary, pendantID: pendantID)
                return summary
            } catch {
                // 3. Offline cache, else surface the error.
                if let cached = VoicePendantSummaryCache.load(pendantID: pendantID, range: range) {
                    return cached
                }
                throw error
            }
        }
    }

    // MARK: Preferred endpoint

    private func fetchStructuredSummary(pendantID: String, range: SummaryRange) async throws -> VoicePendantAISummary {
        let data = try await LimiHTTPClient.postJSON(
            urlString: VoicePendantSummaryEndpoints.summary,
            body: ["pendant_id": pendantID, "range": range.apiValue],
            auth: .requiredBearer
        )
        let response = try LimiHTTPClient.decode(VoicePendantSummaryResponse.self, from: data, decoder: decoder)
        guard let dto = response.resolved else {
            throw LimiAPIError.backend(message: "Empty summary response.")
        }
        return dto.toModel(range: range)
    }

    // MARK: Chat fallback

    private func summariseViaChat(range: SummaryRange, transcript: String?) async throws -> VoicePendantAISummary {
        let context = (transcript?.isEmpty == false)
            ? transcript!
            : "Recent voice conversations with the Limi pendant."
        let prompt = """
        Summarise the user's conversations for the past \(range.displayName.lowercased()). \
        Match the language of the conversation (Urdu + English mix is fine). \
        Respond ONLY with compact JSON in this exact shape, no extra text:
        {"overview":"2-4 sentences","key_points":["..."],"action_items":["..."],"topics":["..."]}

        Conversation context:
        \(context)
        """

        let result = try await chatService.send(userPrompt: prompt, conversationID: nil)
        guard let dto = Self.extractSummaryJSON(from: result.assistantText) else {
            // Last resort: wrap the raw reply as the overview.
            return VoicePendantAISummary(
                overview: result.assistantText,
                keyPoints: [], actionItems: [], topics: [],
                generatedAt: Date(), range: range
            )
        }
        return dto.toModel(range: range)
    }

    /// Extracts the first `{ ... }` JSON object from an LLM reply and decodes it.
    private static func extractSummaryJSON(from text: String) -> VoicePendantSummaryDTO? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VoicePendantSummaryDTO.self, from: data)
    }
}
