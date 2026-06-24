//
//  RoomObject.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation
import CoreGraphics

struct RoomObject: Identifiable, Codable {
    let id: String
    var catalogId: String
    var position: CGPoint             // x,y on floor in cm
    var rotation: CGFloat
}
