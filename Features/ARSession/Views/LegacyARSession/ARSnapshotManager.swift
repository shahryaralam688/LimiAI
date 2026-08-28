import UIKit

/// Handles capturing a screenshot of the current window and saving it
/// both to a local "AR Experience" folder and to the Photos library.
final class ARSnapshotManager {
    static let shared = ARSnapshotManager()
    private init() {}

    func captureScreen() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        saveImage(image)
    }

    private func saveImage(_ image: UIImage) {
        // 1) Save into app Documents/"AR Experience"
        let fileManager = FileManager.default
        do {
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            guard let docs else {
                return
            }
            let folderURL = docs.appendingPathComponent("AR Experience", isDirectory: true)

            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let fileName = "AR_Experience_\(formatter.string(from: Date())).png"
            let fileURL = folderURL.appendingPathComponent(fileName)

            if let pngData = image.pngData() {
                try pngData.write(to: fileURL)
                showThumbnailPreview(image)
            }
        } catch { /* ignored */ }

        // 2) Save into Photos gallery
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    // MARK: - iOS-style thumbnail preview
    private func showThumbnailPreview(_ image: UIImage) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow })
            else { return }

            let thumbnailSize: CGFloat = 120
            let margin: CGFloat = 16

            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            imageView.layer.borderColor = UIColor.appWhite.withAlphaComponent(0.8).cgColor
            imageView.layer.borderWidth = 1

            // Start slightly off-screen bottom-left, animate in
            let startFrame = CGRect(
                x: margin,
                y: window.bounds.height + thumbnailSize, // below screen
                width: thumbnailSize,
                height: thumbnailSize * 1.2
            )

            let endFrame = CGRect(
                x: margin,
                y: window.bounds.height - thumbnailSize * 1.2 - margin,
                width: thumbnailSize,
                height: thumbnailSize * 1.2
            )

            imageView.frame = startFrame
            imageView.alpha = 0
            window.addSubview(imageView)

            // Slide up + fade in
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
                imageView.frame = endFrame
                imageView.alpha = 1
            }) { _ in
                // Hold for a moment, then move right & fade out (like iOS)
                UIView.animate(withDuration: 0.25, delay: 1.5, options: [.curveEaseIn], animations: {
                    imageView.frame = endFrame.offsetBy(dx: thumbnailSize, dy: 0)
                    imageView.alpha = 0
                }) { _ in
                    imageView.removeFromSuperview()
                }
            }
        }
    }
}
