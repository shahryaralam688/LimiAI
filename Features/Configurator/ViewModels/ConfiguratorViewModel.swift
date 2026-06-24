import Foundation

@MainActor
final class ConfiguratorViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var lastSnapId: String?
    @Published private(set) var lastError: String?

    func handleSnapId(
        _ snapId: String,
        macAddress: String? = nil,
        onReady: (() -> Void)? = nil
    ) {
        lastSnapId = snapId
        lastError = nil

        if let mac = macAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !mac.isEmpty {
            DeviceDownloadStore.shared.set(downloadId: snapId, forMac: mac)
        }

        downloadModel(snapId: snapId, onReady: onReady)
    }

    func handlePortalSave(
        spanID: String,
        onConfigReady: @escaping (_ lightType: String, _ downloadId: String) -> Void,
        onModelReady: @escaping () -> Void
    ) {
        isLoading = true
        lastError = nil

        LimiConfiguratorAPI.fetchLightConfig(spanID: spanID) { [weak self] json in
            Task { @MainActor in
                guard let self else { return }
                guard let json else {
                    self.isLoading = false
                    self.lastError = "Failed to load light configuration"
                    return
                }

                let lightType = json["light_type"] as? String ?? "Unknown"
                let downloadId = json["download_Id"] as? String ?? ""

                LightConfigManager.shared.lightType = lightType
                LightConfigManager.shared.downloadId = downloadId
                onConfigReady(lightType, downloadId)

                guard !downloadId.isEmpty else {
                    self.isLoading = false
                    return
                }

                self.downloadModel(snapId: downloadId, onReady: onModelReady)
            }
        }
    }

    private func downloadModel(snapId: String, onReady: (() -> Void)? = nil) {
        lastSnapId = snapId
        lastError = nil
        isLoading = true

        ConfiguratorDownloadService.downloadIfNeeded(snapId: snapId) { [weak self] outcome in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                switch outcome {
                case .alreadyCached, .downloaded:
                    onReady?()
                case .failed(let error):
                    self.lastError = error.localizedDescription
                case .skippedNoNetwork:
                    self.lastError = "No internet connection"
                }
            }
        }
    }
}
