//  OrbView.swift
//  Aura
//
//  Created by Mac Mini on 19/09/2025.
//

import SwiftUI
import SceneKit
import AVFoundation
import UIKit

private struct OrbBrandPalette {
    let edge: UIColor
    let edgeGlow: UIColor
    let coreFill: UIColor
    let coreGlow: UIColor
}

private func orbBrandPalette(active: Bool) -> OrbBrandPalette {
    if active {
        return OrbBrandPalette(
            edge: UIColor(red: 0.33, green: 0.73, blue: 0.45, alpha: 1.0),
            edgeGlow: UIColor(red: 0.58, green: 0.81, blue: 0.64, alpha: 1.0),
            coreFill: UIColor(red: 0.33, green: 0.73, blue: 0.45, alpha: 0.22),
            coreGlow: UIColor(red: 0.58, green: 0.81, blue: 0.64, alpha: 0.55)
        )
    }
    return OrbBrandPalette(
        edge: UIColor(red: 0.33, green: 0.73, blue: 0.45, alpha: 0.42),
        edgeGlow: UIColor(red: 0.45, green: 0.58, blue: 0.50, alpha: 0.28),
        coreFill: UIColor(red: 0.20, green: 0.35, blue: 0.28, alpha: 0.18),
        coreGlow: UIColor(red: 0.33, green: 0.73, blue: 0.45, alpha: 0.12)
    )
}

struct OrbView: UIViewRepresentable {
    @Binding var intensity: CGFloat
    @Binding var currentVolume: CGFloat
    var isActive: Bool = true

    private let edgeRetentionRatio: Double = 0.8
    private let sphereRadius: CGFloat = 10
    /// Smaller scale = larger orb inside the view (matches old `scaledToFill` PNG coverage).
    private var orthographicScale: CGFloat { sphereRadius * 1.05 }
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling2X
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.rendersContinuously = false
        sceneView.preferredFramesPerSecond = 30
        sceneView.isPlaying = true
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = orthographicScale
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 1000
        cameraNode.position = SCNVector3(0, 0, 50)
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
        let (vertices, edges) = buildGeodesicData(radius: sphereRadius, frequency: 3)

        let glowNode = makeGlowNode(radius: sphereRadius * 0.94, active: isActive)
        sceneView.scene?.rootNode.addChildNode(glowNode)

        let orbNode = buildEdgeNode(vertices: vertices, edges: edges, sphereRadius: sphereRadius, active: isActive)
        orbNode.name = "orb"
        sceneView.scene?.rootNode.addChildNode(orbNode)
        
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.toValue = NSValue(scnVector4: SCNVector4(0.3, 1.0, 0.1, Float.pi * 2))
        rotation.duration = 60
        rotation.repeatCount = .infinity
        orbNode.addAnimation(rotation, forKey: "rotate")
        glowNode.addAnimation(rotation, forKey: "rotate")
        
        context.coordinator.orbNode = orbNode
        context.coordinator.glowNode = glowNode
        context.coordinator.sceneView = sceneView
        context.coordinator.isActive = isActive
        context.coordinator.startDisplayLink()
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.volume = currentVolume
        if context.coordinator.isActive != isActive {
            context.coordinator.isActive = isActive
            context.coordinator.applyBrandAppearance(active: isActive)
        }
        context.coordinator.syncDisplayLink()
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopDisplayLink()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var orbNode: SCNNode?
        var glowNode: SCNNode?
        var sceneView: SCNView?
        var displayLink: CADisplayLink?
        var intensity: CGFloat = 3
        var volume: CGFloat = 0
        var isActive: Bool = true
        private var currentRadius: CGFloat = 10
        
