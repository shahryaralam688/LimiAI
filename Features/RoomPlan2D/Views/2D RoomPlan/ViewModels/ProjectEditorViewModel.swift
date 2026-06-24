//
//  ProjectEditorViewModel.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import Foundation
import CoreGraphics

final class ProjectEditorViewModel: ObservableObject {
    @Published var project: Project
    @Published var selectedRoomIndex: Int = 0
    @Published var selectedObjectID: String?

    var catalog = SampleCatalog.items

    init(project: Project) {
        self.project = project
    }

    var room: Room {
        project.rooms[selectedRoomIndex]
    }

    func addObject(_ item: CatalogItem) {
        var obj = RoomObject(id: UUID().uuidString,
                             catalogId: item.id,
                             position: CGPoint(x: room.size.width/2,
                                               y: room.size.height/2),
                             rotation: 0)
        project.rooms[selectedRoomIndex].objects.append(obj)
    }

    func moveObject(_ id: String, to pos: CGPoint) {
        guard let index = project.rooms[selectedRoomIndex].objects.firstIndex(where: { $0.id == id }) else { return }
        project.rooms[selectedRoomIndex].objects[index].position = pos
    }
}
