


import SwiftUI
import RealityKit
import ARKit

struct TestingARPreviewView: View {
    var body: some View {
        ZStack {
            // State for which pendant is selected (1, 2, or 3)
            TestingARPreviewContent()
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct TestingARPreviewContent: View {
    @State private var selectedPendantIndex: Int = 1
    @State private var selectedBaseIndex: Int = 1
    @State private var activeTab: String = "pendants"  // "base" or "pendants"

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TestingARViewContainer(selectedPendantIndex: selectedPendantIndex, selectedBaseIndex: selectedBaseIndex)

            // Modern toggle + options panel
            VStack(spacing: 16) {
                
                Spacer()

                // Toggle buttons
                HStack(spacing: 0) {
                    Button(action: { activeTab = "base" }) {
                        Text("Base")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(activeTab == "base" ? .white : .gray)
                            .background(activeTab == "base" ? Color.blue : Color.clear)
                    }

                    Button(action: { activeTab = "pendants" }) {
                        Text("Pendants")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(activeTab == "pendants" ? .white : .gray)
                            .background(activeTab == "pendants" ? Color.blue : Color.clear)
                    }
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .frame(height: 40)

                // Options based on active tab
                if activeTab == "base" {
                    VStack(spacing: 10) {
                        Text("Base Options")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: { selectedBaseIndex = 1 }) {
                            HStack {
                                Circle()
                                    .fill(selectedBaseIndex == 1 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Base 1")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }

                        Button(action: { selectedBaseIndex = 2 }) {
                            HStack {
                                Circle()
                                    .fill(selectedBaseIndex == 2 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Base 2")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }

                        Button(action: { selectedBaseIndex = 3 }) {
                            HStack {
                                Circle()
                                    .fill(selectedBaseIndex == 3 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Base 3")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 10) {
                        Text("Pendant Options")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: { selectedPendantIndex = 1 }) {
                            HStack {
                                Circle()
                                    .fill(selectedPendantIndex == 1 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Pendant 1")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }

                        Button(action: { selectedPendantIndex = 2 }) {
                            HStack {
                                Circle()
                                    .fill(selectedPendantIndex == 2 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Pendant 2")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }

                        Button(action: { selectedPendantIndex = 3 }) {
                            HStack {
                                Circle()
                                    .fill(selectedPendantIndex == 3 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Pendant 3")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }

                        Button(action: { selectedPendantIndex = 4 }) {
                            HStack {
                                Circle()
                                    .fill(selectedPendantIndex == 4 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text("Pendant 4")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                }

            }
            .padding(16)
            .frame(maxWidth: 200)
        }
    }
}

struct TestingARViewContainer: UIViewRepresentable {
    let selectedPendantIndex: Int
    let selectedBaseIndex: Int
    
    class Coordinator {
        var modelEntity: ModelEntity?
        var pendantEntities: [Entity] = []
        var baseChildEntity: Entity?
        var currentBaseIndex: Int = 1
        private var accumulatedYaw: Float = 0      // Y axis rotation (left/right)
        private var accumulatedPitch: Float = 0    // X axis rotation (up/down)
        private var lastPanLocation: CGPoint = .zero
        private var isRotating = false
        private var isDragging = false
        private var initialDragOffset: SIMD3<Float>?   // Offset from hit point to model center
        private var lastDragHitPosition: SIMD3<Float>? // Last raycast hit position in world space
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? ARView, let model = modelEntity else { return }
            
            let location = gesture.location(in: view)
            
            switch gesture.state {
            case .began:
                // Start drag only if touch begins on the model
                if let _ = view.entity(at: location) {
                    let query = view.makeRaycastQuery(from: location,
                                                      allowing: .existingPlaneGeometry,
                                                      alignment: .any)
                    if let query = query,
                       let hit = view.session.raycast(query).first {
                        let hitPosition = simd_make_float3(hit.worldTransform.columns.3)
                        let modelWorldPosition = model.position(relativeTo: nil)
                        initialDragOffset = modelWorldPosition - hitPosition
                        lastDragHitPosition = hitPosition
                        isDragging = true
                    }
                }
                
            case .changed:
                guard isDragging, let offset = initialDragOffset else { return }
                let query = view.makeRaycastQuery(from: location,
                                                  allowing: .existingPlaneGeometry,
                                                  alignment: .any)
                if let query = query,
                   let hit = view.session.raycast(query).first {
                    let hitPosition = simd_make_float3(hit.worldTransform.columns.3)
                    lastDragHitPosition = hitPosition
                    
                    // Target position is hit point plus initial offset
                    let targetPosition = hitPosition + offset
                    let currentPosition = model.position(relativeTo: nil)
                    
                    // Smooth interpolation to reduce jitter
                    let smoothing: Float = 0.3
                    let newPosition = currentPosition + (targetPosition - currentPosition) * smoothing
                    model.setPosition(newPosition, relativeTo: nil)
                }
                
                // Keep the model's orientation fixed (no rotation from drag)
                model.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                
            case .ended, .cancelled, .failed:
                isRotating = false
                isDragging = false
                initialDragOffset = nil
                lastDragHitPosition = nil
                
            default:
                break
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Debug helper for model info (optional but useful)
    private func debugPrintModelInfo(root: Entity, from url: URL) {
        print("================================")
        print("Loaded model from: \(url.lastPathComponent)")
        print("Root entity name: '\(root.name)' type: \(type(of: root))")

        var modelEntityCount = 0
        var meshSubmeshCount = 0
        var materialCount = 0
        var materialNames: [String] = []

        func walk(_ entity: Entity, level: Int = 0) {
            let indent = String(repeating: "  ", count: level)
            print("loadEntity\(entity)")
            print("\(indent)\(entity.name)' [\(type(of: entity))]")

//            // Transform info
//            let t = entity.transform
//            print("\(indent)  Transform:")
//            print("\(indent)    translation: \(t.translation)")
//            print("\(indent)    rotation: \(t.rotation)")
//            print("\(indent)    scale: \(t.scale)")

            // Model / mesh / material info
            if let modelEntity = entity as? ModelEntity {
                modelEntityCount += 1
//                print("\(indent)  ✅ Has ModelComponent")

                if let modelComp = modelEntity.model {
                    let mesh = modelComp.mesh

                    // This isn't a perfect "submesh count" but gives an idea of pieces
                    let submeshCount = mesh.contents.models.count
                    meshSubmeshCount += submeshCount
//                    print("\(indent)    Mesh submesh count (approx): \(submeshCount)")

                    let mats = modelComp.materials
                    materialCount += mats.count
//                    print("\(indent)    Materials (\(mats.count)):")
//                    for (index, material) in mats.enumerated() {
//                        let matName = ((material.name?.isEmpty) != nil) ? "<unnamed>" : material.name
//                        print("\(indent)      [\(index)] \(matName) – \(type(of: material))")
//                        materialNames.append(matName ?? "")
//                    }
                } else {
                    print("\(indent)    ModelEntity has no ModelComponent")
                }
            }

//            if !entity.children.isEmpty {
//                print("\(indent)  Children count: \(entity.children.count)")
//            }

            for child in entity.children {
                walk(child, level: level + 1)
            }
        }

        walk(root)

        print("---------- SUMMARY ----------")
        print("Total ModelEntity objects: \(modelEntityCount)")
        print("Total mesh submeshes (approx): \(meshSubmeshCount)")
        print("Total materials: \(materialCount)")
        let uniqueNames = Array(Set(materialNames))
        print("Unique material names (\(uniqueNames.count)):")
        for name in uniqueNames {
            print("  • \(name)")
        }
        print("================================")
    }

    // MARK: - Helper to find an entity by name in the hierarchy
    private func findEntity(named name: String, in root: Entity) -> Entity? {
        if root.name == name { return root }
        for child in root.children {
            if let found = findEntity(named: name, in: child) {
                return found
            }
        }
        return nil
    }

    // Helper to attach the selected pendant (UNiBAse1/2/3) to the connector
    private func attachPendant(index: Int, to root: Entity, coordinator: Coordinator) {
        // Decide which cable entities to use based on the current base model
        let cableNames: [String]
        switch coordinator.currentBaseIndex {
        case 1:
            // Base1.usdz has only cable1
            cableNames = ["cable0"]
        case 2:
            // Base2.usdz has cable1, cable2, cable3
            cableNames = ["cable0", "cable1", "cable2"]
        case 3:
            // Base3.usdz has cable2 to cable6
            cableNames = ["cable0", "cable1" , "cable2", "cable3", "cable4", "cable5"]
        default:
            cableNames = ["cable0"]
        }

        // Remove any previously attached pendants
        for existing in coordinator.pendantEntities {
            existing.removeFromParent()
        }
        coordinator.pendantEntities.removeAll()

        let baseName = "UNiBAse\(index)"

        guard let pendantURL = Bundle.main.url(
            forResource: baseName,
            withExtension: "usdz",
            subdirectory: "art.scnassets"
        ) else {
            print("Could not find \(baseName).usdz in art.scnassets")
            return
        }

        do {
            // Load the pendant once and then clone it for each connector
            let basePendant = try Entity.load(contentsOf: pendantURL)

            for cableName in cableNames {
                guard let cableEntity = findEntity(named: cableName, in: root) else {
                    print("Cable entity '\(cableName)' not found in model hierarchy")
                    continue
                }

                // Attach the pendant model to every direct child of this cable
                for child in cableEntity.children {
                    let pendantEntity = basePendant.clone(recursive: true)
                    pendantEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
                    pendantEntity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))

                    child.addChild(pendantEntity)
                    coordinator.pendantEntities.append(pendantEntity)
                }
            }
        } catch {
            print("Failed to load pendant model \(baseName).usdz: \(error)")
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.cameraMode = .ar

        // Show live camera feed as background
        arView.environment.background = .cameraFeed()

        // Prefer a downloaded model in Documents/Configurator/<downloadId>.usdz, where downloadId is mapped from macAddress
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator", isDirectory: true)

        // Resolve download id from persistent mapping using the provided macAddress
        let downloadId: String? = " "
        let downloadedModelURL: URL? = downloadId.map { configuratorFolderURL.appendingPathComponent("\($0).usdz") }

        // Resolve source URL: downloaded file if present, else bundled fallback based on selected base
        let sourceURL: URL = {
            if let dlURL = downloadedModelURL, fileManager.fileExists(atPath: dlURL.path) {
                return dlURL
            }

            let baseFileName: String
            switch selectedBaseIndex {
            case 1:
                baseFileName = "Base1"
            case 2:
                baseFileName = "Base2"
            case 3:
                baseFileName = "Base3"
            default:
                baseFileName = "Base1"
            }

            guard let fallback = Bundle.main.url(
                forResource: baseFileName,
                withExtension: "usdz",
                subdirectory: "art.scnassets"
            ) else {
                fatalError("Could not find \(baseFileName).usdz in art.scnassets and no downloaded model present")
            }
            return fallback
        }()

        // Load the USDZ as a generic Entity
        let loadedEntity: Entity
        do {
            loadedEntity = try Entity.load(contentsOf: sourceURL)
        } catch {
            fatalError("Failed to load model at \(sourceURL.lastPathComponent): \(error)")
        }

        context.coordinator.baseChildEntity = loadedEntity
        context.coordinator.currentBaseIndex = selectedBaseIndex

        // 🔍 Print meshes / materials / hierarchy for this model
        debugPrintModelInfo(root: loadedEntity, from: sourceURL)

        // Attach the selected pendant model (UNiBAse1/2/3) to the 'connector' entity inside MountWithBase
        attachPendant(index: selectedPendantIndex, to: loadedEntity, coordinator: context.coordinator)

        // Recenter the loaded entity so its visual center sits at the origin (0,0,0)
        let bounds = loadedEntity.visualBounds(relativeTo: nil)
        let center = bounds.center
        loadedEntity.position = SIMD3<Float>(center.x, center.y, center.z)

        // Rotate the model to appear right side up in AR
        // First rotate 180° around X axis to flip it upright
        // Then rotate 180° around Y axis to face the correct direction
        let rotateX = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0)) // 180° around X
        let rotateY = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))  // 180° around Y
        loadedEntity.transform.rotation = rotateY * rotateX  // Apply Y rotation first, then X

        // Wrap it in a ModelEntity container so we always have HasCollision support
        let modelEntity = ModelEntity()
        modelEntity.addChild(loadedEntity)

        // Scale the model so it almost completely fills the frame
        let size = bounds.extents
        let largestDimension = max(size.x, max(size.y, size.z))
        let targetHeight: Float = 2.0   // extremely large logical height
        if largestDimension > 0 {
            let uniformScale = targetHeight / largestDimension
            modelEntity.scale = SIMD3<Float>(repeating: uniformScale)
        }

        // Position and attach the model to a detected ceiling plane in AR
        modelEntity.transform.translation = SIMD3<Float>(0, 0, 0)

        // Make sure the entity has collision so gestures can work properly
        modelEntity.generateCollisionShapes(recursive: true)

        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            if #available(iOS 13.0, *) {
                configuration.planeDetection.insert(.horizontal)
            }
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            if #available(iOS 13.0, *) {
                let ceilingAnchor = AnchorEntity(.plane(.horizontal, classification: .ceiling, minimumBounds: [0.2, 0.2]))
                ceilingAnchor.addChild(modelEntity)
                arView.scene.addAnchor(ceilingAnchor)
            } else {
                let anchor = AnchorEntity(world: SIMD3<Float>(0, 1.5, 0))
                anchor.addChild(modelEntity)
                arView.scene.addAnchor(anchor)
            }
        } else {
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 1.5, 0))
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)
        }

        // Attach pan gesture to control rotation around X and Y axes
        context.coordinator.modelEntity = modelEntity
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(panGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // When the selected base index changes, swap the loaded base model in-place
        if let modelEntity = context.coordinator.modelEntity {
            if context.coordinator.currentBaseIndex != selectedBaseIndex {
                // Remove previous base child if present
                if let previousBase = context.coordinator.baseChildEntity {
                    previousBase.removeFromParent()
                    context.coordinator.baseChildEntity = nil
                }

                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator", isDirectory: true)

                let downloadId: String? = " "
                let downloadedModelURL: URL? = downloadId.map { configuratorFolderURL.appendingPathComponent("\($0).usdz") }

                let sourceURL: URL = {
                    if let dlURL = downloadedModelURL, fileManager.fileExists(atPath: dlURL.path) {
                        return dlURL
                    }

                    let baseFileName: String
                    switch selectedBaseIndex {
                    case 1:
                        baseFileName = "Base1"
                    case 2:
                        baseFileName = "Base2"
                    case 3:
                        baseFileName = "Base3"
                    default:
                        baseFileName = "Base1"
                    }
                    // pending to place 3d model
                    
                    guard let fallback = Bundle.main.url(
                        forResource: baseFileName,
                        withExtension: "usdz",
                        subdirectory: "art.scnassets"
                    ) else {
                        fatalError("Could not find \(baseFileName).usdz in art.scnassets and no downloaded model present")
                    }
                    return fallback
                }()

                do {
                    let newLoadedEntity = try Entity.load(contentsOf: sourceURL)

                    let bounds = newLoadedEntity.visualBounds(relativeTo: nil)
                    let center = bounds.center
                    newLoadedEntity.position = SIMD3<Float>(center.x, center.y, center.z)

                    let rotateX = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
                    let rotateY = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                    newLoadedEntity.transform.rotation = rotateY * rotateX

                    modelEntity.addChild(newLoadedEntity)

                    // Regenerate collision shapes so gestures keep working with the new base
                    modelEntity.generateCollisionShapes(recursive: true)

                    let size = bounds.extents
                    let largestDimension = max(size.x, max(size.y, size.z))
                    let targetHeight: Float = 2.0
                    if largestDimension > 0 {
                        let uniformScale = targetHeight / largestDimension
                        modelEntity.scale = SIMD3<Float>(repeating: uniformScale)
                    }

                    context.coordinator.baseChildEntity = newLoadedEntity
                    context.coordinator.currentBaseIndex = selectedBaseIndex
                } catch {
                    print("Failed to load model at \(sourceURL.lastPathComponent): \(error)")
                }
            }

            // When the selected pendant index changes, update the attached pendant
            attachPendant(index: selectedPendantIndex, to: modelEntity, coordinator: context.coordinator)
        }
    }
}

#Preview {
    TestingARPreviewView()
}
