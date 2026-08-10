//
//  VoicePendantSummaryService.swift
//  Limi
//
//  Loads AI conversation summaries for the pendant memory screens via
//  `GET /limi-ai/daily-summaries` (UTC dateKey window + optional limit).
//
//  Demo implementation returns canned structured data for previews/offline.
//

import Foundation

// MARK: - Protocol

protocol VoicePendantSummaryServicing {
    /// Loads an AI summary for a pendant over a time range.
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
    /// `GET` — daily summaries. Query: `from`, `to` (YYYY-MM-DD UTC), `limit` (default 90 on server).
    static var dailySummaries: String { APIConstants.limiAIDailySummaries }
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

    private static let defaultLimit = 90

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func generateSummary(for pendantID: String,
                         range: SummaryRange,
                         recentTranscript: String?) async throws -> VoicePendantAISummary {
        do {
            let summary = try await fetchDailySummaries(range: range)
            VoicePendantSummaryCache.save(summary, pendantID: pendantID)
            return summary
        } catch {
            if let cached = VoicePendantSummaryCache.load(pendantID: pendantID, range: range) {
                return cached
            }
            throw error
        }
    }

    private func fetchDailySummaries(range: SummaryRange) async throws -> VoicePendantAISummary {
        let bounds = range.utcDateKeyBounds()
        guard var components = URLComponents(string: VoicePendantSummaryEndpoints.dailySummaries) else {
            throw LimiAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "from", value: bounds.from),
            URLQueryItem(name: "to", value: bounds.to),
            URLQueryItem(name: "limit", value: String(Self.defaultLimit))
        ]
        guard let urlString = components.url?.absoluteString else {
            throw LimiAPIError.invalidURL
        }

        let data = try await LimiHTTPClient.get(urlString: urlString, auth: .requiredBearer)
        let response = try LimiHTTPClient.decode(DailySummariesResponse.self, from: data, decoder: decoder)
        let items = response.data?.summaries ?? []
        return DailySummaryDTO.aggregate(items, range: range)
    }
}
