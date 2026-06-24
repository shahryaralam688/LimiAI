//
//  CatalogItem.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation
import CoreGraphics

struct CatalogItem: Identifiable, Codable {
    let id: String
    var name: String
    var category: String
    var size: CGSize
    var iconName: String
    var modelName: String?
}
