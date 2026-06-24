//
//  ProductARView.swift
//  IKEA_NC1
//
//  Created by Federica Mosca on 23/11/23.
//

import SwiftUI
import RealityKit
import ARKit 

struct ProductARView: View {
    
    var card: Card
    
    var body: some View {
        
        ARContainerWithOverlay(card: card)
            .onAppear {
                print("TestARView appeared")
            }
            .onDisappear {
                print("TestARView disappeared")
            }
            
    }
    func addAnchorForModel(card: Card, arView: ARView) {
        guard let modelEntity = ConfiguratorModelStore.loadEntity(
            downloadId: card.objectName,
            bundledName: card.objectName
        ) else {
            print("❌ Failed to load model for: \(card.objectName)")
            return
        }

        var position: SIMD3<Float> = .zero

        if card.description.contains("floor") {
            position = SIMD3<Float>(0, 0, 0)
        } else if card.description.contains("wall") {
            position = SIMD3<Float>(0, 1.5, -1)
        } else {
            position = SIMD3<Float>(0, 2.5, 0)
        }

        // ✅ FIX: Proper scale
        modelEntity.transform = Transform(
            scale: SIMD3<Float>(1, 1, 1),
            rotation: simd_quatf(),
            translation: position
        )

        let anchor = AnchorEntity()
        anchor.addChild(modelEntity)
        
        arView.scene.addAnchor(anchor)
    }


}

