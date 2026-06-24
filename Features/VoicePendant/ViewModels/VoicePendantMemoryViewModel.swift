//
//  VoicePendantMemoryViewModel.swift
//  Limi
//
//  Backs the Summary & Memory screens: conversation history, AI summaries,
//  notes and the searchable, unified memory timeline.
//

import Foundation
import SwiftUI

@MainActor
final class VoicePendantMemoryViewModel: ObservableObject {

    let pendant: VoicePendant

    @Published private(set) var conversations: [VoicePendantConversation] = []
    @Published private(set) var summaries: [VoicePendantSummary] = []
    @Published private(set) var notes: [VoicePendantNote] = []

    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // Timeline controls
    @Published var searchText: String = ""
    /// nil = show all kinds.
    @Published var kindFilter: MemoryItemKind?

    private let service: VoicePendantDataServicing

    init(pendant: VoicePendant, service: VoicePendantDataServicing = VoicePendantDataService.current) {
        self.pendant = pendant
        self.service = service
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let c = service.fetchConversations(for: pendant.id)
            async let s = service.fetchSummaries(for: pendant.id)
            async let n = service.fetchNotes(for: pendant.id)
            let (conv, sum, nt) = try await (c, s, n)
            conversations = conv
            summaries = sum
            notes = nt
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addNote(_ content: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let note = try await service.saveNote(trimmed, for: pendant.id)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Unified Timeline

    /// All items merged into one normalized list, newest first.
    var allTimelineItems: [MemoryTimelineItem] {
        var items: [MemoryTimelineItem] = []

        items += conversations.map {
            MemoryTimelineItem(id: "c-\($0.id)", kind: .conversation, title: $0.title,
                               detail: $0.preview, timestamp: $0.startedAt)
        }
        items += summaries.map {
            MemoryTimelineItem(id: "s-\($0.id)", kind: .summary, title: $0.title,
                               detail: $0.summary, timestamp: $0.createdAt)
        }
        items += notes.map {
            MemoryTimelineItem(id: "n-\($0.id)", kind: .note, title: "Note",
                               detail: $0.content, timestamp: $0.createdAt)
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// Timeline after applying the kind filter + search query.
    var filteredTimeline: [MemoryTimelineItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allTimelineItems.filter { item in
            let matchesKind = kindFilter == nil || item.kind == kindFilter
            let matchesQuery = query.isEmpty || item.searchHaystack.contains(query)
            return matchesKind && matchesQuery
        }
    }

    func count(for kind: MemoryItemKind) -> Int {
        switch kind {
        case .conversation: return conversations.count
        case .summary: return summaries.count
        case .note: return notes.count
        }
    }
}
