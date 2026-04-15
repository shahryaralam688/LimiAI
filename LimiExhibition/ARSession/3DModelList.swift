//
//  PortalCongigurator.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 11/12/2025.
//

import SwiftUI
import Network

struct LightConfigItem: Identifiable, Codable {
    let id: String
    let name: String
    let config: LightConfig

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case config
    }
}

struct LightConfig: Codable {
    let lightType: String
    let lightAmount: Int
    let cableColor: String
    let baseType: String
    let downloadId: String

    enum CodingKeys: String, CodingKey {
        case lightType = "light_type"
        case lightAmount = "light_amount"
        case cableColor = "cable_color"
        case baseType = "base_type"
        case downloadId = "download_Id"
    }
}

// MARK: - Unified Display Item (works for both online and preset data)
struct ARDisplayItem: Identifiable {
    let id: String
    let name: String
    let downloadId: String
    let isPreset: Bool
}

struct ARModelList: View {
    @State private var statusCode: Int? = nil
    @State private var items: [LightConfigItem] = []
    @State private var errorMessage: String? = nil
    @StateObject private var stateManager = ARModelStateManager.shared
    @StateObject private var networkMonitor = NetworkMonitor()
    
    // Alert states
    @State private var showOfflineAlert = false
    @State private var showPresetBanner = false
    @State private var isLoading = true
    @State private var loadAttempted = false
    
    // Computed display items (online data or presets)
    private var displayItems: [ARDisplayItem] {
        if !items.isEmpty {
            return items.map { ARDisplayItem(id: $0.id, name: $0.name, downloadId: $0.config.downloadId, isPreset: false) }
        } else if loadAttempted {
            return stateManager.presetModels.map { ARDisplayItem(id: $0.id, name: $0.name, downloadId: $0.downloadId, isPreset: true) }
        }
        return []
    }
    
    private var isUsingPresets: Bool {
        items.isEmpty && loadAttempted
    }

    var body: some View {
        VStack(spacing: 0) {
            // Preset mode banner
            if isUsingPresets && showPresetBanner {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Using built-in presets")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button(action: { showPresetBanner = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
            }
            
            if !displayItems.isEmpty {
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                ForEach(displayItems) { item in
                                    Button(action: {
                                        selectItem(item)
                                    }) {
                                        VStack(spacing: 6) {
                                            HStack(spacing: 4) {
                                                Text(item.name)
                                                    .font(.subheadline)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                if item.isPreset {
                                                    Image(systemName: "cube.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            .padding(.horizontal, 2)
                                            .foregroundColor(.themeWhite)
                                            .padding(4)
                                            .background(stateManager.selectedModelId == item.id ? Color.gray.opacity(0.5) : Color.clear)
                                            .cornerRadius(6)
                                            
                                            Image("1.0")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 45, height: 45)
                                                .padding(4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(stateManager.selectedModelId == item.id ? Color.themeWhite : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .frame(width: UIScreen.main.bounds.width / 3.5)
                                        .padding(.vertical, 8)
                                        .id(item.id)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if item.id != displayItems.last?.id {
                                        Divider()
                                            .frame(height: 60)
                                            .background(Color.gray.opacity(0.3))
                                    }
                                }
                            }
                        }
                        .onChange(of: stateManager.selectedModelId) { newId in
                            if let id = newId {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.themeBlack.opacity(0.9))
                )
                .padding(.horizontal, 0)
                
            } else if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                    Text("Loading models...")
                        .foregroundColor(.themeWhite)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color.themeBlack.opacity(0.9))
            }
        }
        .padding(.horizontal, 0)
        .onAppear {
            fetchLightConfigs()
            syncWithCurrentARModel()
        }
        .alert("Offline Mode", isPresented: $showOfflineAlert) {
            Button("Use Presets", role: .cancel) {
                stateManager.hasShownOfflineAlert = true
                showPresetBanner = true
                selectFirstPreset()
            }
            Button("Retry", role: .none) {
                fetchLightConfigs()
            }
        } message: {
            Text("Unable to load your devices. You can use built-in preset models or retry when connected.")
        }
        .onChange(of: networkMonitor.isConnected) { isConnected in
            if isConnected && items.isEmpty && loadAttempted {
                fetchLightConfigs()
            }
        }
    }
    
    private func selectItem(_ item: ARDisplayItem) {
        stateManager.selectModel(id: item.id, downloadId: item.downloadId, name: item.name)
        
        if item.isPreset {
            stateManager.isUsingPresets = true
        } else {
            stateManager.isUsingPresets = false
            downloadUSDZUsingAPI(downloadId: item.downloadId)
        }
    }
    
    private func selectFirstPreset() {
        if let first = stateManager.presetModels.first {
            stateManager.selectModel(id: first.id, downloadId: first.downloadId, name: first.name)
            stateManager.isUsingPresets = true
        }
    }
    
    private func syncWithCurrentARModel() {
        if let currentId = stateManager.selectedModelId,
           displayItems.contains(where: { $0.id == currentId }) {
            // Already synced
        } else if let first = displayItems.first {
            stateManager.selectModel(id: first.id, downloadId: first.downloadId, name: first.name)
        }
    }

    private func handleSelection(_ item: LightConfigItem) {
        let downloadId = item.config.downloadId
        print("Selected item name: \(item.name), downloadId: \(downloadId)")
        stateManager.selectModel(id: item.id, downloadId: downloadId, name: item.name)
        downloadUSDZUsingAPI(downloadId: downloadId)
    }

    func fetchLightConfigs() {
        isLoading = true
        
        guard let url = URL(string: APIConstants.lightConfigsCheck) else {
            print("Invalid URL")
            handleFetchFailure()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        
        if let token = AuthManager.shared.getToken() {
            request.setValue("\(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("Auth token is nil; cannot set Authorization header")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.loadAttempted = true
            }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.handleFetchFailure()
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.statusCode = httpResponse.statusCode
                }
                
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.handleFetchFailure()
                    }
                    return
                }
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                    self.handleFetchFailure()
                }
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response: \(jsonString)")
            }

