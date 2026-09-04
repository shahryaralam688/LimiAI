//
//  LimiPairingModelView.swift
//  Limi
//
//  Live USDZ preview for Apple-style device pairing cards (non-AR RealityKit).
//

import RealityKit
import SwiftUI

struct LimiPairingModelView: UIViewRepresentable {
    var bundledName: String = LimiPairingAssets.defaultModelName
    var isAnimating: Bool = false
    var allowsInteraction: Bool = false
    /// Slow, continuous turntable spin while idle (pauses during a drag, resumes after).
    var autoRotates: Bool = false
    /// Larger = fills more of the viewport. Setup hero uses ~3.2; compact cards ~2.0.
    var visualScale: Float = 2.0

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.clear)
        loadModel(into: arView, context: context)
        if allowsInteraction {
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handlePan(_:))
            )
            arView.addGestureRecognizer(pan)
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.isAnimating = isAnimating
        context.coordinator.allowsInteraction = allowsInteraction
        context.coordinator.autoRotates = autoRotates
        if isAnimating || autoRotates {
            context.coordinator.startFloatAnimationIfNeeded()
        } else {
            context.coordinator.stopFloatAnimation()
        }
        if context.coordinator.bundledName != bundledName
            || abs(context.coordinator.visualScale - visualScale) > 0.01 {
            context.coordinator.bundledName = bundledName
            context.coordinator.visualScale = visualScale
            reloadModel(in: uiView, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func reloadModel(in arView: ARView, context: Context) {
        arView.scene.anchors.removeAll()
        loadModel(into: arView, context: context)
    }

    private func loadModel(into arView: ARView, context: Context) {
        let candidates = LimiPairingAssets.modelCandidates(primary: bundledName)
        guard let loaded = candidates.compactMap({ name in
            ConfiguratorModelStore.loadEntity(downloadId: nil, bundledName: name)
        }).first else {
            return
        }

        LimiPairingAssets.hideCableParts(in: loaded)

        let bounds = loaded.visualBounds(relativeTo: nil)
        let center = bounds.center
        loaded.position = SIMD3<Float>(-center.x, -center.y, -center.z)

        let container = ModelEntity()
        container.name = "LimiPairingModelContainer"
        container.addChild(loaded)

        let largest = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if largest > 0 {
            let scale = visualScale / largest
            container.scale = SIMD3<Float>(repeating: scale)
        }

        let anchor = AnchorEntity()
        anchor.addChild(container)
        arView.scene.addAnchor(anchor)

        context.coordinator.modelEntity = container
        context.coordinator.bundledName = bundledName
        context.coordinator.visualScale = visualScale
        context.coordinator.startFloatAnimationIfNeeded()
    }

    final class Coordinator {
        var modelEntity: ModelEntity?
        var bundledName: String = LimiPairingAssets.defaultModelName
        var visualScale: Float = 2.0
        var isAnimating = false
        var allowsInteraction = false
        var autoRotates = false

        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private var elapsed: CFTimeInterval = 0

        /// Persisted orientation from user drags. Auto-rotation adds on top of this.
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var autoYaw: Float = 0
        private var isDragging = false

        private static let autoRotateSpeed: Float = 0.35   // rad/s — one turn ≈ 18s
        private static let dragSensitivity: Float = 0.008
        private static let maxPitch: Float = .pi / 6
        private static let floatAmplitude: Float = 0.04

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard allowsInteraction, let view = gesture.view else { return }

            let translation = gesture.translation(in: view)
            let dragYaw = yaw + Float(translation.x) * Self.dragSensitivity
            var dragPitch = pitch + Float(translation.y) * Self.dragSensitivity
            dragPitch = max(min(dragPitch, Self.maxPitch), -Self.maxPitch)

            switch gesture.state {
            case .began, .changed:
                isDragging = true
                applyOrientation(yaw: dragYaw + autoYaw, pitch: dragPitch)
            case .ended, .cancelled, .failed:
                isDragging = false
                yaw = dragYaw
                pitch = dragPitch
                gesture.setTranslation(.zero, in: view)
            default:
                break
            }
        }

        func startFloatAnimationIfNeeded() {
            stopFloatAnimation()
            guard isAnimating || autoRotates, modelEntity != nil else { return }
            lastTimestamp = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopFloatAnimation() {
            displayLink?.invalidate()
            displayLink = nil
            if let modelEntity {
                modelEntity.position.y = 0
            }
        }

        @objc private func tick() {
            guard let modelEntity else { return }
            let now = CACurrentMediaTime()
            let dt = now - lastTimestamp
            lastTimestamp = now
            elapsed += dt

            if isAnimating {
                modelEntity.position.y = Float(sin(elapsed * 2.2)) * Self.floatAmplitude
            }

            if autoRotates, !isDragging {
                autoYaw += Self.autoRotateSpeed * Float(dt)
                applyOrientation(yaw: yaw + autoYaw, pitch: pitch)
            }
        }

        private func applyOrientation(yaw: Float, pitch: Float) {
            guard let modelEntity else { return }
            let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
            modelEntity.orientation = yawQuat * pitchQuat
        }

        deinit {
            stopFloatAnimation()
        }
    }
}

enum LimiPairingAssets {
    static let defaultModelName = "Base1"

    /// Pendant USDZ cable meshes — hide for clean product hero.
    static let cableEntityNames = ["cable0", "c_Cable_0"]

    static func hideCableParts(in root: Entity) {
        for name in cableEntityNames {
            root.findEntity(named: name)?.isEnabled = false
        }
        for child in root.children {
            hideCableParts(in: child)
            let lowered = child.name.lowercased()
            if lowered == "cable0" || lowered == "c_cable_0" {
                child.isEnabled = false
            }
        }
    }

    static func modelCandidates(primary: String) -> [String] {
        let trimmed = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        var names: [String] = []
        if !trimmed.isEmpty { names.append(trimmed) }
        if trimmed != defaultModelName { names.append(defaultModelName) }
        let fallback = PendantModelCatalog.unknownDefault
        if !names.contains(fallback) { names.append(fallback) }
        return names
    }

    static func bundledName(forDeviceId deviceId: String?) -> String {
        let resolved = PendantModelCatalog.bundledName(forDeviceId: deviceId)
        return resolved == PendantModelCatalog.unknownDefault ? defaultModelName : resolved
    }
}
