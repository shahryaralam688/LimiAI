import SwiftUI
import QuickLook

struct ARQuickLookView: UIViewControllerRepresentable {
    var card: Card

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var parent: ARQuickLookView

        init(_ parent: ARQuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            guard let finalURL = ConfiguratorModelStore.previewURL(forSnapId: parent.card.objectName) else {
                print("❌ Model not found: \(parent.card.objectName)")
                return QLPreviewItemDummy()
            }

            print("📦 Loading model for QuickLook:", finalURL.path)
            return finalURL as NSURL
        }
    }
}

// Dummy item to prevent crashes
class QLPreviewItemDummy: NSObject, QLPreviewItem {
    var previewItemURL: URL? = URL(fileURLWithPath: "/dev/null")
}
