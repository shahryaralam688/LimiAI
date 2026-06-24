//
//import SwiftUI
//import RealityKit
//import ARKit
//import Combine
//
//final class TestingARViewHolder: ObservableObject {
//    static let shared = ARViewHolder()       // Singleton to persist ARView
//    let arView: ARView
//    private var lastConfig: ARWorldTrackingConfiguration
//
//    private init() {
//        arView = ARView(frame: .zero)
//        arView.environment.background = .cameraFeed()
//
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal, .vertical]
//        config.environmentTexturing = .automatic
//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
//            config.sceneReconstruction = .meshWithClassification
//        }
//        self.lastConfig = config
//
//        runSession(reset: true)
//        print("Persistent AR session started at \(Date())")
//    }
//
//    func runSession(reset: Bool = false) {
//        // Ensure camera feed is active before running
//        arView.environment.background = .cameraFeed()
//        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
//        arView.session.run(lastConfig, options: options)
//        // Simple log to help diagnose lifecycle issues
//        print("AR session run called. reset=\(reset) @ \(Date())")
//    }
//}
//
//private extension ARContainerWithOverlay {
//    func instructionTextForCard() -> String {
//        let desc = card.description.lowercased()
//        if desc.contains("ceil") { return "Point the camera towards the ceiling" }
//        if desc.contains("fooler") || desc.contains("floor") { return "Point the camera towards the fooler" }
//        return "Point the camera towards the wall"
//    }
//}
//
//struct ARTestingARViewContainer: UIViewRepresentable {
//    var card: Card
//    @Binding var showInstructions: Bool
//    @Binding var showPlacementIndicator: Bool
//    @ObservedObject private var holder = ARViewHolder.shared
//
//    // MARK: - Coordinator
//    class Coordinator: NSObject {
//        let parent: ARViewContainer
//        var updateSubscription: Cancellable?
//        weak var tapGesture: UITapGestureRecognizer?
//        var previewAnchor: AnchorEntity?
//        var previewEntity: Entity?
//        var modelEntity: Entity?
//        var lastValidTransform: float4x4?
//
//        init(_ parent: ARViewContainer) {
//            self.parent = parent
//            super.init()
//        }
//
//        // Determine placement target based on card.description
//        private enum PlacementTarget {
//            case ceiling
//            case floor
//            case wall
//        }
//
//        private func placementTarget() -> PlacementTarget {
//            let desc = parent.card.description.lowercased()
//            if desc.contains("ceil") { return .ceiling }
//            if desc.contains("fooler") || desc.contains("floor") { return .floor }
//            return .wall
//        }
//
//        func loadModelIfNeeded(for card: Card) {
//            guard modelEntity == nil else { return }
//
//            let fileManager = FileManager.default
//            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//            let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator")
//            let modelURL = configuratorFolderURL.appendingPathComponent("\(card.objectName).usdz")
//
//            // Prefer downloaded model from Documents/Configurator; if not present, fall back to bundled asset
//            let finalURL: URL?
//            if fileManager.fileExists(atPath: modelURL.path) {
//                finalURL = modelURL
//            } else {
//                finalURL = Bundle.main.url(forResource: card.objectName,
//                                           withExtension: "usdz",
//                                           subdirectory: "art.scnassets")
//            }
//
//            guard let resolvedURL = finalURL else {
//                print("❌ Model not found for objectName: \(card.objectName)")
//                return
//            }
//            do {
//                let entity = try Entity.load(contentsOf: resolvedURL)
//                entity.transform.scale = SIMD3<Float>(repeating: 1)
//                self.modelEntity = entity
//                print("✅ Loaded model for placement: \(card.objectName)")
//            } catch {
//                print("❌ Failed to load USDZ: \(error.localizedDescription)")
//            }
//        }
//
//        func startRaycasting() {
//            guard updateSubscription == nil else { return }
//            let arView = ARViewHolder.shared.arView
//            // Subscribe to per-frame updates to drive the placement preview
//            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
//                self?.updatePlacementPreview()
//            }
//        }
//
//        func stopRaycasting() {
//            updateSubscription?.cancel()
//            updateSubscription = nil
//        }
//
//        private func ensurePreviewSetup(in arView: ARView) {
//            if previewAnchor == nil {
//                previewAnchor = AnchorEntity(world: matrix_identity_float4x4)
//                if let anchor = previewAnchor {
//                    arView.scene.addAnchor(anchor)
//                }
//            }
//            if previewEntity == nil {
//                // Create transparent border-only square and circle (matching reference image)
//                
//                // Transparent alabaster material for borders only
//                var borderMaterial = UnlitMaterial()
//                borderMaterial.color = .init(tint: UIColor(named: "alabaster")?.withAlphaComponent(0.7) ?? .themeWhite)
//
//                // Square border - 4 thin lines forming outline
//                let lineThickness: Float = 0.004
//                let squareSize: Float = 0.3
//                
//                let topLine = ModelEntity(
//                    mesh: MeshResource.generateBox(width: squareSize, height: lineThickness, depth: lineThickness),
//                    materials: [borderMaterial]
//                )
//                let bottomLine = ModelEntity(
//                    mesh: MeshResource.generateBox(width: squareSize, height: lineThickness, depth: lineThickness),
//                    materials: [borderMaterial]
//                )
//                let leftLine = ModelEntity(
//                    mesh: MeshResource.generateBox(width: lineThickness, height: lineThickness, depth: squareSize),
//                    materials: [borderMaterial]
//                )
//                let rightLine = ModelEntity(
//                    mesh: MeshResource.generateBox(width: lineThickness, height: lineThickness, depth: squareSize),
//                    materials: [borderMaterial]
//                )
//                
//                // Position square border lines
//                let halfSize = squareSize / 2
//                topLine.transform.translation = SIMD3<Float>(0, 0, halfSize)
//                bottomLine.transform.translation = SIMD3<Float>(0, 0, -halfSize)
//                leftLine.transform.translation = SIMD3<Float>(-halfSize, 0, 0)
//                rightLine.transform.translation = SIMD3<Float>(halfSize, 0, 0)
//                
//                // Circle border - create using small segments for smooth outline
//                let circleContainer = Entity()
//                let circleRadius: Float = 0.095
//                let segmentCount = 24
//                
//                for i in 0..<segmentCount {
//                    let angle = Float(i) * (2 * Float.pi / Float(segmentCount))
//                    _ = Float(i + 1) * (2 * Float.pi / Float(segmentCount))
//                    
//                    let segmentLength: Float = 2 * circleRadius * sin(Float.pi / Float(segmentCount))
//                    let segment = ModelEntity(
//                        mesh: MeshResource.generateBox(width: segmentLength, height: lineThickness, depth: lineThickness),
//                        materials: [borderMaterial]
//                    )
//                    
//                    segment.transform.translation = SIMD3<Float>(
//                        cos(angle) * circleRadius,
//                        0.001,
//                        sin(angle) * circleRadius
//                    )
//                    segment.transform.rotation = simd_quatf(angle: angle + Float.pi/2, axis: SIMD3<Float>(0, 1, 0))
//                    
//                    circleContainer.addChild(segment)
//                }
//                
//                // Center dot
//                let centerDot = ModelEntity(
//                    mesh: MeshResource.generateSphere(radius: 0.006),
//                    materials: [borderMaterial]
//                )
//                centerDot.transform.translation.y = 0.002
//                
//                let containerEntity = Entity()
//                containerEntity.addChild(topLine)
//                containerEntity.addChild(bottomLine)
//                containerEntity.addChild(leftLine)
//                containerEntity.addChild(rightLine)
//                containerEntity.addChild(circleContainer)
//                containerEntity.addChild(centerDot)
//                containerEntity.name = "PlacementIndicator"
//                
//                // Animate the circle with subtle pulsing
//                DispatchQueue.main.async {
//                    var isScaledUp = false
//                    Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
//                        let targetScale: SIMD3<Float> = isScaledUp ? SIMD3<Float>(1.0, 1.0, 1.0) : SIMD3<Float>(1.15, 1.0, 1.15)
//                        let targetTransform = Transform(
//                            scale: targetScale,
//                            rotation: circleContainer.transform.rotation,
//                            translation: circleContainer.transform.translation
//                        )
//                        circleContainer.move(to: targetTransform, relativeTo: circleContainer.parent, duration: 0.6)
//                        isScaledUp.toggle()
//                    }
//                }
//                
//                previewEntity = containerEntity
//                previewEntity?.isEnabled = false
//                previewAnchor?.addChild(containerEntity)
//            }
//        }
//
//        private func updatePlacementPreview() {
//            let arView = ARViewHolder.shared.arView
//            ensurePreviewSetup(in: arView)
//
//            // 1) Optional camera orientation guidance depending on target
//            let target = placementTarget()
//            if let frame = arView.session.currentFrame {
//                let m = frame.camera.transform
//                // Camera forward is -Z of the transform
//                let forward = simd_normalize(SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z))
//                // Dot with world up (0,1,0): 1 = straight up, -1 = straight down
//                let dotUp = simd_dot(forward, SIMD3<Float>(0, 1, 0))
//                let lookingUp = dotUp > 0.35
//                let lookingDown = dotUp < -0.35
//
//                switch target {
//                case .ceiling:
//                    if !lookingUp {
//                        previewEntity?.isEnabled = false
//                        lastValidTransform = nil
//                        DispatchQueue.main.async {
//                            self.parent.showPlacementIndicator = false
//                            self.parent.showInstructions = true
//                        }
//                        return
//                    }
//                case .floor:
//                    if !lookingDown {
//                        previewEntity?.isEnabled = false
//                        lastValidTransform = nil
//                        DispatchQueue.main.async {
//                            self.parent.showPlacementIndicator = false
//                            self.parent.showInstructions = true
//                        }
//                        return
//                    }
//                case .wall:
//                    // No strict orientation gate for walls; proceed to raycast
//                    break
//                }
//            }
//
//            // Center point of the screen
//            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
//            // Raycast against existing plane geometry, choose alignment based on target
//            let alignment: ARRaycastQuery.TargetAlignment = {
//                switch placementTarget() {
//                case .wall: return .vertical
//                case .ceiling, .floor: return .horizontal
//                }
//            }()
//            let results = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: alignment)
//
//            guard let first = results.first else {
//                previewEntity?.isEnabled = false
//                lastValidTransform = nil
//                DispatchQueue.main.async {
//                    self.parent.showPlacementIndicator = false
//                    // Keep instructions hidden here (we are looking up) but no ceiling hit yet
//                }
//                return
//            }
//
//            // Allow only the requested classification when available
//            var isValidHit = true
//            if let planeAnchor = first.anchor as? ARPlaneAnchor {
//                if #available(iOS 13.0, *), ARPlaneAnchor.isClassificationSupported {
//                    switch placementTarget() {
//                    case .ceiling:
//                        isValidHit = (planeAnchor.classification == .ceiling)
//                    case .floor:
//                        isValidHit = (planeAnchor.classification == .floor)
//                    case .wall:
//                        isValidHit = (planeAnchor.classification == .wall)
//                    }
//                }
//            }
//
//            if !isValidHit {
//                previewEntity?.isEnabled = false
//                lastValidTransform = nil
//                DispatchQueue.main.async {
//                    self.parent.showPlacementIndicator = false
//                    // Keep instructions visible/hidden depending on orientation gate above
//                }
//                return
//            }
//
//            // Show preview at the hit transform
//            let transform = first.worldTransform
//            previewEntity?.isEnabled = true
//            previewAnchor?.transform.matrix = transform
//            lastValidTransform = transform
//            
//            // Hide instructions and show placement indicator
//            DispatchQueue.main.async {
//                self.parent.showInstructions = false
//                self.parent.showPlacementIndicator = true
//            }
//        }
//
//        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
//            let arView = ARViewHolder.shared.arView
//            guard recognizer.state == .ended,
//                  let placeTransform = lastValidTransform,
//                  let entity = modelEntity else {
//                return
//            }
//            // Place a clone of the loaded model at the preview location
//            let anchor = AnchorEntity(world: placeTransform)
//            let clone = entity.clone(recursive: true)
//            anchor.addChild(clone)
//            arView.scene.addAnchor(anchor)
//            switch placementTarget() {
//            case .ceiling:
//                print("📌 Placed model on ceiling at preview location")
//            case .floor:
//                print("📌 Placed model on floor at preview location")
//            case .wall:
//                print("📌 Placed model on wall at preview location")
//            }
//        }
//    }
//
//    func makeUIView(context: Context) -> ARView {
//        // Ensure session is running when the view is created
//        holder.runSession(reset: false)
//        let arView = holder.arView
//        // Install tap gesture once
//        if context.coordinator.tapGesture == nil {
//            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
//            arView.addGestureRecognizer(tap)
//            context.coordinator.tapGesture = tap
//        }
//        context.coordinator.loadModelIfNeeded(for: card)
//        context.coordinator.startRaycasting()
//        return arView
//    }
//
//    func updateUIView(_ uiView: ARView, context: Context) {
//        // Ensure model is loaded; placement happens via preview + tap
//        context.coordinator.loadModelIfNeeded(for: card)
//    }
//    
//    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
//        // Do not pause the singleton session here; leaving it running avoids losing camera feed on next appear
//        print("ARViewContainer dismantle called (session left running)")
//        uiView.removeFromSuperview()
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//}
//
//// MARK: - AR Instruction Overlay
//struct TestingARInstructionOverlay: View {
//    let showInstructions: Bool
//    let showPlacementIndicator: Bool
//    let instructionText: String
//    @State private var phoneOffsetUp: Bool = false
//    
//    var body: some View {
//        ZStack {
//            if showInstructions {
//                VStack(spacing: 20) {
//                    Spacer()
//                    
//                    VStack(spacing: 16) {
//                        // Phone icon with animation
//                        ZStack {
//                            // Platform/surface
//                            RoundedRectangle(cornerRadius: 8)
//                                .stroke(Color.themeWhite, lineWidth: 2)
//                                .frame(width: 120, height: 8)
//                            
//                            // Phone with up/down animation
//                            RoundedRectangle(cornerRadius: 8)
//                                .fill(Color.themeWhite)
//                                .frame(width: 40, height: 70)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 6)
//                                        .fill(Color.themeBlack)
//                                        .frame(width: 32, height: 55)
//                                )
//                                .offset(y: phoneOffsetUp ? -30 : -5) // animate vertically above platform
//                                .animation(
//                                    Animation.easeInOut(duration: 1.2)
//                                        .repeatForever(autoreverses: true),
//                                    value: phoneOffsetUp
//                                )
//                        }
//                        
//                        Text(instructionText)
//                            .font(.headline)
//                            .foregroundColor(.themeWhite)
//                            .multilineTextAlignment(.center)
//                    }
//                    .padding(.horizontal, 40)
//                    .padding(.vertical, 30)
//                    .background(
//                        RoundedRectangle(cornerRadius: 16)
//                            .fill(Color.themeBlack.opacity(0.7))
//                    )
//                    .onAppear {
//                        // Kick off the vertical animation loop
//                        phoneOffsetUp.toggle()
//                    }
//                    
//                    Spacer()
//                }
//            }
//            
//            if showPlacementIndicator {
//                VStack {
//                    Text("Tap")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.themeWhite)
//                        .padding(.horizontal, 20)
//                        .padding(.vertical, 10)
//                        .background(
//                            Capsule()
//                                .fill(Color.themeBlack.opacity(0.7))
//                        )
//                        .padding(.top, 100)
//                    
//                    Spacer()
//                }
//            }
//        }
//    }
//}
//
//// MARK: - AR Container with Overlay
//struct TestingARContainerWithOverlay: View {
//    let card: Card
//    @State private var showInstructions = true
//    @State private var showPlacementIndicator = false
//    @State private var showPortal = false
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        ZStack {
//            TestingARViewContainer(
//                card: card,
//                showInstructions: $showInstructions,
//                showPlacementIndicator: $showPlacementIndicator
//            )
//            .ignoresSafeArea()
//            
//            TestingARInstructionOverlay(
//                showInstructions: showInstructions,
//                showPlacementIndicator: showPlacementIndicator,
//                instructionText: instructionTextForCard()
//            )
//
//            // Top-left Back button to dismiss AR view
//            
//            VStack {
//                HStack {
//                    Button(action: { dismiss() }) {
//                        HStack(spacing: 6) {
//                            Image(systemName: "chevron.left")
//                                .foregroundColor(.themeWhite)
//                            Text("Back")
//                                .foregroundColor(.themeWhite)
//                                .font(.headline)
//                        }
//                        .padding(10)
//                        .padding(.top, 20)
//                        .cornerRadius(10)
//                    }
//                    .accessibilityLabel("Back")
//                    .padding(.leading, 16)
//                    Spacer()
//                }
//                .padding(.top, 20)
//                Spacer()
//            }
//
//        }
//        .fullScreenCover(isPresented: $showPortal) {
//            PortalWebView()
//                .ignoresSafeArea()
//        }
//    }
//}
//
