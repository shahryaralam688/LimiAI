//
//  Room.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation
import CoreGraphics

struct Room: Identifiable, Codable {
    let id: String
    var name: String
    var size: CGSize                  // width & height in cm
    var objects: [RoomObject]
}
