//
//  RoomCaptureController.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import Foundation
import RoomPlan
import Observation


@Observable
class RoomCaptureController: RoomCaptureViewDelegate, RoomCaptureSessionDelegate, ObservableObject {
    required init?(coder: NSCoder) {
        fatalError("Not needed.")
    }
    
    func encode(with coder: NSCoder) {
       fatalError("Not needed.")
    }
    
    private var _roomCaptureView: RoomCaptureView?
    
    var roomCaptureView: RoomCaptureView {
        if _roomCaptureView == nil {
            let view = RoomCaptureView(frame: .zero)  // Full frame, not 42x42
            view.captureSession.delegate = self
            view.delegate = self
            _roomCaptureView = view
        }
        return _roomCaptureView!
    }
    
    var showSaveButton = false
    var isScanComplete = false
    var showNameInputSheet = false
    var fileName = ""
    
    var sessionConfig: RoomCaptureSession.Configuration
    var finalResult: CapturedRoom?
    
    init() {
        sessionConfig = RoomCaptureSession.Configuration()
        // ✅ roomCaptureView is NOT initialized here
        // It will be created on first access
    }
    
    func startSession() {
        roomCaptureView.captureSession.run(configuration: sessionConfig)
    }
    
    func stopSession() {
        roomCaptureView.captureSession.stop()
    }
    
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }
    
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResult = processedResult
        showSaveButton = true
        isScanComplete = true
    }
    
    func saveScan() {
        guard let finalResult = finalResult else {
            print("No scan result to save.")
            return
        }

        let fileNameWithExtension = fileName.hasSuffix(".usdz") ? fileName : "\(fileName).usdz"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileNameWithExtension)
        let categorizedObjects = categorizeRoomObjects(finalResult.objects)

        do {
            try finalResult.export(to: tempURL)

            if let data = try? Data(contentsOf: tempURL) {
                if RoominatorFileManager.shared.saveUSDZFile(data, withName: fileNameWithExtension) {
                    print("✅ Local save complete.")

                    // Upload the file after saving
                    if let _ = RoominatorFileManager.shared.getUSDZFileURL(for: fileNameWithExtension) {
                        //uploadScanModel(fileURL: fileURL, metadata: ["name": fileName]) // Send metadata like name
                    }

                    printCategorizedObjects(categorizedObjects)
                } else {
                    print("❌ Failed to save processed scan file.")
                }
            } else {
                print("❌ Failed to process USDZ file.")
            }
        } catch {
            print("❌ Error exporting and saving usdz scan: \(error)")
        }

        try? FileManager.default.removeItem(at: tempURL)
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
            
            if categorized[category] == nil {
                categorized[category] = []
            }
            categorized[category]?.append(object)
        }
        
        return categorized
    }
    
    private func printCategorizedObjects(_ categorizedObjects: [String: [CapturedRoom.Object]]) {
        print("Categorized objects:")
        for (category, objects) in categorizedObjects {
            print("  \(category): \(objects.count) items")
            for object in objects {
                print("    - \(object.category): \(object.dimensions)")
            }
        }
    }
}


//
//  RoomCaptureController+Analysis.swift
//  ForReal Demo
//
//  Created by Vatsal Patel on 8/17/24.
//

import Foundation
import RoomPlan

extension RoomCaptureController {
    
    /// Analyzes a saved USDZ file and prints dimensions to console
    /// - Parameter fileName: Name of the USDZ file to analyze
    func analyzeUSDZFile(_ fileName: String) {
        let analyzer = USDZAnalyzer()
        analyzer.analyzeUSDZFile(fileName: fileName)
    }
    
    /// Analyzes the current scan result and prints dimensions to console
    func analyzeCurrentScan() {
        guard let finalResult = finalResult else {
            print("No scan result available to analyze.")
            return
        }
        
        print("\n📊 ANALYZING CURRENT SCAN")
        print("======================================")
        
        // Analyze surfaces
//        analyzeSurfaces(finalResult.surfaces)
        
        // Analyze objects
        analyzeObjects(finalResult.objects)
    }
    
