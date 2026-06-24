import SwiftUI
import RealityKit

struct NonARModelView: UIViewRepresentable {
    let card: Card

    // MARK: - Coordinator for pan-based rotation (like StaticLightPreviewView)
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
            let minPitch: Float = -.pi / 8
            let maxPitch: Float =  .pi / 8
            newPitch = max(min(newPitch, maxPitch), minPitch)

            // 3) Build quaternions for yaw (Y axis) and pitch (X axis)
            let yawQuat   = simd_quatf(angle: newYaw,   axis: SIMD3<Float>(0, 1, 0))
            let pitchQuat = simd_quatf(angle: newPitch, axis: SIMD3<Float>(0.5, 0, 0))

            // 4) Apply orientation (yaw then pitch)
            model.orientation = yawQuat * pitchQuat

            // 5) Store values when gesture ends so dragging continues smoothly
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

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        // No camera feed, just a 3D background similar to StaticLightPreviewView
        arView.automaticallyConfigureSession = false
        arView.cameraMode = .nonAR
        // Light gray / half-white style background
        arView.environment.background = .color(UIColor(white: 0.9, alpha: 1.0))

        loadModel(into: arView, context: context)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Nothing dynamic to update for now
    }

    private func loadModel(into arView: ARView, context: Context) {
        guard let loadedEntity = ConfiguratorModelStore.loadEntity(
            downloadId: card.objectName,
            bundledName: card.objectName
        ) else {
            print("❌ NonARModelView: Model not found for objectName: \(card.objectName)")
            return
        }

        // Recenter so visual center is at origin
        let bounds = loadedEntity.visualBounds(relativeTo: nil)
        let center = bounds.center
        loadedEntity.position = SIMD3<Float>(-center.x, -center.y, -center.z)

        // Correct upside-down orientation: flip 180° around X axis
        loadedEntity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))

        // Wrap in a ModelEntity container so we always have HasCollision support
        let modelEntity = ModelEntity()
        modelEntity.addChild(loadedEntity)

        // Scale the model to a comfortable height relative to its largest dimension
        let size = bounds.extents
        let largestDimension = max(size.x, max(size.y, size.z))
        let targetHeight: Float = 2.0
        if largestDimension > 0 {
            let uniformScale = targetHeight / largestDimension
            modelEntity.scale = SIMD3<Float>(repeating: uniformScale)
        }

        // Position slightly up and towards the camera (lowered a bit compared to before)
        modelEntity.transform.translation = SIMD3<Float>(0, 1.5, -0.5)

        // Ensure collision shapes exist so gestures work
        modelEntity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity()
        anchor.addChild(modelEntity)
        arView.scene.anchors.removeAll()
        arView.scene.addAnchor(anchor)

        // Attach pan gesture to control rotation (like StaticLightPreviewView)
        context.coordinator.modelEntity = modelEntity
        let panGesture = UIPanGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
    }
}
