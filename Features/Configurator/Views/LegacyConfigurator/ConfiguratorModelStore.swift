import Foundation
import RealityKit

/// Canonical on-disk location for configurator-downloaded USDZ models.
enum ConfiguratorModelStore {
    private static let folderName = "Configurator"
    static let defaultAssetsSubdirectory = "art.scnassets"
    /// RealityKit load order. Complete `.usdz` packages win over composition `.usda`.
    static let bundledModelExtensions = ["usdz", "usda", "usd", "usdc", "reality"]

    static func directoryURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    static func url(forSnapId snapId: String) -> URL {
        let normalized = snapId.hasSuffix(".usdz") ? String(snapId.dropLast(5)) : snapId
        return directoryURL().appendingPathComponent("\(normalized).usdz")
    }

    static func ensureDirectoryExists() throws {
        let folderURL = directoryURL()
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    static func fileExists(forSnapId snapId: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forSnapId: snapId).path)
    }

    /// Resolves the canonical URL after moving any legacy cache copy.
    static func resolvedURL(forSnapId snapId: String) -> URL {
        migrateFromCachesIfNeeded(forSnapId: snapId)
        return url(forSnapId: snapId)
    }

    /// Persists downloaded USDZ bytes to `Documents/Configurator/`.
    static func save(_ data: Data, forSnapId snapId: String) throws {
        try ensureDirectoryExists()
        try data.write(to: url(forSnapId: snapId))
    }

    /// One-time move from legacy `Caches/{id}.usdz` into `Documents/Configurator/`.
    static func migrateFromCachesIfNeeded(forSnapId snapId: String) {
        let destinationURL = url(forSnapId: snapId)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else { return }
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let legacyURL = cachesURL.appendingPathComponent(destinationURL.lastPathComponent)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        do {
            try ensureDirectoryExists()
            try FileManager.default.moveItem(at: legacyURL, to: destinationURL)
        } catch { /* ignored */ }
    }

    // MARK: - Safe AR model loading

    static func bundledModelURL(
        name: String,
        subdirectory: String = defaultAssetsSubdirectory
    ) -> URL? {
        for ext in bundledModelExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    /// Downloaded file when present, otherwise bundled `bundledName` (usdz, then usda).
    static func resolveModelURL(
        downloadId: String?,
        bundledName: String,
        subdirectory: String = defaultAssetsSubdirectory
    ) -> URL? {
        if let id = downloadId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !id.isEmpty,
           fileExists(forSnapId: id) {
            return resolvedURL(forSnapId: id)
        }
        return bundledModelURL(name: bundledName, subdirectory: subdirectory)
    }

    static func loadEntity(from url: URL) -> Entity? {
        do {
            return try Entity.load(contentsOf: url)
        } catch {
            DeviceConsole.log(
                .home,
                "3D model load FAIL \(url.lastPathComponent): \(error.localizedDescription)"
            )
            return nil
        }
    }

    static func loadEntity(downloadId: String?, bundledName: String) -> Entity? {
        guard let url = resolveModelURL(downloadId: downloadId, bundledName: bundledName) else {
            return nil
        }
        return loadEntity(from: url)
    }

    /// Control-screen load: requested asset first, then the default pendant
    /// so a missing or incomplete hub USDA never blanks the UI.
    static func loadPreviewEntity(downloadId: String?, bundledName: String) -> Entity? {
        if let entity = loadEntity(downloadId: downloadId, bundledName: bundledName) {
            return entity
        }
        let fallback = PendantModelCatalog.unknownDefault
        guard bundledName != fallback else { return nil }
        return loadEntity(downloadId: nil, bundledName: fallback)
    }

    /// Resolved preview URL: downloaded snap when present, otherwise bundled USDZ.
    static func previewURL(forSnapId snapId: String, bundledName: String? = nil) -> URL? {
        let bundled = bundledName ?? snapId
        guard let url = resolveModelURL(downloadId: snapId, bundledName: bundled) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Loads a scaled `ModelEntity` container for AR placement (single load path).
    static func loadPlacementContainer(
        forSnapId snapId: String,
        bundledName: String? = nil,
        visualScale: Float = 2.0
    ) -> ModelEntity? {
        let bundled = bundledName ?? snapId
        guard let loaded = loadEntity(downloadId: snapId, bundledName: bundled) else {
            return nil
        }

        let container = ModelEntity()
        container.name = "ModelContainer_\(snapId)"
        container.addChild(loaded)
        container.transform.scale = SIMD3<Float>(repeating: visualScale)
        return container
    }
}
