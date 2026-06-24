//
//  ProjectListViewModel.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation

final class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []

    init() {
        load()
    }

    func load() {
        projects = ProjectStorage.shared.load()
    }

    func addNew() {
        let p = Project(
            id: UUID().uuidString,
            name: "New Project",
            rooms: [
                Room(id: UUID().uuidString,
                     name: "Living Room",
                     size: CGSize(width: 500, height: 400),
                     objects: [])
            ]
        )
        projects.append(p)
        save()
    }

    func save() {
        ProjectStorage.shared.save(projects)
    }
}
