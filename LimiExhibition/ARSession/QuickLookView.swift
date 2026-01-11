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

            let fileManager = FileManager.default

            // 1. Check Documents/Configurator for downloaded model
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let folderURL = documentsURL.appendingPathComponent("Configurator")
            let downloadedURL = folderURL.appendingPathComponent("\(parent.card.objectName).usdz")

            // 2. Fallback to bundled model
            let bundledURL = Bundle.main.url(
                forResource: parent.card.objectName,
                withExtension: "usdz",
                subdirectory: "art.scnassets"
            )

            let modelURL: URL? = fileManager.fileExists(atPath: downloadedURL.path)
                ? downloadedURL
                : bundledURL

            guard let finalURL = modelURL else {
                print("❌ Model not found: \(parent.card.objectName)")
                return QLPreviewItemDummy()
            }

            print("📦 Loading model for QuickLook:", finalURL.path)
            // NSURL already conforms to QLPreviewItem
            return finalURL as NSURL
        }
    }
}

// Dummy item to prevent crashes
class QLPreviewItemDummy: NSObject, QLPreviewItem {
    var previewItemURL: URL? = URL(fileURLWithPath: "/dev/null")
}
