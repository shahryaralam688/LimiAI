//
//  FileDetailView.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import SwiftUI
import QuickLook
import UIKit

struct NativeQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }

        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            print("QuickLook view dismissed.")
        }
    }
}

import SwiftUI
import SceneKit

struct FileDetailView: View {
    let fileName: String
    @Environment(RoomCaptureController.self) private var captureController
    @State private var showModelEditor = false
    
    var body: some View {
        VStack {
            Text(fileName)
                .font(.title)
                .padding()
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    showModelEditor = true
                }) {
                    VStack {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 30))
                        Text("View 3D Model")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    // Analyze the USDZ file and print dimensions
                    captureController.analyzeUSDZFile(fileName)
                }) {
                    VStack {
                        Image(systemName: "ruler")
                            .font(.system(size: 30))
                        Text("Analyze Dimensions")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .fullScreenCover(isPresented: $showModelEditor) {
//            ModelEditorView(modelName: fileName)

        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