        func startDisplayLink() {
            guard displayLink == nil else { return }
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            displayLink?.add(to: .main, forMode: .common)
            syncDisplayLink()
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        func syncDisplayLink() {
            let shouldAnimate = isActive || volume * intensity > 0.05
            displayLink?.isPaused = !shouldAnimate
            sceneView?.rendersContinuously = shouldAnimate
        }

        func applyBrandAppearance(active: Bool) {
            let palette = orbBrandPalette(active: active)
            orbNode?.enumerateChildNodes { node, _ in
                guard let material = node.geometry?.firstMaterial else { return }
                material.diffuse.contents = palette.edge
                material.emission.contents = palette.edgeGlow
            }
            if let glowMaterial = glowNode?.geometry?.firstMaterial {
                glowMaterial.diffuse.contents = palette.coreFill
                glowMaterial.emission.contents = palette.coreGlow
                glowMaterial.transparency = active ? 0.72 : 0.88
            }
        }
        
        @objc func update() {
            guard let orb = orbNode else { return }
            let baseRadius: CGFloat = 10
            let noiseFactor = CGFloat.random(in: -0.05...0.05)
            let targetRadius = baseRadius + (volume * intensity * 0.35) + noiseFactor
            let smoothing: CGFloat = 0.05
            currentRadius += (targetRadius - currentRadius) * smoothing
            let scale = Float(currentRadius / baseRadius)
            orb.scale = SCNVector3(x: scale, y: scale, z: scale)
            glowNode?.scale = SCNVector3(x: scale, y: scale, z: scale)
            sceneView?.setNeedsDisplay()
        }
    }
    
