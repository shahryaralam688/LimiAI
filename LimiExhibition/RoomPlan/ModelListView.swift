//
//  ModelListView.swift
//  Limi
//
//  Created by Mac Mini on 20/05/2025.
//


import SwiftUI

/// A SwiftUI view that lists all USDZ files and navigates into your existing FileDetailView
struct ModelListView: View {
    @State private var files: [String] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(files, id: \.self) { file in
                    NavigationLink(destination: ModelEditorView(modelName: file)) {
                        Text(file)
                    }
                }
            }
            .navigationTitle("Edit 3D Models")

            .onAppear(perform: refreshFileList)
        }
    }
    private func refreshFileList() {
        files = RoominatorFileManager.shared.listFiles()
    }

}

struct ModelListView_Previews: PreviewProvider {
    static var previews: some View {
        ModelListView()
    }
}
