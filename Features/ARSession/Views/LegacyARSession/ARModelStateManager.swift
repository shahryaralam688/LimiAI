//
//  ARModelStateManager.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 17/12/2025.
//

import SwiftUI
import Combine

// MARK: - Preset Model Data (Built-in offline fallback)
struct PresetModel: Identifiable {
    let id: String
    let name: String
    let downloadId: String
    let isPreset: Bool = true
}

// MARK: - AR Model State Manager (Singleton)
final class ARModelStateManager: ObservableObject {
    static let shared = ARModelStateManager()
    
    // Currently selected model ID (synced between list and AR view)
    @Published var selectedModelId: String?
    @Published var selectedDownloadId: String?
    @Published var selectedModelName: String?
    
    // Data source status
    @Published var isUsingPresets: Bool = false
    @Published var hasShownOfflineAlert: Bool = false
    
    // Preset models for offline/fallback mode
    let presetModels: [PresetModel] = [
        PresetModel(id: "preset_1", name: "My Device", downloadId: "mount1"),
        PresetModel(id: "preset_2", name: "Living Room Light", downloadId: "mount2"),
        PresetModel(id: "preset_3", name: "Bedroom Lamp", downloadId: "mount3")
    ]
    
    private init() {}
    
    func selectModel(id: String, downloadId: String, name: String) {
        selectedModelId = id
        selectedDownloadId = downloadId
        selectedModelName = name
        
        NotificationCenter.default.post(
            name: .arModelSelectionChanged,
            object: nil,
            userInfo: ["downloadId": downloadId, "name": name]
        )
    }
    
    func resetOfflineAlert() {
        hasShownOfflineAlert = false
    }
}

// MARK: - Notification for model selection changes
extension Notification.Name {
    static let arModelSelectionChanged = Notification.Name("arModelSelectionChanged")
}
