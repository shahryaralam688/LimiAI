//
//  VoicePendantAISummary.swift
//  Limi
//
//  Models for the real, LLM-generated conversation summary shown in the
//  Voice Pendant memory screens (Day / Week / Month).
//

import Foundation

// MARK: - Range

enum SummaryRange: String, CaseIterable, Identifiable, Codable {
    case day
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }

    /// Backend query value.
    var apiValue: String { rawValue }

    /// Inclusive UTC `dateKey` bounds for `GET /limi-ai/daily-summaries`.
    func utcDateKeyBounds(from reference: Date = Date()) -> (from: String, to: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let today = calendar.startOfDay(for: reference)
        let fromDate: Date
        switch self {
        case .day:
            fromDate = today
        case .week:
            fromDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            fromDate = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        }
        return (Self.utcDateKeyFormatter.string(from: fromDate),
                Self.utcDateKeyFormatter.string(from: today))
    }

    private static let utcDateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Summary

/// A structured, AI-generated summary of conversations in a time window.
struct VoicePendantAISummary: Equatable, Codable {
    /// 2–4 sentence narrative overview.
    let overview: String
    /// 3–5 bullet highlights.
    let keyPoints: [String]
    /// Action items / next steps (may be empty).
    let actionItems: [String]
    /// Short topic tags.
    let topics: [String]
    /// When this summary was produced.
    let generatedAt: Date
    /// The range it covers.
    let range: SummaryRange

    var isEmpty: Bool {
        overview.isEmpty && keyPoints.isEmpty && actionItems.isEmpty && topics.isEmpty
    }
}

// MARK: - Backend DTO (`GET /limi-ai/daily-summaries`)

struct DailySummariesResponse: Decodable {
    let success: Bool?
    let data: DailySummariesData?
}

struct DailySummariesData: Decodable {
    let summaries: [DailySummaryDTO]?
}

struct DailySummaryDTO: Decodable {
    let dateKey: String?
    let overview: String?
    let summary: String?
    let text: String?
    let keyPoints: [String]?
    let actionItems: [String]?
    let topics: [String]?
    let generatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case dateKey
        case date_key
        case overview
        case summary
        case text
        case keyPoints
        case key_points
        case actionItems
        case action_items
        case topics
        case generatedAt
        case generated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decodeIfPresent(String.self, forKey: .dateKey)
            ?? container.decodeIfPresent(String.self, forKey: .date_key)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints)
            ?? container.decodeIfPresent([String].self, forKey: .key_points)
        actionItems = try container.decodeIfPresent([String].self, forKey: .actionItems)
            ?? container.decodeIfPresent([String].self, forKey: .action_items)
        topics = try container.decodeIfPresent([String].self, forKey: .topics)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .generated_at)
    }

    var resolvedOverview: String {
        [overview, summary, text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    static func aggregate(_ items: [DailySummaryDTO], range: SummaryRange) -> VoicePendantAISummary {
        let sorted = items.sorted { ($0.dateKey ?? "") > ($1.dateKey ?? "") }
        let overviews = sorted.map(\.resolvedOverview).filter { !$0.isEmpty }
        let keyPoints = sorted.flatMap { $0.keyPoints ?? [] }
        let actionItems = sorted.flatMap { $0.actionItems ?? [] }
        let topics = Self.uniquePreservingOrder(sorted.flatMap { $0.topics ?? [] })
        let latestGeneratedAt = sorted.compactMap(\.generatedAt).max() ?? Date()

        return VoicePendantAISummary(
            overview: overviews.joined(separator: "\n\n"),
            keyPoints: Self.uniquePreservingOrder(keyPoints),
            actionItems: Self.uniquePreservingOrder(actionItems),
            topics: topics,
            generatedAt: latestGeneratedAt,
            range: range
        )
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
