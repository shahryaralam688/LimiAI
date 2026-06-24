//
//  Project.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation

struct Project: Identifiable, Codable {
    let id: String
    var name: String
    var rooms: [Room]
}
