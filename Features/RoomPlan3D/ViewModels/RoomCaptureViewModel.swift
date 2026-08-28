import Foundation
import Observation
import RoomPlan

@Observable
final class RoomCaptureViewModel {
    var showSaveButton = false
    var isScanComplete = false
    var showNameInputSheet = false
    var fileName = ""
    var uploadError: String?

    weak var captureController: RoomCaptureController?

    func resetScanState() {
        showSaveButton = false
        isScanComplete = false
        uploadError = nil
    }

    func markScanComplete() {
        showSaveButton = true
        isScanComplete = true
    }

    func saveAndUploadScan(dismiss: () -> Void) {
        guard let controller = captureController,
              let finalResult = controller.finalResult else {
            return
        }

        let fileNameWithExtension = fileName.hasSuffix(".usdz") ? fileName : "\(fileName).usdz"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileNameWithExtension)
        let categorizedObjects = categorizeRoomObjects(finalResult.objects)

        do {
            try finalResult.export(to: tempURL)

            if let data = try? Data(contentsOf: tempURL),
               RoominatorFileManager.shared.saveUSDZFile(data, withName: fileNameWithExtension) {
                printCategorizedObjects(categorizedObjects)

                if let fileURL = RoominatorFileManager.shared.getUSDZFileURL(for: fileNameWithExtension) {
                    uploadScan(fileURL: fileURL, displayName: fileName)
                }
            } else {
            }
        } catch { /* ignored */ }

        try? FileManager.default.removeItem(at: tempURL)
        dismiss()
    }

    func uploadScan(fileURL: URL, displayName: String) {
        uploadError = nil
        RoomPlanUploadService.uploadScan(
            fileURL: fileURL,
            metadata: ["name": displayName]
        ) { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                } else {
                    self?.uploadError = message ?? "Upload failed"
                }
            }
        }
    }

    func analyzeUSDZFile(_ fileName: String) {
        USDZAnalyzer().analyzeUSDZFile(fileName: fileName)
    }

    func analyzeCurrentScan() {
        guard let finalResult = captureController?.finalResult else {
            return
        }

        analyzeObjects(finalResult.objects)
    }

    private func categorizeRoomObjects(_ objects: [CapturedRoom.Object]) -> [String: [CapturedRoom.Object]] {
        var categorized = [String: [CapturedRoom.Object]]()

        for object in objects {
            let category: String
            switch object.category {
            case .refrigerator, .oven, .dishwasher, .washerDryer:
                category = "Appliance"
            case .table:
                category = "Table"
            case .bed:
                category = "Bed"
            case .chair, .sofa:
                category = "Seating"
            case .storage:
                category = "Storage"
            case .bathtub, .toilet:
                category = "Bathroom Fixture"
            case .sink:
                category = "Sink"
            case .television:
                category = "Television"
            default:
                category = "Other"
            }

            categorized[category, default: []].append(object)
        }

        return categorized
    }

    private func printCategorizedObjects(_ categorizedObjects: [String: [CapturedRoom.Object]]) {
        for (category, objects) in categorizedObjects {
            for object in objects {
            }
        }
    }

    private func analyzeObjects(_ objects: [CapturedRoom.Object]) {

        let categorizedObjects = categorizeRoomObjects(objects)

        for (category, items) in categorizedObjects {

            for (index, object) in items.enumerated() {
                let dimensions = object.dimensions
            }
        }
    }

    private func formatMeasurement(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}
