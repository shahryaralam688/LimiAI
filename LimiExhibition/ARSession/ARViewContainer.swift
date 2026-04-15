import SwiftUI
import RealityKit
import ARKit
import Combine
import Metal
import UIKit

// MARK: - Persistent ARView Holder
final class ARViewHolder: ObservableObject {
    static let shared = ARViewHolder()       // Singleton to persist ARView
    let arView: ARView
    private var lastConfig: ARWorldTrackingConfiguration

    private init() {
        arView = ARView(frame: .zero)
        arView.environment.background = .cameraFeed()

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        self.lastConfig = config

        applyHDRILightingIfAvailable()

        runSession(reset: true)
        print("Persistent AR session started at \(Date())")
    }

    private func applyHDRILightingIfAvailable() {
        // Diagnostic: confirm the file is actually inside the app bundle.
        let exrUrl = Bundle.main.url(forResource: "living-room_2K", withExtension: "exr")
        if exrUrl == nil {
            let exrs = Bundle.main.urls(forResourcesWithExtension: "exr", subdirectory: nil) ?? []
            let hdrs = Bundle.main.urls(forResourcesWithExtension: "hdr", subdirectory: nil) ?? []
            print("⚠️ living-room_2K.exr not found in app bundle. Available .exr=\(exrs.map { $0.lastPathComponent }) .hdr=\(hdrs.map { $0.lastPathComponent })")
        } else {
            print("✅ Found HDRI file in bundle: \(exrUrl!.lastPathComponent)")
        }

        do {
            // RealityKit loads EnvironmentResource by name from the main bundle.
            // The file must be included in the app target (Copy Bundle Resources).
            let env = try EnvironmentResource.load(named: "living-room_2K")
            arView.environment.lighting.resource = env
            arView.environment.lighting.intensityExponent = 0.6
        } catch {
            // Important: RealityKit does NOT load raw .exr/.hdr files via EnvironmentResource.load(named:).
            // It loads a RealityKit EnvironmentResource (typically packaged inside a .reality asset).
            // Since the EXR is present in the bundle but not loadable as an EnvironmentResource,
            // we fall back to ARKit's real-world lighting (environmentTexturing + lightEstimation).
            arView.environment.lighting.resource = nil
            arView.environment.lighting.intensityExponent = 1.0
            print("❌ Failed to load HDRI EnvironmentResource named living-room_2K: \(error)")
            print("ℹ️ living-room_2K.exr is in the bundle, but must be converted to a RealityKit EnvironmentResource (.reality) to be loadable by name. Falling back to ARKit lighting.")
        }
    }

    func runSession(reset: Bool = false) {
        // Ensure camera feed is active before running
        arView.environment.background = .cameraFeed()
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(lastConfig, options: options)
        // Simple log to help diagnose lifecycle issues
        print("AR session run called. reset=\(reset) @ \(Date())")
    }

    // Enable LiDAR scene mesh occlusion (and people occlusion where supported)
    func enableSceneOcclusion() {
        // RealityKit occlusion from reconstructed scene mesh
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)

        // Human/hand occlusion using person segmentation with depth (if available)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            lastConfig.frameSemantics.insert(.personSegmentationWithDepth)
            // Re-run to apply semantics without resetting tracking/anchors
            arView.session.run(lastConfig, options: [])
        }
    }
}

// MARK: - ARContainerWithOverlay Helpers
private extension ARContainerWithOverlay {
    func instructionTextForCard() -> String {
        let desc = card.description.lowercased()
        if desc.contains("ceil") { return "Point the camera towards the ceiling" }
        if desc.contains("fooler") || desc.contains("floor") { return "Point the camera towards the floor" }
        return "Point the camera towards the wall"
    }

    func surfaceTypeForCard() -> ARSurfaceGuideType {
        let desc = card.description.lowercased()
        if desc.contains("ceil") { return .ceiling }
        if desc.contains("fooler") || desc.contains("floor") { return .floor }
        return .wall
    }
}

