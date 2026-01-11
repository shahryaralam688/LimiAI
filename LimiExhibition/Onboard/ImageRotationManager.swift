//
//  ImageRotationManager.swift
//  Limi
//
//  Created by Mac Mini on 20/03/2025.
//
import SwiftUI

class ImageRotationManager: ObservableObject {
    @Published var currentIndex = 0
    private var timer: Timer?

    
    
    let images = ["name1", "name2", "name3"]

    init() {
        startImageRotation()
    }

    func startImageRotation() {
        stopImageRotation() // Stop any existing timer before starting a new one
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.currentIndex = (self.currentIndex + 1) % self.images.count
            }
        }
    }

    func stopImageRotation() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopImageRotation() // Ensure timer is stopped when the object is deallocated
    }
}
