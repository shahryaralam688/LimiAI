import SwiftUI
import SceneKit

/// A UIViewRepresentable that wraps SCNView, sets an interior camera,
/// and handles tap-to-color and first-person controls, plus camera reset.
struct TappableSceneView: UIViewRepresentable {
    let scene: SCNScene
    let onNodeTap: (SCNNode) -> Void
    @Binding var coordinator: Coordinator?

    func makeCoordinator() -> Coordinator {
        Coordinator(onNodeTap: onNodeTap)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.scene = scene
        scnView.backgroundColor = .appBlack
        
        // Create and position the interior camera
        let cameraNode = SCNNode()
        cameraNode.name = "cameraNode"
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1.6, z: 0)
        cameraNode.eulerAngles = SCNVector3Zero
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        
        // let coordinator hold references
        context.coordinator.scnView = scnView
        context.coordinator.cameraNode = cameraNode
        context.coordinator.storeInitialTransform()
        
        // Set the coordinator binding back
        DispatchQueue.main.async {
            self.coordinator = context.coordinator
        }
        
        // Improve lighting for better texture visibility
        scnView.autoenablesDefaultLighting = true

        // Add a single strong light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 2000
        lightNode.light?.color = UIColor.appWhite
        lightNode.position = SCNVector3(x: 0, y: 3, z: 0)
        scene.rootNode.addChildNode(lightNode)

        scnView.allowsCameraControl = false

        // Gestures
        let lookPan = UIPanGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePan(_:)))
        lookPan.minimumNumberOfTouches = 1; lookPan.maximumNumberOfTouches = 1
        scnView.addGestureRecognizer(lookPan)

        let movePan = UIPanGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handleMovePan(_:)))
        movePan.minimumNumberOfTouches = 2; movePan.maximumNumberOfTouches = 2
        scnView.addGestureRecognizer(movePan)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) { }

    class Coordinator: NSObject {
        let onNodeTap: (SCNNode) -> Void
        weak var scnView: SCNView?
        weak var cameraNode: SCNNode?
        private var initialPosition: SCNVector3 = SCNVector3Zero
        private var initialEuler: SCNVector3 = SCNVector3Zero

        init(onNodeTap: @escaping (SCNNode) -> Void) {
            self.onNodeTap = onNodeTap
            super.init()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleMoveNotification(_:)),
                                                   name: .moveCamera,
                                                   object: nil)
        }

        /// Store initial camera transform
        func storeInitialTransform() {
            guard let cam = cameraNode else { return }
            initialPosition = cam.position
            initialEuler = cam.eulerAngles
        }

        /// Reset camera to initial
        func resetCamera() {
            guard let cam = cameraNode else { return }
            cam.position = initialPosition
            cam.eulerAngles = initialEuler
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scn = scnView else { return }
            let location = gesture.location(in: scn)
            let hits = scn.hitTest(location, options: nil)
            if let hit = hits.first {
                let node = hit.node
                print("🛠 Tapped node: \(node.name ?? "<unnamed>")")
                if let geom = node.geometry {
                    print("Geometry materials before: \(geom.materials)")
                }
                onNodeTap(node)
            } else {
                print("🛠 No hit at location: \(location)")
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scn = scnView, let cam = cameraNode else { return }
            let t = gesture.translation(in: scn)
            let s: Float = 0.005
            cam.eulerAngles.y -= Float(t.x) * s
            cam.eulerAngles.x -= Float(t.y) * s
            gesture.setTranslation(.zero, in: scn)
        }

        @objc func handleMovePan(_ gesture: UIPanGestureRecognizer) {
            guard let scn = scnView, let cam = cameraNode else { return }
            let t = gesture.translation(in: scn)
            let s: Float = 0.01
            let yaw = cam.eulerAngles.y
            let fwd = SCNVector3(-sin(yaw),0,-cos(yaw))
            let right = SCNVector3(cos(yaw),0,-sin(yaw))
            cam.position.x += (fwd.x * -Float(t.y) + right.x * Float(t.x)) * s
            cam.position.z += (fwd.z * -Float(t.y) + right.z * Float(t.x)) * s
            gesture.setTranslation(.zero, in: scn)
        }
        

        @objc func handleMoveNotification(_ note: Notification) {
            guard let dir = note.userInfo?["direction"] as? CameraMovement,
                  let cam = cameraNode else { return }
            let step: Float = 0.1
            let yaw = cam.eulerAngles.y
            let fwd = SCNVector3(-sin(yaw),0,-cos(yaw))
            let right = SCNVector3(cos(yaw),0,-sin(yaw))
            switch dir {
            case .forward:
                cam.position = cam.position + fwd * step
            case .backward:
                cam.position = cam.position - fwd * step
            case .left:
                cam.position = cam.position - right * step
            case .right:
                cam.position = cam.position + right * step
            }
        }
        
        @objc func ByPan(_ gesture: UIPanGestureRecognizer) {
            guard let scn = scnView, let cam = cameraNode else { return }
            let t = gesture.translation(in: scn)
            let s: Float = 0.01
            let yaw = cam.eulerAngles.y
            let fwd = SCNVector3(-sin(yaw),0,-cos(yaw))
            let right = SCNVector3(cos(yaw),0,-sin(yaw))
            cam.position.x += (fwd.x * -Float(t.y) + right.x * Float(t.x)) * s
            cam.position.z += (fwd.z * -Float(t.y) + right.z * Float(t.x)) * s
            gesture.setTranslation(.zero, in: scn)
        }
    }
}

