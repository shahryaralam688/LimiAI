//
//  DownloadedModelARView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//


//  DownloadedModelARView.swift
//  Limi
//
//  Created by ChatGPT on 07/07/2025.

import SwiftUI
import RealityKit
import ARKit
import QuickLook

struct DownloadedModelARView: View {
    let modelFileName: String // only file name, e.g., "686b727ca0be428d93add965.usdz"

    var body: some View {
        ARQuickLookViewCon(downloadId: modelFileName)
            .ignoresSafeArea()
    }
}

struct ARQuickLookViewCon: UIViewControllerRepresentable {
    var downloadId: String

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Update the controller if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var parent: ARQuickLookViewCon

        init(_ parent: ARQuickLookViewCon) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            let fileManager = FileManager.default
            let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let modelURL = cachesURL.appendingPathComponent("\(parent.downloadId).usdz")
            return ARQuickLookPreviewItem(fileAt: modelURL)
        }
    }
}
