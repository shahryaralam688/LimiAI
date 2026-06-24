//
//  ProjectEditorView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import SwiftUI

struct ProjectEditorView: View {
    @StateObject var vm: ProjectEditorViewModel
    
    private enum ViewMode: String, CaseIterable { case twoD = "2D", threeD = "3D" }
    @State private var mode: ViewMode = .twoD

    init(project: Project) {
        _vm = StateObject(wrappedValue: ProjectEditorViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $mode) {
                ForEach(ViewMode.allCases, id: \.self) { m in
                    Text(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if mode == .twoD {
                VStack(spacing: 8) {
                    RoomPlanView(vm: vm)
                    CatalogPanelView(vm: vm)
                }
            } else {
                Room3DView(room: vm.room, catalog: vm.catalog)
            }
        }
        .navigationTitle(vm.project.name)
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
    return ProjectEditorView(project: sampleProject)
}
