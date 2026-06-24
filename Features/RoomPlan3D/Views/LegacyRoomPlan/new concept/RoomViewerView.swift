//import RealityKit
//import ARKit
//import SwiftUI
//
//struct RoomViewerView: UIViewRepresentable {
//    let fileURL: URL
//    @Binding var resetCameraTrigger: Bool
//
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal, .vertical]
//        config.environmentTexturing = .automatic
//        config.sceneReconstruction = .meshWithClassification
//        arView.session.run(config)
//
//        do {
//            let entity = try Entity.loadModel(contentsOf: fileURL)
//            entity.generateCollisionShapes(recursive: true)
//
//            let modelAnchor = AnchorEntity(world: .zero)
//            modelAnchor.addChild(entity)
//            arView.scene.anchors.append(modelAnchor)
//
//            // Wait for the model to be properly loaded and positioned
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                // Analyze room structure and add ceiling AFTER the model is loaded
//                context.coordinator.analyzeRoomStructure(entity: entity)
//            }
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                arView.session.pause()
//                arView.cameraMode = .nonAR
//
//                let orbitAnchor = AnchorEntity(world: .zero)
//                let camera = PerspectiveCamera()
//
//                let coordinator = context.coordinator
//                coordinator.cameraDistance = 2.0
//                coordinator.yaw = 0
//                coordinator.pitch = 0
//
//                camera.transform.translation = [0, 0, coordinator.cameraDistance]
//                orbitAnchor.addChild(camera)
//
//                arView.scene.anchors.append(orbitAnchor)
//                coordinator.cameraAnchor = orbitAnchor
//                coordinator.originalCameraTransform = orbitAnchor.transform
//                coordinator.updateCameraPosition()
//            }
//        } catch {
//            print("Error loading model: \(error)")
//        }
//
//        // Add gesture recognizers for both camera control and model interaction
//        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
//        arView.addGestureRecognizer(tapGesture)
//
//        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
//        arView.addGestureRecognizer(panGesture)
//
//        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
//        arView.addGestureRecognizer(pinchGesture)
//
//        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
//        longPressGesture.minimumPressDuration = 0.3
//        arView.addGestureRecognizer(longPressGesture)
//
//        context.coordinator.arView = arView
//        context.coordinator.resetTriggerBinding = $resetCameraTrigger
//        return arView
//    }
//
//    func updateUIView(_ uiView: ARView, context: Context) {
//        if resetCameraTrigger {
//            context.coordinator.resetCameraPosition()
//            DispatchQueue.main.async {
//                resetCameraTrigger = false
//            }
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator()
//    }
//
//    class Coordinator: NSObject {
//        weak var arView: ARView?
//        var cameraAnchor: AnchorEntity?
//        var originalCameraTransform: Transform?
//        var resetTriggerBinding: Binding<Bool>?
//        
//        // 3D Model management
//        var placedModels: [Entity] = []
//        var selectedModel: Entity?
//        var isDraggingModel = false
//        var dragOffset: SIMD3<Float> = [0, 0, 0]
//        var lastDragPosition: SIMD3<Float>?
//        
//        // Store pending texture application
//        var pendingTextureEntity: ModelEntity?
//        var pendingMaterialIndex: Int?
//        var pendingMaterialName: String?
//        var pendingMaterialType: String?
//        
//        // Add ceiling detection properties
//        var roomBounds: (min: SIMD3<Float>, max: SIMD3<Float>)? = nil
//        var ceilingEntity: ModelEntity? = nil
//        let ceilingHeight: Float = 0.05// Thickness of ceiling
//        
//        var yaw: Float = 0
//        var pitch: Float = 0
//        var cameraDistance: Float = 2.0
//
//        override init() {
//            super.init()
//            
//            // Listen for notifications
//            NotificationCenter.default.addObserver(
//                self,
//                selector: #selector(handleTextureApplication(_:)),
//                name: NSNotification.Name("ApplySelectedTexture"),
//                object: nil
//            )
//            
//            NotificationCenter.default.addObserver(
//                self,
//                selector: #selector(handleSaveModel(_:)),
//                name: NSNotification.Name("SaveEditedModel"),
//                object: nil
//            )
//        }
//
//        deinit {
//            NotificationCenter.default.removeObserver(self)
//        }
//
//        @objc func handleTextureApplication(_ notification: Notification) {
//            if let userInfo = notification.userInfo,
//               let textureName = userInfo["textureName"] as? String {
//                applySelectedTexture(textureName: textureName)
//            }
//        }
//
//
//        // Add this method to handle save notification with better error handling
//        @objc func handleSaveModel(_ notification: Notification) {
//            if let userInfo = notification.userInfo,
//               let originalURL = userInfo["originalURL"] as? URL {
//                
//                // Get the first anchor (room anchor) from the scene
//                if let roomAnchor = arView?.scene.anchors.first {
//                    print("🎯 Starting save process...")
//                    print("📂 Original file: \(originalURL.lastPathComponent)")
//                    
//                    Task {
//                        await saveEditedModel(entity: roomAnchor, originalURL: originalURL)
//                    }
//                } else {
//                    print("❌ No room anchor found to save")
//                }
//            }
//        }
//
//        @objc func handleTap(_ sender: UITapGestureRecognizer) {
//            // Don't handle taps if we're dragging
//            if isDraggingModel { return }
//            
//            guard let arView = arView else { return }
//            let tapLocation = sender.location(in: arView)
//            let hits = arView.hitTest(tapLocation)
//            
//            if let firstHit = hits.first {
//                print("\n🎯 TAP DETECTED")
//                print("📍 Tap location: \(tapLocation)")
//                
//                if let modelEntity = firstHit.entity as? ModelEntity {
//                    print("📦 Entity name: \(modelEntity.name)")
//                    
//                    // Check if it's a placed 3D model
//                    if isPlacedModel(modelEntity) {
//                        selectModel(modelEntity)
//                        return
//                    }
//                    
//                    // Check for room materials (walls/floors)
//                    identifyAndShowTextureMenu(
//                        entity: modelEntity,
//                        hitResult: firstHit,
//                        tapLocation: tapLocation
//                    )
//                }
//            }
//        }
//
//        @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
//            guard let arView = arView else { return }
//            let location = sender.location(in: arView)
//            
//            switch sender.state {
//            case .began:
//                print("🔥 Long press BEGAN at: \(location)")
//                startModelDragging(at: location, in: arView)
//            case .changed:
//                if isDraggingModel {
//                    print("📱 Long press CHANGED - updating position")
//                    updateModelDragging(to: location, in: arView)
//                }
//            case .ended, .cancelled:
//                if isDraggingModel {
//                    print("✋ Long press ENDED")
//                    endModelDragging()
//                }
//            default:
//                break
//            }
//        }
//
//        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
//            // If we're dragging a model, handle model movement
//            if isDraggingModel {
//                guard let arView = arView else { return }
//                let location = sender.location(in: arView)
//                updateModelDragging(to: location, in: arView)
//                return
//            }
//            
//            // Otherwise handle camera movement
//            guard let arView = arView else { return }
//            let translation = sender.translation(in: arView)
//            sender.setTranslation(.zero, in: arView)
//
//            let sensitivity: Float = 0.005
//            yaw -= Float(translation.x) * sensitivity
//            pitch -= Float(translation.y) * sensitivity
//            pitch = min(max(pitch, -.pi / 4), .pi / 4)
//            updateCameraPosition()
//        }
//
//        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
//            // Don't handle pinch if we're dragging a model
//            if isDraggingModel { return }
//            
//            cameraDistance /= Float(sender.scale)
//            cameraDistance = min(max(cameraDistance, 0.5), 10.0)
//            sender.scale = 1.0
//            updateCameraPosition()
//        }
//
//        // MARK: - Model Dragging Implementation
//        
//        func startModelDragging(at location: CGPoint, in arView: ARView) {
//            print("🎯 Starting model drag detection...")
//            let hits = arView.hitTest(location)
//            
//            print("📊 Hit test results: \(hits.count) hits")
//            for (index, hit) in hits.enumerated() {
//                print("  [\(index)] Entity: \(hit.entity.name), Type: \(type(of: hit.entity))")
//            }
//            
//            // Try to find a placed model in the hit results
//            for hit in hits {
//                if let entity = hit.entity as? ModelEntity {
//                    print("🔍 Checking entity: \(entity.name)")
//                    
//                    // Check if this entity or its parent is a placed model
//                    if let rootModel = findRootModel(from: entity) {
//                        print("✅ Found placed model: \(rootModel.name)")
//                        
//                        isDraggingModel = true
//                        selectedModel = rootModel
//                        setModelSelection(rootModel, selected: true)
//                        
//                        // Store the initial hit position for offset calculation
//                        dragOffset = hit.position
//                        lastDragPosition = rootModel.transform.translation
//                        
//                        print("🔥 Started dragging model: \(rootModel.name)")
//                        print("📍 Initial position: \(rootModel.transform.translation)")
//                        
//                        // Visual feedback
//                        setModelTransparency(rootModel, alpha: 0.7)
//                        return // Exit early once we find a model
//                    }
//                }
//            }
//            
//            print("❌ No draggable model found at tap location")
//        }
//        
//        func updateModelDragging(to location: CGPoint, in arView: ARView) {
//            guard isDraggingModel,
//                  let model = selectedModel else {
//                print("❌ Not dragging or no selected model")
//                return
//            }
//            
//            print("📱 Updating model position...")
//            
//            // Method 1: Try raycast to existing planes
//            let raycastQuery = ARRaycastQuery(
//                origin: arView.cameraTransform.translation,
//                direction: screenPointToWorldDirection(location, in: arView),
//                allowing: ARRaycastQuery.Target.existingPlaneGeometry,
//                alignment: ARRaycastQuery.TargetAlignment.horizontal
//            )
//            
//            let raycastResults = arView.session.raycast(raycastQuery)
//            
//            if let raycastResult = raycastResults.first {
//                let newPosition = raycastResult.worldTransform.translation
//                model.transform.translation = newPosition
//                print("✅ Raycast position: \(newPosition)")
//                return
//            }
//            
//            // Method 2: Project to Y=0 plane (floor level)
//            let worldRay = screenPointToWorldRay(location, in: arView)
//            let rayOrigin = worldRay.origin
//            let rayDirection = worldRay.direction
//            
//            // Calculate intersection with Y=0 plane
//            if rayDirection.y != 0 {
//                let t = -rayOrigin.y / rayDirection.y
//                if t > 0 {
//                    let intersectionPoint = rayOrigin + rayDirection * t
//                    model.transform.translation = [intersectionPoint.x, 0.0, intersectionPoint.z]
//                    print("✅ Plane intersection: \(intersectionPoint)")
//                    return
//                }
//            }
//            
//            // Method 3: Simple screen-space to world conversion (fallback)
//            let normalizedX = Float(location.x / arView.bounds.width) * 2.0 - 1.0
//            let normalizedZ = Float(location.y / arView.bounds.height) * 2.0 - 1.0
//            
//            let newPosition = SIMD3<Float>(normalizedX * 2.0, 0.0, normalizedZ * 2.0)
//            model.transform.translation = newPosition
//            print("⚠️ Fallback position: \(newPosition)")
//        }
//        
//        func endModelDragging() {
//            if isDraggingModel {
//                print("✅ Finished dragging model")
//                print("📍 Final position: \(selectedModel?.transform.translation ?? [0,0,0])")
//                
//                // Restore model transparency
//                if let model = selectedModel {
//                    setModelTransparency(model, alpha: 1.0)
//                }
//                
//                isDraggingModel = false
//                dragOffset = [0, 0, 0]
//                lastDragPosition = nil
//            }
//        }
//        
//        // Helper function to convert screen point to world direction
//        func screenPointToWorldDirection(_ point: CGPoint, in arView: ARView) -> SIMD3<Float> {
//            let normalizedX = Float(point.x / arView.bounds.width) * 2.0 - 1.0
//            let normalizedY = -(Float(point.y / arView.bounds.height) * 2.0 - 1.0)
//            
//            // Get camera transform
//            let cameraTransform = arView.cameraTransform
//            let cameraRotation = cameraTransform.rotation
//            
//            // Create direction vector in camera space
//            let cameraSpaceDirection = SIMD3<Float>(normalizedX, normalizedY, -1.0)
//            
//            // Transform to world space
//            let worldDirection = cameraRotation.act(normalize(cameraSpaceDirection))
//            
//            return worldDirection
//        }
//        
//        // Helper function to create a world ray from screen point
//        func screenPointToWorldRay(_ point: CGPoint, in arView: ARView) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
//            let cameraTransform = arView.cameraTransform
//            let origin = cameraTransform.translation
//            let direction = screenPointToWorldDirection(point, in: arView)
//            
//            return (origin: origin, direction: direction)
//        }
//
//        // MARK: - Helper Functions for Entity Hierarchy
//        
//        func isDescendantOf(_ child: Entity, _ parent: Entity) -> Bool {
//            var currentEntity: Entity? = child
//            while let current = currentEntity {
//                if current == parent {
//                    return true
//                }
//                currentEntity = current.parent
//            }
//            return false
//        }
//
//        // MARK: - 3D Model Management
//        
//        func addModelToScene(_ modelItem: ModelItem) {
//            guard arView != nil else { return }
//            
//            // Create simple test models if USDZ files aren't available
//            let modelEntity: ModelEntity
//            
//            switch modelItem.name {
//            case "TestCube":
//                let mesh = MeshResource.generateBox(size: [0.3, 0.3, 0.3])
//                var material = SimpleMaterial()
//                material.baseColor = .color(.blue)
//                modelEntity = ModelEntity(mesh: mesh, materials: [material])
//                
//            case "TestSphere":
//                let mesh = MeshResource.generateSphere(radius: 0.15)
//                var material = SimpleMaterial()
//                material.baseColor = .color(.red)
//                modelEntity = ModelEntity(mesh: mesh, materials: [material])
//                
//            case "TestCylinder":
//                let mesh = MeshResource.generateCylinder(height: 0.3, radius: 0.1)
//                var material = SimpleMaterial()
//                material.baseColor = .color(.green)
//                modelEntity = ModelEntity(mesh: mesh, materials: [material])
//                
//            default:
//                // Try to load from bundle
//                do {
//                    if let modelURL = Bundle.main.url(forResource: modelItem.name, withExtension: "usdz") {
//                        modelEntity = try Entity.loadModel(contentsOf: modelURL) as! ModelEntity
//                    } else {
//                        print("❌ \(modelItem.fileName) not found, creating default cube")
//                        let mesh = MeshResource.generateBox(size: [0.3, 0.3, 0.3])
//                        var material = SimpleMaterial()
//                        material.baseColor = .color(.gray)
//                        modelEntity = ModelEntity(mesh: mesh, materials: [material])
//                    }
//                } catch {
//                    print("❌ Error loading \(modelItem.displayName): \(error)")
//                    return
//                }
//            }
//            
//            modelEntity.name = "\(modelItem.name)_\(UUID().uuidString.prefix(8))"
//            addModelToSceneCommon(modelEntity, displayName: modelItem.displayName)
//        }
//        
//        func addModelToSceneCommon(_ modelEntity: ModelEntity, displayName: String) {
//            // Scale the model appropriately
//            modelEntity.scale = [0.5, 0.5, 0.5]
//            
//            // Position the model in the center of the room
//            modelEntity.transform.translation = [0.0, 0.0, 0.0]
//            
//            // Generate collision shapes for interaction - THIS IS CRUCIAL
//            modelEntity.generateCollisionShapes(recursive: true)
//            
//            // Add visual selection indicator
//            addSelectionIndicator(to: modelEntity)
//            
//            // Add to the scene
//            if let roomAnchor = arView?.scene.anchors.first {
//                roomAnchor.addChild(modelEntity)
//                placedModels.append(modelEntity)
//                selectModel(modelEntity)
//                
//                print("✅ \(displayName) added to scene")
//                print("🎮 Model details:")
//                print("   • Name: \(modelEntity.name)")
//                print("   • Position: \(modelEntity.transform.translation)")
//                print("   • Scale: \(modelEntity.scale)")
//                print("   • Has collision: \(modelEntity.collision != nil)")
//                print("   • Children count: \(modelEntity.children.count)")
//                print("🎮 Model is now interactive:")
//                print("   • Long press to start dragging")
//                print("   • Drag to move around the room")
//                print("   • Release to place")
//            }
//        }
//        
//        func isPlacedModel(_ entity: Entity) -> Bool {
//            return placedModels.contains { placedModel in
//                return entity == placedModel || isDescendantOf(entity, placedModel)
//            }
//        }
//        
//        func findRootModel(from entity: Entity) -> Entity? {
//            return placedModels.first { placedModel in
//                return entity == placedModel || isDescendantOf(entity, placedModel)
//            }
//        }
//        
//        func selectModel(_ entity: Entity) {
//            // Deselect previous model
//            if let previousModel = selectedModel {
//                setModelSelection(previousModel, selected: false)
//            }
//            
//            // Select new model
//            if let rootModel = findRootModel(from: entity) {
//                selectedModel = rootModel
//                setModelSelection(rootModel, selected: true)
//                print("🎯 Selected model: \(rootModel.name)")
//                print("🎮 Model is ready for interaction:")
//                print("   • Long press and drag to move")
//                print("   • Tap elsewhere to deselect")
//            }
//        }
//        
//        func setModelSelection(_ model: Entity, selected: Bool) {
//            // Find selection indicator and toggle visibility
//            if let indicator = model.children.first(where: { $0.name == "SelectionIndicator" }) {
//                indicator.isEnabled = selected
//            }
//        }
//        
//        func addSelectionIndicator(to model: Entity) {
//            // Create a wireframe box as selection indicator
//            let mesh = MeshResource.generateBox(size: [1.2, 1.2, 1.2])
//            var material = SimpleMaterial()
//            material.baseColor = .color(.yellow.withAlphaComponent(0.3))
//            material.metallic = .float(0.0)
//            material.roughness = .float(1.0)
//            
//            let indicator = ModelEntity(mesh: mesh, materials: [material])
//            indicator.name = "SelectionIndicator"
//            indicator.isEnabled = false // Hidden by default
//            
//            model.addChild(indicator)
//        }
//        
//        func setModelTransparency(_ entity: Entity, alpha: Float) {
//            entity.children.forEach { child in
//                if let modelChild = child as? ModelEntity, child.name != "SelectionIndicator" {
//                    setModelTransparency(modelChild, alpha: alpha)
//                }
//            }
//            
//            if let modelEntity = entity as? ModelEntity,
//               var materials = modelEntity.model?.materials {
//                for i in 0..<materials.count {
//                    if var material = materials[i] as? SimpleMaterial {
//                        let baseColor = material.baseColor
//                        switch baseColor {
//                        case .color(let color):
//                            material.baseColor = .color(color.withAlphaComponent(CGFloat(alpha)))
//                        case .texture(let texture):
//                            material.baseColor = .texture(texture)
//                        default:
//                            break
//                        }
//                        materials[i] = material
//                    }
//                }
//                modelEntity.model?.materials = materials
//            }
//        }
//
//        func updateCameraPosition() {
//            guard let cameraAnchor = cameraAnchor,
//                  let camera = cameraAnchor.children.first as? PerspectiveCamera else { return }
//
//            let x = cameraDistance * cos(pitch) * sin(yaw)
//            let y = cameraDistance * sin(pitch)
//            let z = cameraDistance * cos(pitch) * cos(yaw)
//
//            camera.transform.translation = [x, y, z]
//            camera.look(at: [0, 0, 0], from: [x, y, z], upVector: [0, 1, 0], relativeTo: cameraAnchor)
//        }
//
//        func resetCameraPosition() {
//            yaw = 0
//            pitch = 0
//            cameraDistance = 2.0
//            updateCameraPosition()
//            
//            // Reset all models
//            placedModels.forEach { model in
//                model.removeFromParent()
//            }
//            placedModels.removeAll()
//            selectedModel = nil
//            
//            clearPendingTexture()
//            print("🔄 Reset camera and removed all models")
//        }
//
//        // MARK: - Texture Management
//        
//        func identifyAndShowTextureMenu(entity: ModelEntity, hitResult: CollisionCastHit, tapLocation: CGPoint) {
//            guard let model = entity.model else {
//                print("❌ No model found in entity")
//                return
//            }
//
//            print("🔍 MATERIAL ANALYSIS:")
//            print("📊 Total materials in entity: \(model.materials.count)")
//            
//            for (index, material) in model.materials.enumerated() {
//                let materialName = material.name ?? "Unnamed_\(index)"
//                print("   [\(index)] \(materialName)")
//            }
//            
//            let hitMaterialIndex = identifyHitMaterialIndex(
//                entity: entity,
//                hitResult: hitResult,
//                materials: model.materials
//            )
//            
//            if let materialIndex = hitMaterialIndex {
//                let material = model.materials[materialIndex]
//                let materialName = material.name ?? "Unnamed_\(materialIndex)"
//                
//                print("\n🎯 IDENTIFIED TAPPED MATERIAL:")
//                print("📝 Material name: \(materialName)")
//                print("📍 Material index: \(materialIndex)")
//                
//                if materialName.hasPrefix("Wall") {
//                    showTextureSelectionMenu(
//                        entity: entity,
//                        materialIndex: materialIndex,
//                        materialName: materialName,
//                        materialType: "Wall"
//                    )
//                } else if materialName.hasPrefix("Floor") {
//                    showTextureSelectionMenu(
//                        entity: entity,
//                        materialIndex: materialIndex,
//                        materialName: materialName,
//                        materialType: "Floor"
//                    )
//                } else if entity.name == "Ceiling" {
//                    showTextureSelectionMenu(
//                        entity: entity,
//                        materialIndex: materialIndex,
//                        materialName: "Ceiling",
//                        materialType: "Ceiling"
//                    )
//                }
//            }
//        }
//
//        func showTextureSelectionMenu(entity: ModelEntity, materialIndex: Int, materialName: String, materialType: String) {
//            pendingTextureEntity = entity
//            pendingMaterialIndex = materialIndex
//            pendingMaterialName = materialName
//            pendingMaterialType = materialType
//            
//            print("🎨 Showing texture menu for \(materialType): \(materialName)")
//            
//            NotificationCenter.default.post(
//                name: NSNotification.Name("ShowTextureMenu"),
//                object: nil,
//                userInfo: [
//                    "materialType": materialType,
//                    "materialName": materialName
//                ]
//            )
//        }
//
//        func applySelectedTexture(textureName: String) {
//            guard let entity = pendingTextureEntity,
//                  let materialIndex = pendingMaterialIndex,
//                  let materialName = pendingMaterialName,
//                  let materialType = pendingMaterialType else {
//                print("❌ No pending texture application")
//                return
//            }
//            
//            var newMaterial: SimpleMaterial?
//            
//            switch materialType {
//            case "Wall":
//                newMaterial = createWallMaterial(textureName: textureName)
//            case "Floor":
//                newMaterial = createFloorMaterial(textureName: textureName)
//            case "Ceiling":
//                newMaterial = createCeilingMaterial(textureName: textureName)
//            default:
//                print("❌ Unknown material type: \(materialType)")
//            }
//            
//            guard let texture = newMaterial else {
//                print("❌ Failed to create texture material")
//                return
//            }
//            
//            var updatedMaterials = entity.model?.materials ?? []
//            updatedMaterials[materialIndex] = texture
//            entity.model?.materials = updatedMaterials
//            
//            print("✅ SUCCESS!")
//            print("🎨 \(textureName) texture applied to '\(materialName)'")
//            
//            clearPendingTexture()
//        }
//        
//        func createCeilingMaterial(textureName: String) -> SimpleMaterial? {
//            guard let uiImage = UIImage(named: textureName),
//                  let cgImage = uiImage.cgImage else {
//                print("❌ Could not load \(textureName) image")
//                return nil
//            }
//
//            do {
//                // Fixed: Use .color semantic or nil instead of the type
//                let texture = try TextureResource(image: cgImage, options: TextureResource.CreateOptions(semantic: .color))
//                var material = SimpleMaterial()
//                material.baseColor = .texture(texture)
//                material.metallic = .float(0.0)
//                material.roughness = .float(0.8)
//                return material
//            } catch {
//                print("❌ Ceiling texture generation error: \(error)")
//                return nil
//            }
//        }
//        
//        func clearPendingTexture() {
//            pendingTextureEntity = nil
//            pendingMaterialIndex = nil
//            pendingMaterialName = nil
//            pendingMaterialType = nil
//        }
//
//        func identifyHitMaterialIndex(entity: ModelEntity, hitResult: CollisionCastHit, materials: [RealityKit.Material]) -> Int? {
//            for (index, material) in materials.enumerated() {
//                if let materialName = material.name, materialName.hasPrefix("Wall") {
//                    return index
//                }
//            }
//            
//            for (index, material) in materials.enumerated() {
//                if let materialName = material.name, materialName.hasPrefix("Floor") {
//                    return index
//                }
//            }
//            
//            return nil
//        }
//
//        func createWallMaterial(textureName: String) -> SimpleMaterial? {
//            guard let uiImage = UIImage(named: textureName),
//                  let cgImage = uiImage.cgImage else {
//                print("❌ Could not load \(textureName) image")
//                return nil
//            }
//
//            do {
//                // Fixed: Specify the semantic parameter explicitly
//                let texture = try TextureResource.generate(from: cgImage, options: TextureResource.CreateOptions(semantic: .color))
//                var material = SimpleMaterial()
//                material.baseColor = .texture(texture)
//                material.metallic = .float(0.0)
//                material.roughness = .float(0.7)
//                return material
//            } catch {
//                print("❌ Wall texture generation error: \(error)")
//                return nil
//            }
//        }
//
//        func createFloorMaterial(textureName: String) -> SimpleMaterial? {
//            guard let uiImage = UIImage(named: textureName),
//                  let cgImage = uiImage.cgImage else {
//                print("❌ Could not load \(textureName) image")
//                return nil
//            }
//
//            do {
//                // Fixed: Specify the semantic parameter explicitly
//                let texture = try TextureResource.generate(from: cgImage, options: TextureResource.CreateOptions(semantic: .color))
//                var material = SimpleMaterial()
//                material.baseColor = .texture(texture)
//                material.metallic = .float(0.1)
//                material.roughness = .float(0.8)
//                return material
//            } catch {
//                print("❌ Floor texture generation error: \(error)")
//                return nil
//            }
//        }
//        
//        func analyzeRoomStructure(entity: Entity) {
//            // Reset bounds
//            roomBounds = nil
//            
//            // Reset any existing ceiling
//            ceilingEntity?.removeFromParent()
//            ceilingEntity = nil
//            
//            // Calculate bounds in the entity's local space first
//            var localMin = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
//            var localMax = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
//            
//            calculateLocalBounds(for: entity, min: &localMin, max: &localMax)
//            
//            // Convert to world space using the entity's transform
//            let transform = entity.transformMatrix(relativeTo: nil)
//            let worldMin = transform * SIMD4<Float>(localMin, 1)
//            let worldMax = transform * SIMD4<Float>(localMax, 1)
//            
//            roomBounds = (
//                SIMD3<Float>(worldMin.x, worldMin.y, worldMin.z),
//                SIMD3<Float>(worldMax.x, worldMax.y, worldMax.z)
//            )
//            
//            // Add ceiling if we found valid bounds
//            if let bounds = roomBounds {
//                addCeiling(bounds: bounds)
//            } else {
//                print("⚠️ Could not determine room bounds")
//            }
//        }
//
//        func calculateLocalBounds(for entity: Entity, min: inout SIMD3<Float>, max: inout SIMD3<Float>) {
//            if let modelEntity = entity as? ModelEntity {
//                guard let mesh = modelEntity.model?.mesh else { return }
//                
//                let modelBounds = mesh.bounds
//                min.x = Swift.min(min.x, modelBounds.min.x)
//                min.y = Swift.min(min.y, modelBounds.min.y)
//                min.z = Swift.min(min.z, modelBounds.min.z)
//                
//                max.x = Swift.max(max.x, modelBounds.max.x)
//                max.y = Swift.max(max.y, modelBounds.max.y)
//                max.z = Swift.max(max.z, modelBounds.max.z)
//            }
//            
//            // Recurse through children
//            entity.children.forEach { child in
//                calculateLocalBounds(for: child, min: &min, max: &max)
//            }
//        }
//
//        func addCeiling(bounds: (min: SIMD3<Float>, max: SIMD3<Float>)) {
//            // Calculate ceiling dimensions with slight overlap
//            let width = (bounds.max.x - bounds.min.x) * 1.02  // 2% larger than room
//            let length = (bounds.max.z - bounds.min.z) * 1.02
//            let height = ceilingHeight
//            
//            // Create ceiling mesh
//            let mesh = MeshResource.generateBox(width: width,
//                                              height: height,
//                                              depth: length)
//            
//            // Create ceiling material (white by default)
//            var material = SimpleMaterial()
//            material.baseColor = .color(.themeWhite)
//            material.metallic = .float(0.0)
//            material.roughness = .float(0.7)
//            
//            // Create ceiling entity
//            let ceiling = ModelEntity(mesh: mesh, materials: [material])
//            ceiling.name = "Ceiling"
//            
//            // Position ceiling at top of room with slight offset downward
//            let centerX = bounds.min.x + (bounds.max.x - bounds.min.x) / 2
//            let centerZ = bounds.min.z + (bounds.max.z - bounds.min.z) / 2
//            ceiling.position = SIMD3<Float>(centerX, bounds.max.y - height/2, centerZ)  // Slight offset down
//            
//            // Add collision shape for interaction
//            ceiling.generateCollisionShapes(recursive: true)
//            
//            // Add to scene
//            if let roomAnchor = arView?.scene.anchors.first {
//                roomAnchor.addChild(ceiling)
//                ceilingEntity = ceiling
//                
//                print("✅ Added ceiling to room")
//                print("   - Dimensions: \(width)m x \(length)m x \(height)m")
//                print("   - Position: \(ceiling.position)")
//                print("   - Room bounds min: \(bounds.min), max: \(bounds.max)")
//            }
//        }
//        
//        func saveEditedModel(entity: Entity, originalURL: URL) async {
//            do {
//                // Create new file URL with "_edited" suffix
//                let fileName = originalURL.deletingPathExtension().lastPathComponent
//                let fileExtension = originalURL.pathExtension
//                let editedFileName = "\(fileName)_edited.\(fileExtension)"
//                let editedFileURL = originalURL.deletingLastPathComponent().appendingPathComponent(editedFileName)
//
//                // Create directory if needed
//                let directoryURL = editedFileURL.deletingLastPathComponent()
//                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
//
//                print("📂 Attempting to save model to: \(editedFileURL.path)")
//
//                // Check if file already exists and remove it
//                if FileManager.default.fileExists(atPath: editedFileURL.path) {
//                    try FileManager.default.removeItem(at: editedFileURL)
//                    print("🗑️ Removed existing file at path")
//                }
//
//                // Create new anchor entity to hold all parts
//                let newAnchor = await AnchorEntity(world: .zero)
//
//                // Find the original room model (not the ceiling or placed furniture)
//                var roomEntity: Entity?
//                for child in await  entity.children {
//                    if await child.name != "Ceiling" && !placedModels.contains(child) {
//                        roomEntity = child
//                        break
//                    }
//                }
//
//                if let roomEntity = roomEntity {
//                    // Clone and add the room entity
//                    let clonedRoom = await roomEntity.clone(recursive: true)
//                    await newAnchor.addChild(clonedRoom)
//
//                    // Add ceiling if it exists
//                    if let ceiling = ceilingEntity {
//                        let clonedCeiling = await ceiling.clone(recursive: true)
//                        await newAnchor.addChild(clonedCeiling)
//                    }
//
//                    // Add placed models
//                    for model in placedModels {
//                        let clonedModel = await model.clone(recursive: true)
//                        await newAnchor.addChild(clonedModel)
//                    }
//
//                    // Save the anchor entity to the file
//                    try await newAnchor.write(to: editedFileURL)
//
//                    // Verify file exists and has content
//                    if FileManager.default.fileExists(atPath: editedFileURL.path) {
//                        let fileAttributes = try FileManager.default.attributesOfItem(atPath: editedFileURL.path)
//                        let fileSize = fileAttributes[.size] as? UInt64 ?? 0
//                        let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
//
//                        if fileSize > 1024 {
//                            print("✅ Model saved successfully!")
//                            print("📊 File size: \(String(format: "%.2f", fileSizeMB)) MB")
//                            print("📍 Path: \(editedFileURL.path)")
//
//                            // Test if the saved file can be loaded
//                            do {
//                                _ = try await Entity.loadModel(contentsOf: editedFileURL)
//                                print("✅ Saved file validation successful - can be loaded")
//
//                                DispatchQueue.main.async {
//                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
//                                }
//                            } catch {
//                                print("❌ Saved file validation failed: \(error)")
//                                try? FileManager.default.removeItem(at: editedFileURL)
//                            }
//                        } else {
//                            print("❌ Saved file is too small (likely corrupted)")
//                            try? FileManager.default.removeItem(at: editedFileURL)
//                        }
//                    } else {
//                        print("❌ File was not created after save operation")
//                    }
//
//                } else {
//                    print("❌ Could not find room entity to save")
//                }
//
//            } catch {
//                print("❌ Failed to save model: \(error.localizedDescription)")
//                print("📝 Error details: \(error)")
//
//                if let nsError = error as NSError? {
//                    print("🔍 Error Domain: \(nsError.domain)")
//                    print("🔍 Error Code: \(nsError.code)")
//                    print("🔍 Error User Info: \(nsError.userInfo)")
//                }
//            }
//        }
//
//
//
//
//        // Add this method to validate files before loading
//        func validateAndLoadModel(from url: URL) throws -> Entity {
//            // Check if file exists
//            guard FileManager.default.fileExists(atPath: url.path) else {
//                throw NSError(domain: "FileNotFound", code: 404, userInfo: [
//                    NSLocalizedDescriptionKey: "File does not exist at path: \(url.path)"
//                ])
//            }
//            
//            // Check file size
//            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
//            let fileSize = attributes[.size] as? UInt64 ?? 0
//            
//            if fileSize < 1024 {
//                throw NSError(domain: "FileCorrupted", code: 400, userInfo: [
//                    NSLocalizedDescriptionKey: "File appears to be corrupted (size: \(fileSize) bytes)"
//                ])
//            }
//            
//            // Try to load the model
//            do {
//                let entity = try Entity.loadModel(contentsOf: url)
//                print("✅ Successfully loaded model from: \(url.lastPathComponent)")
//                return entity
//            } catch {
//                print("❌ Failed to load model: \(error)")
//                throw error
//            }
//        }
//
//        private func reloadSavedModelIfNeeded(at url: URL) async {
//            // Only reload if we're in non-AR mode
//            guard let arView = arView, await arView.cameraMode == .nonAR else { return }
//            
//            do {
//                let entity = try await Entity.loadModel(contentsOf: url)
//                await MainActor.run {
//                    entity.generateCollisionShapes(recursive: true)
//                    
//                    // Remove existing anchors except camera
//                    arView.scene.anchors.forEach {
//                        if $0 != self.cameraAnchor {
//                            $0.removeFromParent()
//                        }
//                    }
//                    
//                    let modelAnchor = AnchorEntity(world: .zero)
//                    modelAnchor.addChild(entity)
//                    arView.scene.addAnchor(modelAnchor)
//                    
//                    // Re-analyze room structure
//                    self.analyzeRoomStructure(entity: entity)
//                }
//            } catch {
//                print("Auto-reload failed: \(error)")
//            }
//        }
//    }
//}
//
//// Extension for Transform translation
//extension simd_float4x4 {
//    var translation: SIMD3<Float> {
//        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
//    }
//}
