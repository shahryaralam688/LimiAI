import Foundation
import SwiftUI

// MARK: - Module Model
struct Module: Identifiable {
    let id: Int
    let icon: String
    let titleKey: String
    var status: ModuleStatus

    var title: String {
        titleKey.localized
    }
}

enum ModuleStatus {
    case addModule
    case added
}

// MARK: - Modules Manager
class ModulesManager: ObservableObject {
    static let shared = ModulesManager()
    
    @Published var modules: [Module] = [
        Module(id: 1, icon: "iconDevices", titleKey: "module.device_manager.title", status: .addModule),
        Module(id: 2, icon: "iconConfigurator", titleKey: "module.configurator.title", status: .addModule),
        Module(id: 3, icon: "iconAR", titleKey: "module.ar_view.title", status: .addModule),
        Module(id: 4, icon: "iconRoomplan", titleKey: "module.room_scan.title", status: .addModule),
        Module(id: 5, icon: "VoiceAi", titleKey: "module.voice_pendant_scan.title", status: .addModule)
    ]
    
    private let modulesStorageKey = "savedModulesStatus"
    
    init() {
        loadModulesFromUserDefaults()
    }
    
    func toggleModuleStatus(for id: Int) {
        if let index = modules.firstIndex(where: { $0.id == id }) {
            modules[index].status = modules[index].status == .addModule ? .added : .addModule
            saveModulesToUserDefaults()
        }
    }
    
    func saveModulesToUserDefaults() {
        let modulesData = modules.map { ["id": $0.id, "status": $0.status == .added ? 1 : 0] }
        UserDefaults.standard.set(modulesData, forKey: modulesStorageKey)
        UserDefaults.standard.synchronize()
        print("✅ Modules saved to UserDefaults")
    }
    
    func loadModulesFromUserDefaults() {
        if let savedData = UserDefaults.standard.array(forKey: modulesStorageKey) as? [[String: Int]] {
            for savedModule in savedData {
                if let id = savedModule["id"], let statusValue = savedModule["status"],
                   let index = modules.firstIndex(where: { $0.id == id }) {
                    modules[index].status = statusValue == 1 ? .added : .addModule
                }
            }
            print("✅ Modules loaded from UserDefaults")
        }
    }
    
    func getAddedModules() -> [Module] {
        return modules.filter { $0.status == .added }
    }
    
    func clearModules() {
        UserDefaults.standard.removeObject(forKey: modulesStorageKey)
        modules = [
            Module(id: 1, icon: "iconDevices", titleKey: "module.device_manager.title", status: .addModule),
            Module(id: 2, icon: "iconConfigurator", titleKey: "module.configurator.title", status: .addModule),
            Module(id: 3, icon: "iconAR", titleKey: "module.ar_view.title", status: .addModule),
            Module(id: 4, icon: "iconRoomplan", titleKey: "module.room_scan.title", status: .addModule),
            Module(id: 5, icon: "VoiceAi", titleKey: "module.voice_pendant_scan.title", status: .addModule)
        ]
    }
}
