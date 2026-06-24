//
//  ProjectStorage.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation

final class ProjectStorage {
    static let shared = ProjectStorage()

    private let key = "projects_storage"

    func load() -> [Project] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([Project].self, from: data)) ?? []
    }

    func save(_ projects: [Project]) {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