// MARK: - ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    var card: Card
    @Binding var showInstructions: Bool
    @Binding var showPlacementIndicator: Bool
    @Binding var hasPlacedModel: Bool
    @ObservedObject private var holder = ARViewHolder.shared

    // MARK: - Coordinator
    class Coordinator: NSObject, ARSessionDelegate {
        let parent: ARViewContainer
        var updateSubscription: Cancellable?
        weak var tapGesture: UITapGestureRecognizer?
        var previewAnchor: AnchorEntity?
        var previewEntity: Entity?
        var modelEntity: Entity?
        var lastValidTransform: float4x4?
        // Occlusion state mapped by ARAnchor identifier
        var occlusionAnchors: [UUID: AnchorEntity] = [:]
        // Light estimation & ambience
        weak var placedModel: ModelEntity?
        var ambientIntensity: CGFloat = 1000.0
        var ambientColorTemperature: CGFloat = 6500.0
        var smoothedAmbientIntensity: CGFloat = 1000.0
        var cameraLightAnchor: AnchorEntity?
        var directionalLightEntity: Entity?
        var smoothedDirectionalIntensity: Float = 1500.0
        let lightSmoothing: Float = 0.35

        // NEW: shadow receiver under placed model
        var shadowPlane: ModelEntity?
        private var shadowBlobTexture: TextureResource?
        weak var shadowTarget: Entity?

        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
        }

        private func firstModelEntity(in root: Entity) -> ModelEntity? {
            if let m = root as? ModelEntity { return m }
            for child in root.children {
                if let found = firstModelEntity(in: child) { return found }
            }
            return nil
        }

        private func makeShadowBlobTextureIfNeeded() -> TextureResource? {
            if let existing = shadowBlobTexture {
                return existing
            }

            let size: CGFloat = 256
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let image = renderer.image { ctx in
                let center = CGPoint(x: size / 2.0, y: size / 2.0)
                let colors = [
                    UIColor.appBlack.withAlphaComponent(0.45).cgColor,
                    UIColor.appBlack.withAlphaComponent(0.0).cgColor
                ] as CFArray
                let locations: [CGFloat] = [0.0, 1.0]
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size / 2.0,
                    options: [.drawsAfterEndLocation]
                )
            }

            guard let cgImage = image.cgImage else { return nil }
            do {
                let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
                shadowBlobTexture = texture
                return texture
            } catch {
                print("❌ Failed to generate shadow blob texture: \(error)")
                return nil
            }
        }

        // Determine placement target based on card.description
        private enum PlacementTarget {
            case ceiling
            case floor
            case wall
        }

        private func placementTarget() -> PlacementTarget {
            let desc = parent.card.description.lowercased()
            if desc.contains("ceil") { return .ceiling }
            if desc.contains("fooler") || desc.contains("floor") { return .floor }
            return .wall
        }

        // Convert ARMeshGeometry -> MeshResource for RealityKit occlusion
        private func meshResource(from geometry: ARMeshGeometry) -> MeshResource? {
            var descriptor = MeshDescriptor(name: "OcclusionMesh")

            // Positions
            let vertexCount = geometry.vertices.count
            var positions: [SIMD3<Float>] = []
            positions.reserveCapacity(vertexCount)
            let vb = geometry.vertices.buffer
            let vStride = geometry.vertices.stride
            let vPtr = vb.contents()
            for i in 0..<vertexCount {
                let base = vPtr.advanced(by: i * vStride)
                let p = base.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                positions.append(p)
            }
            descriptor.positions = MeshBuffer(positions)

            // Indices (triangles)
            let faces = geometry.faces
            let indexCount = faces.count / faces.bytesPerIndex  // Total number of indices
            let indicesPerPrimitive = 3  // Assuming triangles for occlusion
            let triCount = indexCount / indicesPerPrimitive
            _ = triCount
            var indices: [UInt32] = []
            indices.reserveCapacity(indexCount)
            let ib = faces.buffer
            let iPtr = ib.contents() // ARGeometryElement doesn't expose an offset; data begins at start
            switch faces.bytesPerIndex {
            case 2:
                let typed = iPtr.bindMemory(to: UInt16.self, capacity: indexCount)
                for i in 0..<indexCount { indices.append(UInt32(typed[i])) }
            case 4:
                let typed = iPtr.bindMemory(to: UInt32.self, capacity: indexCount)
                for i in 0..<indexCount { indices.append(typed[i]) }
            default:
                return nil
            }
            descriptor.primitives = .triangles(indices)

            do {
                return try MeshResource.generate(from: [descriptor])
            } catch {
                print("❌ MeshResource generation failed: \(error)")
                return nil
            }
        }

        // Create or update occlusion entity for a given ARMeshAnchor
        func upsertOcclusion(for meshAnchor: ARMeshAnchor, in arView: ARView) {
            guard let mesh = meshResource(from: meshAnchor.geometry) else { return }
            let model = ModelEntity(mesh: mesh, materials: [OcclusionMaterial()])
            model.name = "Occlusion_\(meshAnchor.identifier)"

            if let anchorEntity = occlusionAnchors[meshAnchor.identifier] {
                anchorEntity.transform.matrix = meshAnchor.transform
                anchorEntity.children.removeAll()
                anchorEntity.addChild(model)
            } else {
                let anchorEntity = AnchorEntity(world: meshAnchor.transform)
                anchorEntity.addChild(model)
                arView.scene.addAnchor(anchorEntity)
                occlusionAnchors[meshAnchor.identifier] = anchorEntity
            }
        }

        private func removeOcclusion(for anchorId: UUID, from arView: ARView) {
            if let anchorEntity = occlusionAnchors.removeValue(forKey: anchorId) {
                arView.scene.removeAnchor(anchorEntity)
            }
        }

        func loadModelIfNeeded(for card: Card) {
            guard modelEntity == nil else { return }

            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator")
            let modelURL = configuratorFolderURL.appendingPathComponent("\(card.objectName).usdz")

            // Prefer downloaded model from Documents/Configurator; if not present, fall back to bundled asset
            let finalURL: URL?
            if fileManager.fileExists(atPath: modelURL.path) {
                finalURL = modelURL
            } else {
                finalURL = Bundle.main.url(forResource: card.objectName,
                                           withExtension: "usdz",
                                           subdirectory: "art.scnassets")
            }

            guard let resolvedURL = finalURL else {
                print("❌ Model not found for objectName: \(card.objectName)")
                return
            }
            do {
                // Load USDZ as a generic Entity
                let loaded = try Entity.load(contentsOf: resolvedURL)

                // Wrap it in a ModelEntity container which conforms to HasCollision
                let container = ModelEntity()
                container.name = "ModelContainer_\(card.objectName)"
                container.addChild(loaded)

                // Visual up-scale so the model appears larger in AR (scale the container)
                let visualScale: Float = 2.0
                container.transform.scale = SIMD3<Float>(repeating: visualScale)
                self.modelEntity = container
                print("✅ Loaded model for placement (wrapped in container): \(card.objectName)")
                print("   ▶️ Initial container scale: \(container.transform.scale)")

                let bounds = container.visualBounds(relativeTo: nil)
                let baseSize = bounds.extents
                let scale = container.transform.scale
                let finalSize = SIMD3<Float>(
                    baseSize.x * scale.x,
                    baseSize.y * scale.y,
                    baseSize.z * scale.z
                )
                print("📏 Base model size (m) [W,H,D]: \(baseSize)")
                print("📏 Final model size with scale (m) [W,H,D]: \(finalSize)")

                applyReflectiveAdjustments(to: container)
            } catch {
                print("❌ Failed to load USDZ: \(error.localizedDescription)")
            }
        }

        private func applyReflectiveAdjustments(to root: Entity) {
            let shinyChildren = root.children.compactMap { $0 as? ModelEntity }
            guard !shinyChildren.isEmpty else { return }

            for model in shinyChildren {
                guard var component = model.model else { continue }
                component.materials = component.materials.map { material in
                    var mat = material
                    if var pbr = mat as? PhysicallyBasedMaterial {
                        // Keep existing metallic/roughness; only ensure they are not fully matte
                        mat = pbr
                    }
                    return mat
                }
                model.model = component
            }
        }

        func startRaycasting() {
            guard updateSubscription == nil else { return }
            let arView = ARViewHolder.shared.arView
            // Subscribe to per-frame updates to drive the placement preview
            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                self?.updatePlacementPreview()
            }
        }

        func stopRaycasting() {
            updateSubscription?.cancel()
            updateSubscription = nil
        }

        private func ensurePreviewSetup(in arView: ARView) {
            if previewAnchor == nil {
                previewAnchor = AnchorEntity(world: matrix_identity_float4x4)
                if let anchor = previewAnchor {
                    arView.scene.addAnchor(anchor)
                }
            }
            if previewEntity == nil {
                // Create transparent border-only square and circle (matching reference image)
                
                // Transparent alabaster material for borders only
                var borderMaterial = UnlitMaterial()
                borderMaterial.color = .init(tint: UIColor(named: "alabaster")?.withAlphaComponent(0.7) ?? .appWhite)

                // Square border - 4 thin lines forming outline
                let lineThickness: Float = 0.004
                let squareSize: Float = 0.3
                
                let topLine = ModelEntity(
                    mesh: MeshResource.generateBox(width: squareSize, height: lineThickness, depth: lineThickness),
                    materials: [borderMaterial]
                )
                let bottomLine = ModelEntity(
                    mesh: MeshResource.generateBox(width: squareSize, height: lineThickness, depth: lineThickness),
                    materials: [borderMaterial]
                )
                let leftLine = ModelEntity(
                    mesh: MeshResource.generateBox(width: lineThickness, height: lineThickness, depth: squareSize),
                    materials: [borderMaterial]
                )
                let rightLine = ModelEntity(
                    mesh: MeshResource.generateBox(width: lineThickness, height: lineThickness, depth: squareSize),
                    materials: [borderMaterial]
                )
                
                // Position square border lines
                let halfSize = squareSize / 2
                topLine.transform.translation = SIMD3<Float>(0, 0, halfSize)
                bottomLine.transform.translation = SIMD3<Float>(0, 0, -halfSize)
                leftLine.transform.translation = SIMD3<Float>(-halfSize, 0, 0)
                rightLine.transform.translation = SIMD3<Float>(halfSize, 0, 0)
                
                // Circle border - create using small segments for smooth outline
                let circleContainer = Entity()
                let circleRadius: Float = 0.095
                let segmentCount = 24
                
                for i in 0..<segmentCount {
                    let angle = Float(i) * (2 * Float.pi / Float(segmentCount))
                    _ = Float(i + 1) * (2 * Float.pi / Float(segmentCount))
                    
                    let segmentLength: Float = 2 * circleRadius * sin(Float.pi / Float(segmentCount))
                    let segment = ModelEntity(
                        mesh: MeshResource.generateBox(width: segmentLength, height: lineThickness, depth: lineThickness),
                        materials: [borderMaterial]
                    )
                    
                    segment.transform.translation = SIMD3<Float>(
                        cos(angle) * circleRadius,
                        0.001,
                        sin(angle) * circleRadius
                    )
                    segment.transform.rotation = simd_quatf(angle: angle + Float.pi/2, axis: SIMD3<Float>(0, 1, 0))
                    
                    circleContainer.addChild(segment)
                }
                
                // Center dot
                let centerDot = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: 0.006),
                    materials: [borderMaterial]
                )
                centerDot.transform.translation.y = 0.002
                
                let containerEntity = Entity()
                containerEntity.addChild(topLine)
                containerEntity.addChild(bottomLine)
                containerEntity.addChild(leftLine)
                containerEntity.addChild(rightLine)
                containerEntity.addChild(circleContainer)
                containerEntity.addChild(centerDot)
                containerEntity.name = "PlacementIndicator"
                
                // Animate the circle with subtle pulsing
                DispatchQueue.main.async {
                    var isScaledUp = false
                    Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                        let targetScale: SIMD3<Float> = isScaledUp ? SIMD3<Float>(1.0, 1.0, 1.0) : SIMD3<Float>(1.15, 1.0, 1.15)
                        let targetTransform = Transform(
                            scale: targetScale,
                            rotation: circleContainer.transform.rotation,
                            translation: circleContainer.transform.translation
                        )
                        circleContainer.move(to: targetTransform, relativeTo: circleContainer.parent, duration: 0.6)
                        isScaledUp.toggle()
                    }
                }
                
                previewEntity = containerEntity
                previewEntity?.isEnabled = false
                previewAnchor?.addChild(containerEntity)
            }
        }

        private func updatePlacementPreview() {
            let arView = ARViewHolder.shared.arView
            ensurePreviewSetup(in: arView)

            // 1) Optional camera orientation guidance depending on target
            let target = placementTarget()
            if let frame = arView.session.currentFrame {
                let m = frame.camera.transform
                // Camera forward is -Z of the transform
                let forward = simd_normalize(SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z))
                // Dot with world up (0,1,0): 1 = straight up, -1 = straight down
                let dotUp = simd_dot(forward, SIMD3<Float>(0, 1, 0))
                let lookingUp = dotUp > 0.35
                let lookingDown = dotUp < -0.35

                switch target {
                case .ceiling:
                    if !lookingUp {
                        previewEntity?.isEnabled = false
                        lastValidTransform = nil
                        DispatchQueue.main.async {
                            self.parent.showPlacementIndicator = false
                            self.parent.showInstructions = true
                        }
                        return
                    }
                case .floor:
                    if !lookingDown {
                        previewEntity?.isEnabled = false
                        lastValidTransform = nil
                        DispatchQueue.main.async {
                            self.parent.showPlacementIndicator = false
                            self.parent.showInstructions = true
                        }
                        return
                    }
                case .wall:
                    // No strict orientation gate for walls; proceed to raycast
                    break
                }
            }

            // Center point of the screen
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            // Raycast against existing plane geometry, choose alignment based on target
            let alignment: ARRaycastQuery.TargetAlignment = {
                switch placementTarget() {
                case .wall: return .vertical
                case .ceiling, .floor: return .horizontal
                }
            }()
            let results = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: alignment)

            guard let first = results.first else {
                previewEntity?.isEnabled = false
                lastValidTransform = nil
                DispatchQueue.main.async {
                    self.parent.showPlacementIndicator = false
                    // Keep instructions hidden here (we are looking up) but no ceiling hit yet
                }
                return
            }

            // Allow only the requested classification when available
            var isValidHit = true
            if let planeAnchor = first.anchor as? ARPlaneAnchor {
                if #available(iOS 13.0, *), ARPlaneAnchor.isClassificationSupported {
                    switch placementTarget() {
                    case .ceiling:
                        isValidHit = (planeAnchor.classification == .ceiling)
                    case .floor:
                        isValidHit = (planeAnchor.classification == .floor)
                    case .wall:
                        isValidHit = (planeAnchor.classification == .wall)
                    }
                }
            }

            if !isValidHit {
                previewEntity?.isEnabled = false
                lastValidTransform = nil
                DispatchQueue.main.async {
                    self.parent.showPlacementIndicator = false
                }
                return
            }

            // Show preview at the hit transform
            let transform = first.worldTransform
            previewEntity?.isEnabled = true
            previewAnchor?.transform.matrix = transform
            lastValidTransform = transform
            
            // Hide instructions and show placement indicator
            DispatchQueue.main.async {
                self.parent.showInstructions = false
                self.parent.showPlacementIndicator = true
            }
        }

        // MARK: - Shadow plane creator
        // MARK: - Shadow plane creator
        private func addOrUpdateShadowPlane(parentAnchor: AnchorEntity, for entity: Entity) {
            let bounds = entity.visualBounds(relativeTo: nil)
            let radius = max(bounds.extents.x, bounds.extents.z) * 0.6
            let planeSize: Float = max(0.15, radius)

            let shadowMesh = MeshResource.generatePlane(width: planeSize, depth: planeSize)

            let baseAlpha: CGFloat = 0.85
            let surfaceLift: Float = 0.025
            let shadowMaterial: RealityKit.Material = {
                if let tex = makeShadowBlobTextureIfNeeded() {
                    var unlit = UnlitMaterial()
                    unlit.color = .init(tint: UIColor.appBlack.withAlphaComponent(baseAlpha), texture: .init(tex))
                    return unlit
                } else {
                    let baseColor = UIColor.appBlack.withAlphaComponent(0.35)
                    var simple = SimpleMaterial(color: .appBlack, isMetallic: false)
                    simple.roughness = 1.0
                    simple.color = .init(tint: baseColor)
                    return simple
                }
            }()

            let planeEntity: ModelEntity
            if let existing = shadowPlane {
                planeEntity = existing
            } else {
                planeEntity = ModelEntity()
                planeEntity.name = "ShadowPlane"
                shadowPlane = planeEntity
                parentAnchor.addChild(planeEntity)
                print("✅ ShadowPlane created")
            }

            planeEntity.model = ModelComponent(mesh: shadowMesh, materials: [shadowMaterial])

            // Place slightly below the model
            var t = entity.transform
            t.translation.y -= 0.001
            planeEntity.transform = t

            // Align plane orientation to surface
            switch placementTarget() {
            case .floor:
                planeEntity.orientation = simd_quatf(angle: 0, axis: [1,0,0])
            case .ceiling:
                planeEntity.orientation = simd_quatf(angle: .pi, axis: [1,0,0])
            case .wall:
                planeEntity.orientation = simd_quatf(angle: -.pi/2, axis: [1,0,0])
            }

            // With scene occlusion enabled, content exactly on the surface can get occluded.
            // Push the shadow plane slightly in front of the surface along its normal.
            let normal = planeEntity.orientation.act(SIMD3<Float>(0, 1, 0))
            planeEntity.position += normal * surfaceLift
        }


        // MARK: - Tap to Place + Enable Move/Rotate/Scale
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            let arView = ARViewHolder.shared.arView
            guard recognizer.state == .ended,
                  let placeTransform = lastValidTransform,
                  let entity = modelEntity else {
                return
            }

            print("🟢 handleTap fired")

            // Place a clone of the loaded model at the preview location
            let anchor = AnchorEntity(world: placeTransform)
            let clone = entity.clone(recursive: true)

            print("🟢 clone created: \(type(of: clone)) children=\(clone.children.count)")

            // 👉 Make the placed clone interactive:
            // 1) Generate collision so gestures can "hit" the entity
            clone.generateCollisionShapes(recursive: true)
            // 2) Install built-in gestures to move/rotate/scale the model on the container
            if let collidableClone = clone as? HasCollision {
                arView.installGestures([.translation, .rotation, .scale], for: collidableClone)
            } else {
                print("⚠️ Placed clone does not conform to HasCollision even with container; gestures not installed.")
            }

            anchor.addChild(clone)
            arView.scene.addAnchor(anchor)

            shadowTarget = clone

            placedModel = firstModelEntity(in: clone)
            if placedModel == nil {
                print("⚠️ No ModelEntity found in placed clone; creating shadow based on Entity bounds")
            }

            addOrUpdateShadowPlane(parentAnchor: anchor, for: clone)
            print("🟢 shadow plane update called")

            updateModelAmbience()

            print("📐 Placed model scale: \(clone.transform.scale)")

            DispatchQueue.main.async {
                self.parent.showInstructions = false
                self.parent.showPlacementIndicator = false
                self.parent.hasPlacedModel = true
            }

            switch placementTarget() {
            case .ceiling:
                print("📌 Placed model on ceiling at preview location")
            case .floor:
                print("📌 Placed model on floor at preview location")
            case .wall:
                print("📌 Placed model on wall at preview location")
            }
        }

        // MARK: - ARSessionDelegate (LiDAR mesh -> occlusion)
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            let arView = ARViewHolder.shared.arView
            anchors.compactMap { $0 as? ARMeshAnchor }.forEach { upsertOcclusion(for: $0, in: arView) }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            let arView = ARViewHolder.shared.arView
            anchors.compactMap { $0 as? ARMeshAnchor }.forEach { upsertOcclusion(for: $0, in: arView) }
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            let arView = ARViewHolder.shared.arView
            anchors.forEach { anchor in
                if let mesh = anchor as? ARMeshAnchor { removeOcclusion(for: mesh.identifier, from: arView) }
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if let lightEstimate = frame.lightEstimate {
                print("💡 AR LightEstimate - ambientIntensity=\(lightEstimate.ambientIntensity), colorTemp=\(lightEstimate.ambientColorTemperature)")
                updateAmbient(from: lightEstimate)
            }

            if let directional = frame.lightEstimate as? ARDirectionalLightEstimate {
                updateDirectionalLight(with: directional, cameraTransform: frame.camera.transform)
                updateShadowPlane(with: directional)
            } else {
                // Fallback: still update shadow strength based on ambient only
                updateShadowPlane(with: nil)
            }
        }

        private func updateAmbient(from lightEstimate: ARLightEstimate) {
            let rawAmbient = Float(lightEstimate.ambientIntensity)
            let smoothed = lerp(Float(smoothedAmbientIntensity), rawAmbient, lightSmoothing)

            smoothedAmbientIntensity = CGFloat(smoothed)
            ambientIntensity = smoothedAmbientIntensity
            ambientColorTemperature = lightEstimate.ambientColorTemperature

            DispatchQueue.main.async {
                self.updateModelAmbience()
            }
        }

        func updateModelAmbience() {
            guard let model = placedModel else { return }

            // Strong mapping from real brightness → visual brightness
            let normalized = max(0.1, min(ambientIntensity / 1000.0, 4.0))
            let brightnessScale = Float(normalized)

            // Strong warm/cool mapping
            let clampedTemp = max(2500.0, min(ambientColorTemperature, 9000.0))
            let t = Float((clampedTemp - 2500.0) / (9000.0 - 2500.0))

            let warmColor = SIMD3<Float>(1.0, 0.78, 0.55)
            let coolColor = SIMD3<Float>(0.7, 0.9, 1.0)
            let mixedColor = warmColor * (1.0 - t) + coolColor * t

            let tintColor = UIColor(
                red: CGFloat(mixedColor.x),
                green: CGFloat(mixedColor.y),
                blue: CGFloat(mixedColor.z),
                alpha: 1.0
            )

            guard let modelComponent = model.model else { return }

            let updatedMaterials: [RealityKit.Material] = modelComponent.materials.map { material in
                var mat = material

                if var pbr = mat as? PhysicallyBasedMaterial {
                    let originalTint = pbr.baseColor.tint
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    if originalTint.getRed(&r, green: &g, blue: &b, alpha: &a) {
                        let factor = CGFloat(min(3.0, max(0.2, brightnessScale)))
                        let newBase = UIColor(
                            red: min(1.0, r * factor),
                            green: min(1.0, g * factor),
                            blue: min(1.0, b * factor),
                            alpha: a
                        )
                        pbr.baseColor = .init(tint: newBase)
                    }

                    let emissiveBoost = max(0.0, brightnessScale - 0.5) * 3.0
                    let emissiveAlpha = CGFloat(min(1.0, emissiveBoost))
                    let emissiveUIColor = tintColor.withAlphaComponent(emissiveAlpha)
                    pbr.emissiveColor = .init(color: emissiveUIColor)

                    mat = pbr
                } else if var simple = mat as? SimpleMaterial {
                    let factor = CGFloat(min(3.0, max(0.2, brightnessScale)))
                    simple.color = .init(tint: tintColor.withAlphaComponent(factor))
                    mat = simple
                }

                return mat
            }

            model.model?.materials = updatedMaterials
        }

        // NEW: update shadow plane opacity/shape based on light
        private func updateShadowPlane(with estimate: ARDirectionalLightEstimate?) {
            guard let shadowPlane = shadowPlane else { return }

            if let target = shadowTarget {
                let surfaceLift: Float = 0.025
                var t = target.transform
                t.translation.y -= 0.001
                shadowPlane.transform = t

                switch placementTarget() {
                case .floor:
                    shadowPlane.orientation = simd_quatf(angle: 0, axis: [1,0,0])
                case .ceiling:
                    shadowPlane.orientation = simd_quatf(angle: .pi, axis: [1,0,0])
                case .wall:
                    shadowPlane.orientation = simd_quatf(angle: -.pi/2, axis: [1,0,0])
                }

                let normal = shadowPlane.orientation.act(SIMD3<Float>(0, 1, 0))
                shadowPlane.position += normal * surfaceLift
            }

            // Base opacity from ambient intensity
            let ambient = Float(ambientIntensity)
            let normalized = max(0.2, min(ambient / 1000.0, 2.5))
            let baseAlpha = CGFloat(min(0.85, max(0.35, 0.35 * normalized)))

            // Update material alpha
            if var modelComponent = shadowPlane.model {
                modelComponent.materials = modelComponent.materials.map { mat in
                    var m = mat
                    if var unlit = m as? UnlitMaterial {
                        let tint = unlit.color.tint
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        if tint.getRed(&r, green: &g, blue: &b, alpha: &a) {
                            unlit.color.tint = UIColor(red: r, green: g, blue: b, alpha: baseAlpha)
                        }
                        m = unlit
                    } else if var simple = m as? SimpleMaterial {
                        let current = simple.color.tint
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        if current.getRed(&r, green: &g, blue: &b, alpha: &a) {
                            let newColor = UIColor(red: r, green: g, blue: b, alpha: baseAlpha)
                            simple.color = .init(tint: newColor)
                        }
                        m = simple
                    }
                    return m
                }
                shadowPlane.model = modelComponent
            }

            // Offset & scale shadow along opposite of light direction
            var offset = SIMD3<Float>(0, 0, 0)
            var scale = SIMD3<Float>(repeating: 1.0)

            if let est = estimate {
                let dir = est.primaryLightDirection
                let shadowDir = SIMD3<Float>(-dir.x, 0, -dir.z)

                offset.x += shadowDir.x * 0.05
                offset.z += shadowDir.z * 0.05

                let strength = max(0.5, min(Float(est.primaryLightIntensity) / 1000.0, 2.0))
                scale = SIMD3<Float>(
                    1.0 + strength * 0.4,
                    1.0,
                    1.0 + strength * 0.8
                )
            }

            var t = shadowPlane.transform
            t.translation = t.translation + offset
            t.scale = scale
            shadowPlane.transform = t
        }

        func ensureLightAnchor(in arView: ARView) {
            guard cameraLightAnchor == nil else { return }

            let anchor = AnchorEntity(.camera)
            let lightEntity = Entity()

            var light = DirectionalLightComponent()
            light.intensity = smoothedDirectionalIntensity
            light.color = .appWhite

            lightEntity.components.set(light)

            anchor.addChild(lightEntity)
            arView.scene.addAnchor(anchor)

            cameraLightAnchor = anchor
            directionalLightEntity = lightEntity
        }

        private func updateDirectionalLight(with estimate: ARDirectionalLightEstimate,
                                            cameraTransform: simd_float4x4) {
            guard
                let lightEntity = directionalLightEntity,
                var light = lightEntity.components[DirectionalLightComponent.self]
            else { return }

            let rawIntensity = Float(estimate.primaryLightIntensity) * 2.0
            smoothedDirectionalIntensity = lerp(smoothedDirectionalIntensity, rawIntensity, lightSmoothing)
            light.intensity = smoothedDirectionalIntensity

            lightEntity.components.set(light)

            let anchorMatrix = cameraLightAnchor?.transform.matrix ?? cameraTransform
            let dirWorld = estimate.primaryLightDirection
            let inv = anchorMatrix.inverse
            let worldDir4 = SIMD4<Float>(dirWorld.x, dirWorld.y, dirWorld.z, 0)
            let localDir4 = inv * worldDir4
            let dirLocal = normalize(SIMD3<Float>(localDir4.x, localDir4.y, localDir4.z))
            let rotation = orientationFrom(direction: dirLocal)
            lightEntity.transform.rotation = rotation
        }

        private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
            return a + (b - a) * t
        }

        private func colorFromTemperature(_ kelvin: CGFloat) -> UIColor {
            let temp = kelvin / 100
            let red: CGFloat
            let green: CGFloat
            let blue: CGFloat

            if temp <= 66 {
                red = 1.0
                green = max(0.0, min(1.0, 0.39008157876901960784 * log(temp) - 0.63184144378862745098))
            } else {
                red = max(0.0, min(1.0, 1.29293618606274509804 * pow(temp - 60, -0.1332047592)))
                green = max(0.0, min(1.0, 1.12989086089529411765 * pow(temp - 60, -0.0755148492)))
            }

            if temp >= 66 {
                blue = 1.0
            } else if temp <= 19 {
                blue = 0.0
            } else {
                blue = max(0.0, min(1.0, 0.54320678911019607843 * log(temp - 10) - 1.19625408914))
            }

            return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        }

        private func orientationFrom(direction: SIMD3<Float>) -> simd_quatf {
            let forward = normalize(direction)
            let up = SIMD3<Float>(0, 1, 0)
            let right = normalize(cross(up, forward))
            let correctedUp = cross(forward, right)
            let matrix = float3x3(columns: (right, correctedUp, forward * -1))
            return simd_quatf(matrix)
        }
    }

    func makeUIView(context: Context) -> ARView {
        // Ensure session is running when the view is created
        holder.runSession(reset: false)
        let arView = holder.arView
        // Activate real-world occlusion
        holder.enableSceneOcclusion()
        // Receive ARMeshAnchor updates
        arView.session.delegate = context.coordinator
        context.coordinator.ensureLightAnchor(in: arView)
        // Build occlusion for any pre-existing mesh anchors
        if let anchors = arView.session.currentFrame?.anchors {
            anchors.compactMap { $0 as? ARMeshAnchor }.forEach { context.coordinator.upsertOcclusion(for: $0, in: arView) }
        }
        // Install tap gesture once
        if context.coordinator.tapGesture == nil {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            arView.addGestureRecognizer(tap)
            context.coordinator.tapGesture = tap
        }
        context.coordinator.loadModelIfNeeded(for: card)
        context.coordinator.startRaycasting()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Ensure model is loaded; placement happens via preview + tap
        context.coordinator.loadModelIfNeeded(for: card)
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        // Do not pause the singleton session here; leaving it running avoids losing camera feed on next appear
        print("ARViewContainer dismantle called (session left running)")
        uiView.removeFromSuperview()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

// MARK: - AR Instruction Overlay
struct ARInstructionOverlay: View {
    let showInstructions: Bool
    let showPlacementIndicator: Bool
    let instructionText: String
    let surfaceType: ARSurfaceGuideType
    @State private var phoneOffsetUp: Bool = false
    
    var body: some View {
        ZStack {
            if showInstructions {
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack() {

                        ARSurfaceGuideView(type: surfaceType)
                            .frame(height: 150)

                        Text(instructionText)
                            .font(.headline)
                            .foregroundColor(.themeWhite)
                            .multilineTextAlignment(.center)
                            .padding(.top)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 30)
                    .onAppear {
                        // Kick off the vertical animation loop
                        phoneOffsetUp.toggle()
                    }

                    Spacer()
                }
            }
            
            if showPlacementIndicator {
                VStack {
                    Text("Tap")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.themeWhite)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.themeBlack.opacity(0.7))
                        )
                        .padding(.top, 100)
                    
                    Spacer()
                }
            }
            
        }
    }
}

