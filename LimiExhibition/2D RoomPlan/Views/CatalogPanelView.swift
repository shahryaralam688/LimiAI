//
//  CatalogPanelView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import SwiftUI

struct CatalogPanelView: View {
    @ObservedObject var vm: ProjectEditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(vm.catalog) { item in
                    VStack {
                        Image(item.iconName)
                            .resizable()
                            .frame(width: 50, height: 50)
                        Text(item.name).font(.caption)
                    }
                    .onTapGesture {
                        vm.addObject(item)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
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
    return CatalogPanelView(vm: vm)
}
