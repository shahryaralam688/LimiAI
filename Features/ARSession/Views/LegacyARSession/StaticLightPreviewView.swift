//
//  StaticLightPreviewView 2.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 26/11/2025.
//


import SwiftUI
import RealityKit

struct StaticLightPreviewView: View {
    var body: some View {
        ZStack {
            StaticLightARViewContainer(macAddress: "avcd")
                .ignoresSafeArea()
        }
        .background(Color.appCanvasPrimary)
        .ignoresSafeArea()
    }
}

struct StaticLightARViewContainer: UIViewRepresentable {
    let macAddress: String?
    
    class Coordinator {
        var modelEntity: ModelEntity?
        private var accumulatedYaw: Float = 0      // Y axis rotation (left/right)
        private var accumulatedPitch: Float = 0    // X axis rotation (up/down)

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view, let model = modelEntity else { return }

            let translation = gesture.translation(in: view)
            let sensitivity: Float = 0.005   // adjust for faster/slower rotation

            // 1) Propose new yaw & pitch based on drag
            var newYaw   = accumulatedYaw   + Float(translation.x) * sensitivity
            var newPitch = accumulatedPitch + Float(translation.y) * sensitivity

            // 2) Clamp pitch so model doesn’t flip vertically
            let minPitch: Float = -.pi / 8    // -90°
            let maxPitch: Float =  .pi / 8  // +90°
            newPitch = max(min(newPitch, maxPitch), minPitch)

            // 👉 If you ALSO want to clamp yaw (optional), uncomment this:
            // let minYaw: Float = -.pi        // -180°
            // let maxYaw: Float =  .pi        // +180°
            // newYaw = max(min(newYaw, maxYaw), minYaw)

            // 3) Build quaternions for yaw (Y axis) and pitch (X axis)
            let yawQuat   = simd_quatf(angle: newYaw,   axis: SIMD3<Float>(0, 1, 0))
            let pitchQuat = simd_quatf(angle: newPitch, axis: SIMD3<Float>(0.5, 0, 0))

            // 4) Apply orientation (yaw then pitch)
            model.orientation = yawQuat * pitchQuat

            // 5) Store the values when gesture ends so dragging continues smoothly
            switch gesture.state {
            case .ended, .cancelled, .failed:
                accumulatedYaw = newYaw
                accumulatedPitch = newPitch
                gesture.setTranslation(.zero, in: view)
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
            print("\(indent)─ Entity: '\(entity.name)' [\(type(of: entity))]")

            // Transform info
            let t = entity.transform
            print("\(indent)  Transform:")
            print("\(indent)    translation: \(t.translation)")
            print("\(indent)    rotation: \(t.rotation)")
            print("\(indent)    scale: \(t.scale)")

            // Model / mesh / material info
            if let modelEntity = entity as? ModelEntity {
                modelEntityCount += 1
                print("\(indent)  ✅ Has ModelComponent")

                if let modelComp = modelEntity.model {
                    let mesh = modelComp.mesh

                    // This isn't a perfect "submesh count" but gives an idea of pieces
                    let submeshCount = mesh.contents.models.count
                    meshSubmeshCount += submeshCount
                    print("\(indent)    Mesh submesh count (approx): \(submeshCount)")

                    let mats = modelComp.materials
                    materialCount += mats.count
                    print("\(indent)    Materials (\(mats.count)):")
                    for (index, material) in mats.enumerated() {
                        let matName = ((material.name?.isEmpty) != nil) ? "<unnamed>" : material.name
                        print("\(indent)      [\(index)] \(matName) – \(type(of: material))")
                        materialNames.append(matName ?? "")
                    }
                } else {
                    print("\(indent)    ModelEntity has no ModelComponent")
                }
            }

            if !entity.children.isEmpty {
                print("\(indent)  Children count: \(entity.children.count)")
            }

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

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.cameraMode = .nonAR

        // Set the 3D background color behind the model (matches dark hex-style background)
        arView.environment.background = .color(UIColor(Color.appCanvasPrimary))

        let downloadId: String? = macAddress.flatMap { DeviceDownloadStore.shared.get(forMac: $0) }

        guard let loadedEntity = ConfiguratorModelStore.loadEntity(downloadId: downloadId, bundledName: "mount1") else {
            return arView
        }

        // 🔍 Print meshes / materials / hierarchy for this model
        if let sourceURL = ConfiguratorModelStore.resolveModelURL(downloadId: downloadId, bundledName: "mount1") {
            debugPrintModelInfo(root: loadedEntity, from: sourceURL)
        }

        // Recenter the loaded entity so its visual center sits at the origin (0,0,0)
        let bounds = loadedEntity.visualBounds(relativeTo: nil)
        let center = bounds.center
        loadedEntity.position = SIMD3<Float>(-center.x, -center.y, -center.z)

        // Correct upside-down orientation: flip 180° around X axis on the child entity
        loadedEntity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))

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

        // Position the model higher and closer to the camera for better visibility
        modelEntity.transform.translation = SIMD3<Float>(0, 2.5, -0.5)

        // Make sure the entity has collision so gestures can work properly
        modelEntity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity()
        anchor.addChild(modelEntity)
        arView.scene.addAnchor(anchor)

        // Attach pan gesture to control rotation around X and Y axes
        context.coordinator.modelEntity = modelEntity
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(panGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
    }
}

#Preview {
    StaticLightPreviewView()
}
