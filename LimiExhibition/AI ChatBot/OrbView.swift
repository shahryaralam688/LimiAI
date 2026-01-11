//  OrbView.swift
//  Aura
//
//  Created by Mac Mini on 19/09/2025.
//

import SwiftUI
import SceneKit
import AVFoundation
import UIKit

struct OrbView: UIViewRepresentable {
    @Binding var intensity: CGFloat
    @Binding var currentVolume: CGFloat
    private let edgeRetentionRatio: Double = 0.8
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling4X
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = 22
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 1000
        cameraNode.position = SCNVector3(0, 0, 50)
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
        let (vertices, edges) = buildGeodesicData(radius: 10, frequency: 3)
        let orbNode = buildEdgeNode(vertices: vertices, edges: edges, sphereRadius: 10)
        orbNode.name = "orb"
        sceneView.scene?.rootNode.addChildNode(orbNode)
        
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.toValue = NSValue(scnVector4: SCNVector4(0.3, 1.0, 0.1, Float.pi * 2))
        rotation.duration = 60
        rotation.repeatCount = .infinity
        orbNode.addAnimation(rotation, forKey: "rotate")
        
        context.coordinator.orbNode = orbNode
        context.coordinator.sceneView = sceneView
        context.coordinator.startDisplayLink()
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.volume = currentVolume
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var orbNode: SCNNode?
        var sceneView: SCNView?
        var displayLink: CADisplayLink?
        var intensity: CGFloat = 3
        var volume: CGFloat = 0
        private var currentRadius: CGFloat = 10
        
        func startDisplayLink() {
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .default)
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

    private func buildEdgeNode(vertices: [SCNVector3], edges: [Edge], sphereRadius: CGFloat) -> SCNNode {
        let parent = SCNNode()
        let thickness: CGFloat = max(0.10, sphereRadius * 0.010)
        let material = flatMaterial()
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

    private func flatMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.diffuse.contents = UIColor(white: 0.45, alpha: 1.0)
        mat.emission.contents = UIColor(white: 0.45, alpha: 1.0)
        return mat
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

struct OrbShowcase: View {
    @State private var intensity: CGFloat = 3
    @State private var volume: CGFloat = 0.2
    var body: some View {
        VStack(spacing: 16) {
            OrbView(intensity: $intensity, currentVolume: $volume)
                .frame(width: 300, height: 300)
                .background(Color.clear)
            Text("Animation Intensity:")
                .foregroundColor(.white)
            Slider(value: $intensity, in: 0.5...120, step: 0.5)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

#Preview {
    OrbShowcase().preferredColorScheme(.dark)
}