enum CameraMovement { case forward, backward, left, right }

extension Notification.Name {
    static let resetCameraManual = Notification.Name("resetCameraManual")
    static let moveCamera        = Notification.Name("moveCamera")
}

/// Full-screen SwiftUI view that hosts the tappable interior scene with Reset and Movement controls
struct ModelEditorView: View {
    @State private var scene: SCNScene?
    @State private var coordinator: TappableSceneView.Coordinator?
    @State private var debugMessage: String = ""
    @State private var showDebug: Bool = false
    @State private var selectedColor: Color = .red
    @State private var showColorPicker = false
    @State private var textureScale: Float = 2.0
    
    // Texture names
    let brickTextureName = "brick_texture"
    
    // Track wall overlays
    @State private var wallOverlays: [String: SCNNode] = [:]
    
    let modelName: String
    
    // Predefined colors for walls
    let wallColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        Color.appBrick, // Brick red
        Color.appTan, // Tan
        Color.appNeutralGray, // Gray
        Color.appNeutralMid, // Off-white
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let scene = scene {
                GeometryReader { proxy in
                    TappableSceneView(scene: scene,
                                      onNodeTap: handleNodeTap(_:),
                                      coordinator: $coordinator)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .edgesIgnoringSafeArea(.all)
                }
            } else {
                Text("Loading 3D interior view…")
                    .italic()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBlack)
                    .foregroundColor(.themeWhite)
            }

            // Controls
            VStack(spacing: 12) {
                Button("Reset") { NotificationCenter.default.post(name: .resetCameraManual, object: nil) }
                    .padding(8).background(Color.themeWhite.opacity(0.7)).cornerRadius(8)
                VStack(spacing: 4) {
                    Button("↑") { move(.forward) }
                    HStack(spacing: 16) {
                        Button("←") { move(.left) }
                        Button("→") { move(.right) }
                    }
                    Button("↓") { move(.backward) }
                }
                .padding(8).background(Color.themeWhite.opacity(0.7)).cornerRadius(8)
                
                // Color selection
                Button("Colors") { showColorPicker.toggle() }
                    .padding(8).background(Color.themeWhite.opacity(0.7)).cornerRadius(8)
                
                if showColorPicker {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wall Colors")
                            .font(.caption)
                            .padding(.horizontal, 8)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 8) {
                            ForEach(wallColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(color == selectedColor ? Color.themeWhite : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(8)
                        
                        // Texture scale slider
                        Text("Texture Scale: \(textureScale, specifier: "%.1f")")
                            .font(.caption)
                            .padding(.horizontal, 8)
                        
                        Slider(value: $textureScale, in: 0.5...5.0, step: 0.5)
                            .padding(.horizontal, 8)
                        
                        // Action buttons
                        HStack {
                            Button("Apply Color") {
                                applyColorToAllWalls()
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(8)
                            
                            Button("Apply Brick to Walls") {
                                applyBrickTextureToAllWalls()
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.7))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 8)
                        
                        // Add new buttons for the overlay approach
                        HStack {
                            Button("Create Overlays") {
                                createWallOverlays()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(8)
                            
                            Button("Remove Overlays") {
                                removeWallOverlays()
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.7))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(8)
                    .background(Color.themeBlack.opacity(0.7))
                    .cornerRadius(8)
                }
                
                // Debug button
                Button("Debug") { showDebug.toggle() }
                    .padding(8).background(Color.themeWhite.opacity(0.7)).cornerRadius(8)
            }
            .padding()
            
            // Debug overlay
            if showDebug {
                VStack(alignment: .leading) {
                    Text("Debug Info")
                        .font(.headline)
                    Text(debugMessage)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(10)
                }
                .padding()
                .background(Color.themeBlack.opacity(0.7))
                .foregroundColor(.themeWhite)
                .cornerRadius(8)
                .frame(maxWidth: 300)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 150)
            }
        }
        .onAppear {
            loadScene(named: modelName)
            NotificationCenter.default.addObserver(forName: .resetCameraManual, object: nil, queue: .main) { _ in
                coordinator?.resetCamera()
            }
            
            // Test texture loading on app launch
            testTextureLoading()
        }
    }
    
    private func testTextureLoading() {
        var debugInfo = "Texture Loading Test:\n"
        
        // Test using UIImage
        if let image = UIImage(named: brickTextureName) {
            debugInfo += "✅ UIImage loaded: \(brickTextureName) (\(image.size.width) x \(image.size.height))\n"
        } else {
            debugInfo += "❌ UIImage failed to load: \(brickTextureName)\n"
        }
        
        // Test using Bundle path
        if let path = Bundle.main.path(forResource: brickTextureName, ofType: "jpg") {
            debugInfo += "✅ Found in bundle at: \(path)\n"
        } else {
            debugInfo += "❌ Not found in bundle with extension .jpg\n"
        }
        
        if let path = Bundle.main.path(forResource: brickTextureName, ofType: "png") {
            debugInfo += "✅ Found in bundle at: \(path)\n"
        } else {
            debugInfo += "❌ Not found in bundle with extension .png\n"
        }
        
        updateDebugMessage(debugInfo)
    }

    private func loadScene(named name: String) {
        guard let url = RoominatorFileManager.shared.getUSDZFileURL(for: name) else { return }
        do {
            let loaded = try SCNScene(url: url, options: nil)
            loaded.rootNode.enumerateChildNodes { node, _ in
                node.geometry?.firstMaterial?.isDoubleSided = true
            }
            scene = loaded
        } catch {
            print("Failed to load scene: \(error)")
        }
    }
    
    // MARK: - Wall Overlay Methods
    
    private func createWallOverlays() {
        guard let scene = scene else { return }
        
        // First remove any existing overlays
        removeWallOverlays()
        
        var debugInfo = "Creating wall overlays:\n"
        var wallCount = 0
        
        // Find all wall nodes
        scene.rootNode.enumerateChildNodes { node, _ in
            if let name = node.name, name.hasPrefix("Wall") {
                wallCount += 1
                
                // Create an overlay for this wall
                if let overlay = createOverlayForWall(node) {
                    // Store the overlay
                    wallOverlays[name] = overlay
                    
                    // Apply brick texture to the overlay
                    applyBrickTextureToOverlay(overlay)
                    
                    debugInfo += "Created overlay for \(name)\n"
                } else {
                    debugInfo += "Failed to create overlay for \(name)\n"
                }
            }
        }
        
        debugInfo += "Total walls found: \(wallCount)\n"
        updateDebugMessage(debugInfo)
    }
    
    private func removeWallOverlays() {
        for (name, overlay) in wallOverlays {
            overlay.removeFromParentNode()
            print("Removed overlay for \(name)")
        }
        wallOverlays.removeAll()
    }
    
    private func createOverlayForWall(_ wallNode: SCNNode) -> SCNNode? {
        // Get the wall's geometry
        guard let wallGeometry = wallNode.geometry else {
            print("❌ Wall has no geometry")
            return nil
        }
        
        // Get the wall's bounding box
        let (min, max) = wallGeometry.boundingBox
        
        // Calculate dimensions
        let width = max.x - min.x
        let height = max.y - min.y
        let depth = max.z - min.z
        
        // Determine which dimension is the smallest (thickness)
        let dimensions = [width, height, depth]
        let minDimension = dimensions.min() ?? 0.01
        
        // Create a plane that's slightly larger than the wall
        var planeWidth: CGFloat = 0
        var planeHeight: CGFloat = 0
        var planeNode = SCNNode()
        
        // Determine the orientation of the wall
        if depth < width && depth < height {
            // Wall is oriented along X-Y plane (front/back wall)
            planeWidth = CGFloat(width) * 0.98
            planeHeight = CGFloat(height) * 0.98
            let plane = SCNPlane(width: planeWidth, height: planeHeight)
            planeNode = SCNNode(geometry: plane)
            
            // Position the plane just in front of the wall
            let offset: Float = Float(minDimension) * 0.6
            if wallNode.worldPosition.z > 0 {
                planeNode.position = SCNVector3(0, 0, -offset)
            } else {
                planeNode.position = SCNVector3(0, 0, offset)
            }
        } else if width < depth && width < height {
            // Wall is oriented along Y-Z plane (side wall)
            planeWidth = CGFloat(depth) * 0.98
            planeHeight = CGFloat(height) * 0.98
            let plane = SCNPlane(width: planeWidth, height: planeHeight)
            planeNode = SCNNode(geometry: plane)
            
            // Rotate the plane to face the right direction
            planeNode.eulerAngles = SCNVector3(0, Float.pi/2, 0)
            
            // Position the plane just in front of the wall
            let offset: Float = Float(minDimension) * 0.6
            if wallNode.worldPosition.x > 0 {
                planeNode.position = SCNVector3(-offset, 0, 0)
            } else {
                planeNode.position = SCNVector3(offset, 0, 0)
            }
        } else {
            // Wall is oriented along X-Z plane (floor/ceiling)
            planeWidth = CGFloat(width) * 0.98
            planeHeight = CGFloat(depth) * 0.98
            let plane = SCNPlane(width: planeWidth, height: planeHeight)
            planeNode = SCNNode(geometry: plane)
            
            // Rotate the plane to face the right direction
            planeNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
            
            // Position the plane just in front of the wall
            let offset: Float = Float(minDimension) * 0.6
            if wallNode.worldPosition.y > 0 {
                planeNode.position = SCNVector3(0, -offset, 0)
            } else {
                planeNode.position = SCNVector3(0, offset, 0)
            }
        }
        
        // Name the overlay
        planeNode.name = "Overlay_\(wallNode.name ?? "Wall")"
        
        // Add the plane as a child of the wall
        wallNode.addChildNode(planeNode)
        
        print("✅ Created overlay for \(wallNode.name ?? "unnamed wall") with dimensions \(planeWidth) x \(planeHeight)")
        
        return planeNode
    }
    
    private func applyBrickTextureToOverlay(_ node: SCNNode) {
        // Check if node has geometry
        guard let geometry = node.geometry else {
            print("❌ Overlay has no geometry")
            return
        }
        
        // Load the texture image
        guard let image = UIImage(named: brickTextureName) else {
            print("❌ Failed to load texture image")
            return
        }
        
        // Create a simple material with the brick texture
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(textureScale, textureScale, 1)
        
        // Use a simple lighting model
        material.lightingModel = .constant
        
        // Make sure both sides are visible
        material.isDoubleSided = true
        
        // Apply the material
        geometry.materials = [material]
        
        print("✅ Applied brick texture to overlay \(node.name ?? "unnamed")")
    }
    
    // MARK: - Original Methods (kept for compatibility)
    
    private func applyColorToAllWalls() {
        guard let scene = scene else { return }
        
        var debugInfo = "Applying color to all walls:\n"
        var wallCount = 0
        
        // Find all wall nodes
        scene.rootNode.enumerateChildNodes { node, _ in
            if let name = node.name, name.hasPrefix("Wall") {
                wallCount += 1
                
                // Apply color to this wall
                applyColorToNode(node)
                
                debugInfo += "Applied color to \(name)\n"
            }
        }
        
        debugInfo += "Total walls found: \(wallCount)\n"
        updateDebugMessage(debugInfo)
    }
    
    private func applyBrickTextureToAllWalls() {
        guard let scene = scene else { return }
        
        var debugInfo = "Applying brick texture to all walls:\n"
        var wallCount = 0
        
        // Find all wall nodes
        scene.rootNode.enumerateChildNodes { node, _ in
            if let name = node.name, name.hasPrefix("Wall") {
                wallCount += 1
                
                // Apply brick texture to this wall
                applyBrickTextureToNode(node)
                
                debugInfo += "Applied brick texture to \(name)\n"
            }
        }
        
        debugInfo += "Total walls found: \(wallCount)\n"
        updateDebugMessage(debugInfo)
    }
    
    private func applyColorToNode(_ node: SCNNode) {
        // Check if node has geometry
        guard let geometry = node.geometry else { return }
        
        // Create a new material with the selected color
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(color: selectedColor)
        material.lightingModel = .constant // No lighting effects
        
        // Apply to the node
        let geoCopy = geometry.copy() as! SCNGeometry
        geoCopy.materials = [material]
        node.geometry = geoCopy
    }
    
    private func applyBrickTextureToNode(_ node: SCNNode) {
        // Check if node has geometry
        guard let geometry = node.geometry else {
            print("❌ Node has no geometry")
            return
        }
        
        // Load the texture image
        guard let image = UIImage(named: brickTextureName) else {
            print("❌ Failed to load texture image")
            return
        }
        
        // Create a material with the brick texture
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(textureScale, textureScale, 1)
        
        // Apply to the node
        let geoCopy = geometry.copy() as! SCNGeometry
        geoCopy.materials = [material]
        node.geometry = geoCopy
        
        print("✅ Applied brick texture to \(node.name ?? "unnamed")")
    }

    private func handleNodeTap(_ node: SCNNode) {
        print("🔧 Tapped node: \(node.name ?? "<unnamed>")")
        
        guard let name = node.name else {
            print("❌ Node has no name")
            return
        }
        
        if name.hasPrefix("Wall") {
            // Apply brick texture directly to the wall
            applyBrickTextureToNode(node)
        } else {
            // For non-wall nodes, apply random color as before
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.random()
        }
    }
    
    private func updateDebugMessage(_ message: String) {
        debugMessage = message
        print(message)
    }
    
    private func move(_ direction: CameraMovement) {
        NotificationCenter.default.post(name: .moveCamera, object: nil, userInfo: ["direction": direction])
    }
}

// Helper to convert SwiftUI Color to UIColor
extension UIColor {
    convenience init(color: Color) {
        let components = color.components()
        self.init(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }
}

// Helper to get color components
extension Color {
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 1.0
        
        let result = scanner.scanHexInt64(&hexNumber)
        if result {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
        }
        return (r, g, b, a)
    }
}

// Helpers
private extension UIColor { static func random() -> UIColor { UIColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1) }}
private func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 { SCNVector3(lhs.x+rhs.x, lhs.y+rhs.y, lhs.z+rhs.z) }
private func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 { SCNVector3(lhs.x-rhs.x, lhs.y-rhs.y, lhs.z-rhs.z) }
private func * (v: SCNVector3, s: Float) -> SCNVector3 { SCNVector3(v.x*s, v.y*s, v.z*s) }
