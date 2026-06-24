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

    /// Start date of the window relative to now.
    func startDate(from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day: return calendar.date(byAdding: .day, value: -1, to: reference) ?? reference
        case .week: return calendar.date(byAdding: .day, value: -7, to: reference) ?? reference
        case .month: return calendar.date(byAdding: .month, value: -1, to: reference) ?? reference
        }
    }
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

// MARK: - Backend DTO (`POST /memory/summary`)

/// Envelope: `{ "success": true, "data": { ... } }` or the data object directly.
struct VoicePendantSummaryResponse: Codable {
    let data: VoicePendantSummaryDTO?
    let overview: String?
    let keyPoints: [String]?
    let actionItems: [String]?
    let topics: [String]?

    enum CodingKeys: String, CodingKey {
        case data
        case overview
        case keyPoints = "key_points"
        case actionItems = "action_items"
        case topics
    }

    /// Normalises wrapped vs flat shapes into one DTO.
    var resolved: VoicePendantSummaryDTO? {
        if let data { return data }
        if overview != nil || keyPoints != nil || actionItems != nil || topics != nil {
            return VoicePendantSummaryDTO(overview: overview, keyPoints: keyPoints,
                                          actionItems: actionItems, topics: topics)
        }
        return nil
    }
}

struct VoicePendantSummaryDTO: Codable {
    let overview: String?
    let keyPoints: [String]?
    let actionItems: [String]?
    let topics: [String]?

    enum CodingKeys: String, CodingKey {
        case overview
        case keyPoints = "key_points"
        case actionItems = "action_items"
        case topics
    }

    func toModel(range: SummaryRange) -> VoicePendantAISummary {
        VoicePendantAISummary(
            overview: overview ?? "",
            keyPoints: keyPoints ?? [],
            actionItems: actionItems ?? [],
            topics: topics ?? [],
            generatedAt: Date(),
            range: range
        )
    }
}