    private func buildGeodesicData(radius: CGFloat, frequency: Int) -> ([SCNVector3], [Edge]) {
        var vertices = icosahedronVertices()
        var indices = icosahedronIndices()
        for _ in 0..<max(0, frequency) {
            (vertices, indices) = subdivide(vertices: vertices, indices: indices)
        }
        var finalVerts: [SCNVector3] = []
        finalVerts.reserveCapacity(vertices.count)
        for v in vertices {
            let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            finalVerts.append(SCNVector3(v.x/len * Float(radius), v.y/len * Float(radius), v.z/len * Float(radius)))
        }
        var edgeSet = Set<Edge>()
        var uniqueEdges: [Edge] = []
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = indices[i]
            let i1 = indices[i+1]
            let i2 = indices[i+2]
            let e0 = i0 < i1 ? Edge(a: i0, b: i1) : Edge(a: i1, b: i0)
            let e1 = i1 < i2 ? Edge(a: i1, b: i2) : Edge(a: i2, b: i1)
            let e2 = i2 < i0 ? Edge(a: i2, b: i0) : Edge(a: i0, b: i2)
            if edgeSet.insert(e0).inserted { uniqueEdges.append(e0) }
            if edgeSet.insert(e1).inserted { uniqueEdges.append(e1) }
            if edgeSet.insert(e2).inserted { uniqueEdges.append(e2) }
        }
        return (finalVerts, uniqueEdges)
    }

    private func buildEdgeNode(vertices: [SCNVector3], edges: [Edge], sphereRadius: CGFloat, active: Bool) -> SCNNode {
        let parent = SCNNode()
        let thickness: CGFloat = max(0.14, sphereRadius * 0.020)
        let material = edgeMaterial(active: active)
        let retention = max(0.0, min(1.0, edgeRetentionRatio))
        let total = edges.count
        let keepCount = max(0, min(total, Int((Double(total) * retention).rounded())))
        let step = Double(total) / Double(max(1, keepCount))
        var pickedEdges: [Edge] = []
        for i in 0..<keepCount {
            let idx = Int(floor(Double(i) * step))
            pickedEdges.append(edges[idx])
        }
        for e in pickedEdges {
            let a = vertices[Int(e.a)]
            let b = vertices[Int(e.b)]
            let edgeNode = cylinderNode(from: a, to: b, thickness: thickness, material: material)
            parent.addChildNode(edgeNode)
        }
        return parent
    }

    private func cylinderNode(from: SCNVector3, to: SCNVector3, thickness: CGFloat, material: SCNMaterial) -> SCNNode {
        let dir = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let length = CGFloat(sqrt(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z))
        let cyl = SCNCylinder(radius: thickness, height: length)
        cyl.radialSegmentCount = 12
        cyl.firstMaterial = material
        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((from.x + to.x)/2, (from.y + to.y)/2, (from.z + to.z)/2)
        node.orientation = rotationBetweenVectors(from: SCNVector3(0, 1, 0), to: dir)
        return node
    }

    private func rotationBetweenVectors(from: SCNVector3, to: SCNVector3) -> SCNQuaternion {
        let v1 = normalize(from)
        let v2 = normalize(to)
        let crossV = cross(v1, v2)
        let dotV = dot(v1, v2)
        var q = SCNQuaternion(x: crossV.x, y: crossV.y, z: crossV.z, w: 1 + dotV)
        if q.w < 1e-6 {
            let axis = abs(v1.x) > 0.9 ? SCNVector3(0, 0, 1) : SCNVector3(1, 0, 0)
            let ortho = normalize(cross(v1, axis))
            q = SCNQuaternion(x: ortho.x, y: ortho.y, z: ortho.z, w: 0)
        }
        return normalize(q)
    }

    private func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
    private func cross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x)
    }
    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let len = max(1e-6, sqrt(v.x*v.x + v.y*v.y + v.z*v.z))
        return SCNVector3(v.x/len, v.y/len, v.z/len)
    }
    private func normalize(_ q: SCNQuaternion) -> SCNQuaternion {
        let len = sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w)
        return SCNQuaternion(q.x/len, q.y/len, q.z/len, q.w/len)
    }

    private func makeGlowNode(radius: CGFloat, active: Bool) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        let palette = orbBrandPalette(active: active)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.diffuse.contents = palette.coreFill
        material.emission.contents = palette.coreGlow
        material.transparency = active ? 0.72 : 0.88
        material.writesToDepthBuffer = false
        sphere.firstMaterial = material
        let node = SCNNode(geometry: sphere)
        node.renderingOrder = -1
        return node
    }

    private func edgeMaterial(active: Bool) -> SCNMaterial {
        let palette = orbBrandPalette(active: active)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.diffuse.contents = palette.edge
        mat.emission.contents = palette.edgeGlow
        return mat
    }

    private func flatMaterial() -> SCNMaterial {
        edgeMaterial(active: true)
    }

    private func icosahedronVertices() -> [SCNVector3] {
        let t = Float((1.0 + sqrt(5.0)) / 2.0)
        let s: Float = 1.0 / sqrt(1 + t * t)
        let a = s
        let b = t * s
        return [
            SCNVector3(-a,  b,  0), SCNVector3( a,  b,  0),
            SCNVector3(-a, -b,  0), SCNVector3( a, -b,  0),
            SCNVector3( 0, -a,  b), SCNVector3( 0,  a,  b),
            SCNVector3( 0, -a, -b), SCNVector3( 0,  a, -b),
            SCNVector3( b,  0, -a), SCNVector3( b,  0,  a),
            SCNVector3(-b,  0, -a), SCNVector3(-b,  0,  a)
        ]
    }

    private func icosahedronIndices() -> [UInt32] {
        return [
            0,11,5,  0,5,1,   0,1,7,   0,7,10,  0,10,11,
            1,5,9,  5,11,4,  11,10,2, 10,7,6,  7,1,8,
            3,9,4,  3,4,2,   3,2,6,   3,6,8,   3,8,9,
            4,9,5,  2,4,11,  6,2,10,  8,6,7,   9,8,1
        ]
    }

    private struct Edge: Hashable { let a: UInt32; let b: UInt32 }

    private func subdivide(vertices: [SCNVector3], indices: [UInt32]) -> ([SCNVector3], [UInt32]) {
        var verts = vertices
        var newIndices: [UInt32] = []
        var midpointCache: [Edge: UInt32] = [:]
        func midpoint(_ i0: UInt32, _ i1: UInt32) -> UInt32 {
            let key = i0 < i1 ? Edge(a: i0, b: i1) : Edge(a: i1, b: i0)
            if let idx = midpointCache[key] { return idx }
            let v0 = verts[Int(i0)]
            let v1 = verts[Int(i1)]
            let m = SCNVector3((v0.x + v1.x)*0.5, (v0.y + v1.y)*0.5, (v0.z + v1.z)*0.5)
            verts.append(m)
            let idx = UInt32(verts.count - 1)
            midpointCache[key] = idx
            return idx
        }
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = indices[i]
            let i1 = indices[i+1]
            let i2 = indices[i+2]
            let a = midpoint(i0, i1)
            let b = midpoint(i1, i2)
            let c = midpoint(i2, i0)
            newIndices += [i0, a, c, i1, b, a, i2, c, b, a, b, c]
        }
        return (verts, newIndices)
    }
}

// MARK: - Shared orb scene (replaces neuralOrb / neuralOrbOff assets)

enum LimiOrbRenderMode {
    /// Full SceneKit geodesic orb — use for the floating AI bubble only.
    case sceneKit
    /// Lightweight SwiftUI orb — use on onboarding and other multi-animation screens.
    case swiftUI
}

/// GPU-free brand orb for screens that already run heavy animations (onboarding, sign-in).
struct LimiOrbBadge: View {
    let isActive: Bool
    let size: CGFloat

