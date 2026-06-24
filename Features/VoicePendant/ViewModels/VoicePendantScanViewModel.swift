//
//  VoicePendantScanViewModel.swift
//  Limi
//
//  Drives the Voice Pendant Scan listing + command flow.
//

import Foundation
import SwiftUI

@MainActor
final class VoicePendantScanViewModel: ObservableObject {

    // MARK: Listing state
    @Published private(set) var pendants: [VoicePendant] = []
    @Published private(set) var isScanning: Bool = false
    @Published var errorMessage: String?

    // MARK: Per-pendant transient state
    /// IDs currently running a connect request.
    @Published private(set) var connectingIDs: Set<String> = []
    /// IDs currently relaying a command.
    @Published private(set) var busyCommandIDs: Set<String> = []
    /// Latest acknowledgement text, surfaced as a transient toast.
    @Published var lastAcknowledgement: String?

    private let service: VoicePendantServicing

    init(service: VoicePendantServicing = VoicePendantService.current) {
        self.service = service
    }

    #if DEBUG
    /// Pre-populated state for SwiftUI previews (skips network).
    init(previewPendants: [VoicePendant], isScanning: Bool = false, errorMessage: String? = nil) {
        self.service = DemoVoicePendantService()
        self.pendants = previewPendants
        self.isScanning = isScanning
        self.errorMessage = errorMessage
    }
    #endif

    var hasLoadedOnce: Bool { !pendants.isEmpty || errorMessage != nil }

    // MARK: - Scan / Listing

    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            let result = try await service.fetchPendants()
            pendants = result
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
        isScanning = false
    }

    // MARK: - Connect

    func isConnecting(_ pendant: VoicePendant) -> Bool {
        connectingIDs.contains(pendant.id)
    }

    func connect(to pendant: VoicePendant) async {
        guard !connectingIDs.contains(pendant.id) else { return }
        connectingIDs.insert(pendant.id)
        defer { connectingIDs.remove(pendant.id) }

        do {
            try await service.connect(to: pendant.id)
            if let index = pendants.firstIndex(where: { $0.id == pendant.id }) {
                pendants[index].status = .online
            }
            lastAcknowledgement = "Connected to \(pendant.name)"
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Commands

    func isSendingCommand(_ pendant: VoicePendant) -> Bool {
        busyCommandIDs.contains(pendant.id)
    }

    func send(_ command: VoicePendantCommand, to pendant: VoicePendant) async {
        guard !busyCommandIDs.contains(pendant.id) else { return }
        busyCommandIDs.insert(pendant.id)
        defer { busyCommandIDs.remove(pendant.id) }

        do {
            let response = try await service.sendCommand(command, to: pendant.id)
            lastAcknowledgement = response.message ?? "Sent: \(command.displayDescription)"
        } catch {
            errorMessage = (error as? LimiAPIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
