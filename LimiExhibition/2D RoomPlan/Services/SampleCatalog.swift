//
//  SampleCatalog.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation
import CoreGraphics

struct SampleCatalog {
    static let items: [CatalogItem] = [
        CatalogItem(id: "sofa_1",
                    name: "Sofa",
                    category: "Furniture",
                    size: CGSize(width: 200, height: 90),
                    iconName: "sofa_icon",
                    modelName: "sofa_1"),

        CatalogItem(id: "pendant_light",
                    name: "Pendant Light",
                    category: "Light",
                    size: CGSize(width: 30, height: 30),
                    iconName: "pendant_icon",
                    modelName: "pendant_light")
    ]
}
