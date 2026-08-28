import Foundation

@MainActor
final class ARSessionViewModel: ObservableObject {
    @Published var items: [LightConfigItem] = []
    @Published var isLoading = true
    @Published var loadAttempted = false
    @Published var showOfflineAlert = false
    @Published var showPresetBanner = false
    @Published var errorMessage: String?
    @Published var statusCode: Int?

    private let stateManager: ARModelStateManager

    init(stateManager: ARModelStateManager = .shared) {
        self.stateManager = stateManager
    }

    var displayItems: [ARDisplayItem] {
        if !items.isEmpty {
            return items.map {
                ARDisplayItem(id: $0.id, name: $0.name, downloadId: $0.config.downloadId, isPreset: false)
            }
        }
        if loadAttempted {
            return stateManager.presetModels.map {
                ARDisplayItem(id: $0.id, name: $0.name, downloadId: $0.downloadId, isPreset: true)
            }
        }
        return []
    }

    var isUsingPresets: Bool {
        items.isEmpty && loadAttempted
    }

    func onAppear() {
        fetchLightConfigs()
        syncWithCurrentARModel()
    }

    func onNetworkReconnected() {
        if items.isEmpty && loadAttempted {
            fetchLightConfigs()
        }
    }

    func selectItem(_ item: ARDisplayItem) {
        stateManager.selectModel(id: item.id, downloadId: item.downloadId, name: item.name)
        stateManager.isUsingPresets = item.isPreset

        if !item.isPreset {
            ConfiguratorDownloadService.downloadIfNeeded(
                snapId: item.downloadId,
                requireNetworkWhenMissing: true
            ) { _ in }
        }
    }

    func confirmOfflinePresets() {
        stateManager.hasShownOfflineAlert = true
        showPresetBanner = true
        selectFirstPreset()
    }

    func syncWithCurrentARModel() {
        if let currentId = stateManager.selectedModelId,
           displayItems.contains(where: { $0.id == currentId }) {
            return
        }
        if let first = displayItems.first {
            stateManager.selectModel(id: first.id, downloadId: first.downloadId, name: first.name)
        }
    }

    func fetchLightConfigs() {
        isLoading = true

        LimiHTTPClient.postJSON(
            urlString: APIConstants.lightConfigsCheck,
            body: [:]
        ) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                self.loadAttempted = true

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.handleFetchFailure()
                    return
                }

                if let httpResponse = response {
                    self.statusCode = httpResponse.statusCode
                    if httpResponse.statusCode != 200 {
                        self.handleFetchFailure()
                        return
                    }
                }

                guard let data else {
                    self.errorMessage = "No data received"
                    self.handleFetchFailure()
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode([LightConfigItem].self, from: data)
                    if decoded.isEmpty {
                        self.handleFetchFailure()
                        return
                    }

                    self.saveLightConfigsCache(data)
                    self.items = decoded
                    self.errorMessage = nil
                    self.stateManager.isUsingPresets = false
                    self.syncWithCurrentARModel()
                } catch {
                    self.errorMessage = "Failed to decode response"
                    self.handleFetchFailure()
                }
            }
        }
    }

    private func handleFetchFailure() {
        isLoading = false
        loadAttempted = true

        if loadCachedLightConfigs() {
            return
        }

        if !stateManager.hasShownOfflineAlert {
            showOfflineAlert = true
        } else {
            showPresetBanner = true
            selectFirstPreset()
        }
    }

    private func selectFirstPreset() {
        guard let first = stateManager.presetModels.first else { return }
        stateManager.selectModel(id: first.id, downloadId: first.downloadId, name: first.name)
        stateManager.isUsingPresets = true
    }

    private var cacheFileURL: URL? {
        do {
            let directory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return directory.appendingPathComponent("light_configs_cache.json")
        } catch {
            return nil
        }
    }

    private func saveLightConfigsCache(_ data: Data) {
        guard let fileURL = cacheFileURL else { return }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch { /* ignored */ }
    }

    @discardableResult
    private func loadCachedLightConfigs() -> Bool {
        guard let fileURL = cacheFileURL else { return false }
        do {
            let cachedData = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([LightConfigItem].self, from: cachedData)
            guard !decoded.isEmpty else { return false }

            items = decoded
            stateManager.isUsingPresets = false
            syncWithCurrentARModel()
            showPresetBanner = true
            return true
        } catch {
            return false
        }
    }
}