            do {
                let decoded = try JSONDecoder().decode([LightConfigItem].self, from: data)
                
                if decoded.isEmpty {
                    DispatchQueue.main.async {
                        self.handleFetchFailure()
                    }
                    return
                }
                
                self.saveLightConfigsCache(data)
                DispatchQueue.main.async {
                    self.items = decoded
                    self.errorMessage = nil
                    self.stateManager.isUsingPresets = false
                    self.syncWithCurrentARModel()
                }
            } catch {
                print("Failed to decode JSON: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode response"
                    self.handleFetchFailure()
                }
            }
        }.resume()
    }
    
    private func handleFetchFailure() {
        isLoading = false
        loadAttempted = true
        
        // Try loading from cache first
        if loadCachedLightConfigs() {
            return
        }
        
        // No cache available - show offline alert if not already shown
        if !stateManager.hasShownOfflineAlert {
            showOfflineAlert = true
        } else {
            showPresetBanner = true
            selectFirstPreset()
        }
    }

    private func downloadUSDZUsingAPI(downloadId: String) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator")

        if !fileManager.fileExists(atPath: configuratorFolderURL.path) {
            do {
                try fileManager.createDirectory(at: configuratorFolderURL, withIntermediateDirectories: true)
                print("✅ Configurator folder created at: \(configuratorFolderURL.path)")
            } catch {
                print("❌ Failed to create folder: \(error)")
                return
            }
        }

        let fileURL = configuratorFolderURL.appendingPathComponent("\(downloadId).usdz")

        if fileManager.fileExists(atPath: fileURL.path) {
            print("✅ Model already exists at: \(fileURL.path), using cached file")
            return
        }

        checkInternetConnection { hasInternet in
            guard hasInternet else {
                print("❌ No internet connection and no cached model for id: \(downloadId)")
                return
            }

            guard let url = URL(string: APIConstants.webConfiguratorDownload(downloadId)) else {
                print("❌ Invalid download URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Download error: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    print("❌ No data in response")
                    return
                }

                do {
                    try data.write(to: fileURL)
                    print("✅ Model saved at: \(fileURL.path)")
                } catch {
                    print("❌ Save error: \(error)")
                }
            }

            task.resume()
        }
    }

    private func checkInternetConnection(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.pathUpdateHandler = { path in
            completion(path.status == .satisfied)
            monitor.cancel()
        }
        monitor.start(queue: queue)
    }

    private var cacheFileURL: URL? {
        do {
            let directory = try FileManager.default.url(for: .documentDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
            return directory.appendingPathComponent("light_configs_cache.json")
        } catch {
            print("Failed to resolve cache directory: \(error)")
            return nil
        }
    }

    private func saveLightConfigsCache(_ data: Data) {
        guard let fileURL = cacheFileURL else { return }
        do {
            try data.write(to: fileURL, options: [.atomic])
            print("Light configs cached at: \(fileURL.path)")
        } catch {
            print("Failed to write cache file: \(error)")
        }
    }

    @discardableResult
    private func loadCachedLightConfigs() -> Bool {
        guard let fileURL = cacheFileURL else { return false }
        do {
            let cachedData = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([LightConfigItem].self, from: cachedData)
            
            guard !decoded.isEmpty else { return false }
            
            DispatchQueue.main.async {
                self.items = decoded
                self.stateManager.isUsingPresets = false
                self.syncWithCurrentARModel()
                
                // Show subtle cached data indicator
                if !self.networkMonitor.isConnected {
                    self.showPresetBanner = true
                }
            }
            print("Loaded light configs from cache")
            return true
        } catch {
            print("Failed to load cached light configs: \(error)")
            return false
        }
    }
}

#Preview {
    ARModelList()
}
