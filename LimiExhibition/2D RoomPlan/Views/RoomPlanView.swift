                                                                                                                           //
//  RoomPlanView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import SwiftUI

struct RoomPlanView: View {
    @ObservedObject var vm: ProjectEditorViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().stroke()

                ForEach(vm.room.objects) { obj in
                    let catalog = vm.catalog.first { $0.id == obj.catalogId }
                    let pos = CGPoint(
                        x: geo.size.width * obj.position.x / vm.room.size.width,
                        y: geo.size.height * obj.position.y / vm.room.size.height
                    )

                    Image(catalog?.iconName ?? "questionmark")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .position(pos)
                        .gesture(
                            DragGesture()
                                .onChanged { g in
                                    let newPos = CGPoint(
                                        x: vm.room.size.width * g.location.x / geo.size.width,
                                        y: vm.room.size.height * g.location.y / geo.size.height
                                    )
                                    vm.moveObject(obj.id, to: newPos)
                                }
                        )
                }
            }
        }
        .padding()
    }
}
#Preview {
    let sampleProject = Project(
        id: "preview-project",
        name: "Preview Project",
        rooms: [
            Room(
                id: "preview-room",
                name: "Living Room",
                size: CGSize(width: 500, height: 400),
                objects: []
            )
        ]
    )
    let vm = ProjectEditorViewModel(project: sampleProject)
    return RoomPlanView(vm: vm)
}
