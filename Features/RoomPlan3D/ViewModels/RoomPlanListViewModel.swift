import Foundation
import Observation

@Observable
final class RoomPlanListViewModel {
    var files: [String] = []
    var analyzingFile: String?
    var showAnalysisAlert = false

    func refreshFileList() {
        files = RoominatorFileManager.shared.listFiles()
    }

    func onAppear(isAuthenticated: Bool) {
        if isAuthenticated {
            RoomPlanUploadService.syncFromBackend { [weak self] in
                self?.refreshFileList()
            }
        } else {
            refreshFileList()
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileName = files[index]

            if RoominatorFileManager.shared.deleteFile(named: fileName) {
                RoomPlanUploadService.deleteModel(filename: fileName) { success in
                    if success {
                        print("🗑️ Deleted '\(fileName)' from both local and backend.")
                    } else {
                        print("⚠️ Deleted '\(fileName)' locally, but backend deletion failed.")
                    }
                }
                files.remove(at: index)
            }
        }
    }

    func deleteFileByName(_ fileName: String) {
        if RoominatorFileManager.shared.deleteFile(named: fileName) {
            RoomPlanUploadService.deleteModel(filename: fileName) { success in
                if success {
                    print("🗑️ Swipe deleted '\(fileName)' from backend too")
                }
            }
            files.removeAll { $0 == fileName }
        }
    }

    func beginAnalysis(for fileName: String, analyzer: (String) -> Void) {
        analyzingFile = fileName
        analyzer(fileName)
        showAnalysisAlert = true
    }
}
