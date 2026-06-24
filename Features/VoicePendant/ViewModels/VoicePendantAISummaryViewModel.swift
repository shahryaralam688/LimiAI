//
//  VoicePendantAISummaryViewModel.swift
//  Limi
//
//  Drives the AI Conversation Summary screen: Day / Week / Month selection,
//  loading + error states, manual refresh, and offline cache.
//

import Foundation
import SwiftUI

@MainActor
final class VoicePendantAISummaryViewModel: ObservableObject {

    @Published var range: SummaryRange = .day {
        didSet {
            guard oldValue != range else { return }
            loadCachedOrGenerate()
        }
    }
    @Published private(set) var summary: VoicePendantAISummary?
    @Published private(set) var isLoading = false
    @Published private(set) var isFromCache = false
    @Published var errorMessage: String?

    private let pendant: VoicePendant
    private let service: VoicePendantSummaryServicing

    init(pendant: VoicePendant,
         service: VoicePendantSummaryServicing = VoicePendantSummaryService.current) {
        self.pendant = pendant
        self.service = service
    }

    var pendantName: String { pendant.name }

    /// Initial entry: show cached summary instantly (if any), then refresh.
    func onAppear() {
        if summary == nil {
            loadCachedOrGenerate()
        }
    }

    private func loadCachedOrGenerate() {
        if let cached = VoicePendantSummaryCache.load(pendantID: pendant.id, range: range) {
            summary = cached
            isFromCache = true
        } else {
            summary = nil
            isFromCache = false
        }
        Task { await generate() }
    }

    /// Manually (re)generate the summary for the current range.
    func refresh() {
        Task { await generate(force: true) }
    }

    private func generate(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await service.generateSummary(
                for: pendant.id,
                range: range,
                recentTranscript: nil
            )
            summary = result
            isFromCache = false
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
            // Keep any cached summary visible behind the error banner.
            if summary == nil {
                summary = VoicePendantSummaryCache.load(pendantID: pendant.id, range: range)
                isFromCache = summary != nil
            }
        }
    }

    func clearError() { errorMessage = nil }
}