    @State private var breathe = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandHighlight.opacity(isActive ? 0.30 : 0.12),
                            Color.brandAction.opacity(isActive ? 0.18 : 0.07),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.05,
                        endRadius: size * 0.58
                    )
                )

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.brandHighlight.opacity(isActive ? 0.55 : 0.25),
                            Color.brandAction.opacity(isActive ? 0.35 : 0.15),
                            Color.brandHighlight.opacity(0.12),
                            Color.brandAction.opacity(isActive ? 0.45 : 0.2),
                            Color.brandHighlight.opacity(isActive ? 0.5 : 0.22)
                        ],
                        center: .center
                    ),
                    lineWidth: max(0.8, size * 0.014)
                )
                .rotationEffect(.degrees(rotation))
                .blur(radius: 0.4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandHighlight.opacity(isActive ? 0.95 : 0.55),
                            Color.brandAction.opacity(isActive ? 0.85 : 0.45),
                            Color.brandActionDark.opacity(isActive ? 0.65 : 0.35)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.themeWhite.opacity(isActive ? 0.22 : 0.10), Color.clear],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: size * 0.28
                            )
                        )
                )
                .scaleEffect(breathe ? 1.03 : 0.97)
                .shadow(color: Color.brandAction.opacity(isActive ? 0.45 : 0.2), radius: size * 0.14)
                .shadow(color: Color.brandHighlight.opacity(isActive ? 0.35 : 0.15), radius: size * 0.22)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .opacity(isActive ? 1 : 0.78)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

final class LimiOrbSceneState: ObservableObject {
    @Published var isActive: Bool
    let size: CGFloat

    init(isActive: Bool = false, size: CGFloat = 56) {
        self.isActive = isActive
        self.size = size
    }
}

struct LimiOrbScene: View {
    let isActive: Bool
    let size: CGFloat
    var renderMode: LimiOrbRenderMode = .sceneKit

    @State private var intensity: CGFloat = 3
    @State private var volume: CGFloat = 0

    init(isActive: Bool, size: CGFloat = 56, renderMode: LimiOrbRenderMode = .sceneKit) {
        self.isActive = isActive
        self.size = size
        self.renderMode = renderMode
    }

    var body: some View {
        Group {
            switch renderMode {
            case .swiftUI:
                LimiOrbBadge(isActive: isActive, size: size)
            case .sceneKit:
                sceneKitBody
            }
        }
    }

    private var sceneKitBody: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandHighlight.opacity(isActive ? 0.28 : 0.10),
                            Color.brandAction.opacity(isActive ? 0.16 : 0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.05,
                        endRadius: size * 0.58
                    )
                )
                .frame(width: size, height: size)

            OrbView(intensity: $intensity, currentVolume: $volume, isActive: isActive)
                .frame(width: size, height: size)
                .scaleEffect(1.14)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .opacity(isActive ? 1 : 0.78)
        .onAppear { syncMotion(animated: false) }
        .onChange(of: isActive) { _, active in
            syncMotion(animated: true, isActive: active)
        }
    }

    private func syncMotion(animated: Bool, isActive active: Bool? = nil) {
        let active = active ?? isActive
        let targetIntensity: CGFloat = active ? 8 : 2
        let targetVolume: CGFloat = active ? 0.28 : 0.04

        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                intensity = targetIntensity
                volume = targetVolume
            }
        } else {
            intensity = targetIntensity
            volume = targetVolume
        }
    }
}

/// UIKit bridge — keeps `LimiOrbScene` in sync when `LimiOrbSceneState` changes.
struct LimiOrbSceneController: View {
    @ObservedObject var state: LimiOrbSceneState

    var body: some View {
        LimiOrbScene(isActive: state.isActive, size: state.size)
    }
}

struct OrbShowcase: View {
    @State private var intensity: CGFloat = 3
    @State private var volume: CGFloat = 0.2
    var body: some View {
        VStack(spacing: 16) {
            OrbView(intensity: $intensity, currentVolume: $volume)
                .frame(width: 300, height: 300)
                .background(Color.clear)
            Text("Animation Intensity:")
                .foregroundColor(.appTextPrimary)
            Slider(value: $intensity, in: 0.5...120, step: 0.5)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.themeBlack.edgesIgnoringSafeArea(.all))
    }
}

#Preview {
    OrbShowcase().preferredColorScheme(.dark)
}

