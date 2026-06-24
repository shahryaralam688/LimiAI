//
//  VoicePendantDetailViewModel.swift
//  Limi
//
//  Backs the device detail hub, controls and settings screens.
//

import Foundation
import SwiftUI

@MainActor
final class VoicePendantDetailViewModel: ObservableObject {

    let pendant: VoicePendant

    // Settings / configuration
    @Published var settings: VoicePendantSettings?
    @Published private(set) var isLoadingSettings = false
    @Published private(set) var isSaving = false

    // Status monitoring
    @Published var status: VoicePendantStatusSnapshot?
    @Published private(set) var isLoadingStatus = false

    // AI model selection
    @Published var aiModels: [AIModelOption] = []

    @Published var errorMessage: String?
    @Published var toastMessage: String?

    private let service: VoicePendantDataServicing

    init(pendant: VoicePendant, service: VoicePendantDataServicing = VoicePendantDataService.current) {
        self.pendant = pendant
        self.service = service
    }

    var selectedModel: AIModelOption? {
        guard let id = settings?.aiModelID else { return nil }
        return aiModels.first { $0.id == id }
    }

    // MARK: - Loading

    func loadAll() async {
        async let s: Void = loadSettings()
        async let st: Void = loadStatus()
        async let m: Void = loadModels()
        _ = await (s, st, m)
    }

    func loadSettings() async {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            settings = try await service.fetchSettings(for: pendant.id)
        } catch {
            errorMessage = describe(error)
        }
    }

    func loadStatus() async {
        isLoadingStatus = true
        defer { isLoadingStatus = false }
        do {
            status = try await service.fetchStatus(for: pendant.id)
        } catch {
            errorMessage = describe(error)
        }
    }

    func loadModels() async {
        do {
            aiModels = try await service.fetchAIModels()
        } catch {
            errorMessage = describe(error)
        }
    }

    func refreshStatus() async {
        await loadStatus()
    }

    // MARK: - Mutations

    func save() async {
        guard let settings else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.updateSettings(settings, for: pendant.id)
            toastMessage = "Settings saved"
        } catch {
            errorMessage = describe(error)
        }
    }

    func selectModel(_ model: AIModelOption) {
        settings?.aiModelID = model.id
        Task { await save() }
    }

    private func describe(_ error: Error) -> String {
        (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
    }
}
