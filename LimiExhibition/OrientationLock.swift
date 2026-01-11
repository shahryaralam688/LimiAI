//
//  OrientationLock.swift
//  Limi
//
//  Created by Mac Mini on 22/03/2025.
//


import SwiftUI

struct OrientationLock {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