// MARK: - AR Container with Overlay
struct ARContainerWithOverlay: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var stateManager = ARModelStateManager.shared
    
    let card: Card
    @State private var currentCard: Card
    @State private var showInstructions = true
    @State private var showPlacementIndicator = false
    @State private var showPortal = false
    @State private var hasPlacedModel = false
    
    // Simple local switch: true = AR camera, false = Object (QuickLook)
    @State private var isARMode: Bool = true
    
    init(card: Card) {
        self.card = card
        self._currentCard = State(initialValue: card)
    }
    
    var body: some View {
        ZStack {
            if isARMode {
                ARViewContainer(
                    card: currentCard,
                    showInstructions: $showInstructions,
                    showPlacementIndicator: $showPlacementIndicator,
                    hasPlacedModel: $hasPlacedModel
                )
                .id(currentCard.objectName)
                .ignoresSafeArea()
                
                if !hasPlacedModel {
                    ARInstructionOverlay(
                        showInstructions: showInstructions,
                        showPlacementIndicator: showPlacementIndicator,
                        instructionText: instructionTextForCard(),
                        surfaceType: surfaceTypeForCard()
                    )
                }
            } else {
                // Non-AR 3D viewer without camera feed
                NonARModelView(card: currentCard)
                    .ignoresSafeArea()
            }

            // Top-left bar with back + AR/Object toggle
            VStack {
                HStack {
                    CustomTopBar(isARMode: $isARMode)
                        .padding()
                    
                    Spacer()
                }
                .padding(.top, 20)
                Spacer()
                ARBottomBar()
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .arModelSelectionChanged)) { notification in
            if let downloadId = notification.userInfo?["downloadId"] as? String,
               let name = notification.userInfo?["name"] as? String {
                updateCurrentCard(downloadId: downloadId, name: name)
            }
        }
        .fullScreenCover(isPresented: $showPortal) {
            PortalWebView()
                .ignoresSafeArea()
        }
    }
    
    private func updateCurrentCard(downloadId: String, name: String) {
        let description = stateManager.isUsingPresets ? "ceiling" : card.description
        let newCard = Card(
            imageName: card.imageName,
            title: name,
            price: card.price,
            description: description,
            objectName: downloadId,
            size: card.size,
            color: card.color
        )
        
        withAnimation {
            currentCard = newCard
            hasPlacedModel = false
            showInstructions = true
            showPlacementIndicator = false
        }
    }
}
#Preview{
    ARContainerWithOverlay(card:  Card(imageName: ["chairFront","chairSide","chairBack"], title: "Placeholder", price: 49, description: "Placeholder", objectName: "ceilingmultiplependants", size: "22 x 22 x 22", color: "red"))
}
