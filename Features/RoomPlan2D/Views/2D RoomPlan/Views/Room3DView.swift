//
//  Room3DView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import SwiftUI
import SceneKit

struct Room3DView: UIViewRepresentable {
    let room: Room
    let catalog: [CatalogItem]

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = SCNScene()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .appWhite
        if let scene = scnView.scene {
            buildScene(in: scene)
        }
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // For now, rebuild scene when room changes
        uiView.scene = SCNScene()
        if let scene = uiView.scene {
            buildScene(in: scene)
        }
    }

    private func buildScene(in scene: SCNScene) {
        // Convert cm to meters for SceneKit (1 unit ≈ 1 m)
        let widthM = room.size.width / 100
        let heightM = room.size.height / 100

        // Floor
        let floorGeom = SCNPlane(width: widthM, height: heightM)
        floorGeom.firstMaterial?.diffuse.contents = UIColor(white: 0.95, alpha: 1.0)
        floorGeom.firstMaterial?.isDoubleSided = true
        let floorNode = SCNNode(geometry: floorGeom)
        floorNode.eulerAngles.x = -.pi / 2 // lay flat
        scene.rootNode.addChildNode(floorNode)

        // Simple ambient + omni light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let light = SCNLight()
        light.type = .omni
        light.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 3, 3)
        scene.rootNode.addChildNode(lightNode)

        // Camera (top-down by default)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(max(widthM, heightM) * 0.8)
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 5, 0)
        cameraNode.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(cameraNode)

        // Objects
        for obj in room.objects {
            guard let item = catalog.first(where: { $0.id == obj.catalogId }) else { continue }

            // Placeholder geometry for now (box). Size from catalog (cm→m)
            let box = SCNBox(
                width: max(item.size.width / 100, 0.05),
                height: 0.3,
                length: max(item.size.height / 100, 0.05),
                chamferRadius: 0.02
            )
            box.firstMaterial?.diffuse.contents = UIColor.systemBrown
            let node = SCNNode(geometry: box)

            // Map 2D (x,y) where origin is top-left in cm to SceneKit (x,z) centered
            let x = (obj.position.x - room.size.width / 2) / 100
            let z = (obj.position.y - room.size.height / 2) / 100
            node.position = SCNVector3(x, box.height / 2, z)
            node.eulerAngles.y = Float(obj.rotation * .pi / 180)

            scene.rootNode.addChildNode(node)
        }
    }
}

#Preview {
    // Minimal preview data
    let room = Room(
        id: "preview-room",
        name: "Living Room",
        size: CGSize(width: 500, height: 400),
        objects: [
            RoomObject(id: "o1", catalogId: "sofa_1", position: CGPoint(x: 250, y: 200), rotation: 0),
            RoomObject(id: "o2", catalogId: "pendant_light", position: CGPoint(x: 150, y: 120), rotation: 45)
        ]
    )
    let catalog = SampleCatalog.items
    return Room3DView(room: room, catalog: catalog)
}
