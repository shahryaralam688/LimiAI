//
//  ProjectListView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 07/01/2026.
//


import SwiftUI

struct ProjectListView: View {
    @StateObject private var vm = ProjectListViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.projects) { project in
                    NavigationLink(project.name) {
                        ProjectEditorView(project: project)
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                Button(action: vm.addNew) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
#Preview {
    ProjectListView()
}