    /// Analyzes surfaces from RoomPlan data
    private func analyzeSurfaces(_ surfaces: [CapturedRoom.Surface]) {
        print("\n🧱 SURFACES")
        print("--------------------------------------")
        
        var totalWallArea: Float = 0
        var totalFloorArea: Float = 0
        let totalCeilingArea: Float = 0
        
        for (index, surface) in surfaces.enumerated() {
            let dimensions = surface.dimensions
            let area = dimensions.x * dimensions.y
            
            print("Surface #\(index + 1) (\(surface.category)):")
            print("  • Width: \(formatMeasurement(dimensions.x)) m")
            print("  • Height: \(formatMeasurement(dimensions.y)) m")
            print("  • Thickness: \(formatMeasurement(dimensions.z)) m")
            print("  • Area: \(formatMeasurement(area)) m²")
            
            switch surface.category {
            case .wall:
                totalWallArea += area
            case .floor:
                totalFloorArea += area
//            case .ceiling:
//                totalCeilingArea += area
            case .door:
                // Door area calculation
                break
            case .window:
                // Window area calculation
                break
            case .opening:
                // Opening area calculation
                break
            @unknown default:
                break
            }
        }
        
        print("\nTotal Areas:")
        print("  • Wall Area: \(formatMeasurement(totalWallArea)) m²")
        print("  • Floor Area: \(formatMeasurement(totalFloorArea)) m²")
        print("  • Ceiling Area: \(formatMeasurement(totalCeilingArea)) m²")
    }
    
    /// Analyzes objects from RoomPlan data
    private func analyzeObjects(_ objects: [CapturedRoom.Object]) {
        print("\n🪑 OBJECTS")
        print("--------------------------------------")
        
        let categorizedObjects = categorizeRoomObjects(objects)
        
        for (category, items) in categorizedObjects {
            print("\n\(category) (\(items.count) items):")
            
            for (index, object) in items.enumerated() {
                let dimensions = object.dimensions
                print("  \(index + 1). \(object.category):")
                print("    • Width: \(formatMeasurement(dimensions.x)) m")
                print("    • Height: \(formatMeasurement(dimensions.y)) m")
                print("    • Depth: \(formatMeasurement(dimensions.z)) m")
//                print("    • Position: (\(formatMeasurement(object.transform.position.x)), \(formatMeasurement(object.transform.position.y)), \(formatMeasurement(object.transform.position.z)))")
            }
        }
    }
    
    /// Formats a measurement to 2 decimal places
    private func formatMeasurement(_ value: Float) -> String {
        return String(format: "%.2f", value)
    }
    func uploadScanModel(fileURL: URL, metadata: [String: String]) {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: APIConstants.uploadRoom3DModel)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        print("🔐 Preparing request to upload 3D model...")

        // Add token if needed
        if let token = AuthManager.shared.getToken() {
            request.setValue("\(token)", forHTTPHeaderField: "Authorization")
            print("✅ Authorization token set.")
        } else {
            print("⚠️ No authorization token found.")
        }

        var body = Data()

        // Add file
        do {
            let fileData = try Data(contentsOf: fileURL)
            print("📂 File loaded from: \(fileURL.path)")
            print("📦 File size: \(fileData.count) bytes")

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: model/vnd.usdz+zip\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            print("✅ File data appended to body.")
        } catch {
            print("❌ Error reading file: \(error)")
            return
        }

        // Add metadata
        for (key, value) in metadata {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata[\(key)]\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
            print("📝 Metadata added: \(key) = \(value)")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        print("📤 Request body prepared. Starting upload...")

        // Perform upload
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Upload error: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Upload status code: \(httpResponse.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📬 Upload response: \(responseString)")
            } else {
                print("📭 No response data received.")
            }
        }.resume()
    }



}
