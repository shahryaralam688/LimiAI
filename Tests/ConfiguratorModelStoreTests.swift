//
//  ConfiguratorModelStoreTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class ConfiguratorModelStoreTests: XCTestCase {

    private let snapId = "test-snap-\(UUID().uuidString)"

    override func tearDown() {
        let url = ConfiguratorModelStore.url(forSnapId: snapId)
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    func testURLNormalizesUSDZSuffix() {
        let withSuffix = ConfiguratorModelStore.url(forSnapId: "\(snapId).usdz")
        let withoutSuffix = ConfiguratorModelStore.url(forSnapId: snapId)

        XCTAssertEqual(withSuffix.lastPathComponent, withoutSuffix.lastPathComponent)
        XCTAssertTrue(withSuffix.lastPathComponent.hasSuffix(".usdz"))
    }

    func testDirectoryURLUsesConfiguratorFolder() {
        let directory = ConfiguratorModelStore.directoryURL()

        XCTAssertTrue(directory.path.hasSuffix("Configurator"))
    }

    func testSaveCreatesFileInConfiguratorDirectory() throws {
        let payload = Data("fake-usdz".utf8)
        try ConfiguratorModelStore.save(payload, forSnapId: snapId)

        XCTAssertTrue(ConfiguratorModelStore.fileExists(forSnapId: snapId))
        let saved = try Data(contentsOf: ConfiguratorModelStore.url(forSnapId: snapId))
        XCTAssertEqual(saved, payload)
    }

    func testResolveModelURLPrefersDownloadedFile() throws {
        let payload = Data("downloaded-model".utf8)
        try ConfiguratorModelStore.save(payload, forSnapId: snapId)

        let resolved = ConfiguratorModelStore.resolveModelURL(
            downloadId: snapId,
            bundledName: "missing-bundle"
        )

        XCTAssertEqual(resolved, ConfiguratorModelStore.resolvedURL(forSnapId: snapId))
    }

    func testMigrateFromCachesIfNeededMovesLegacyFile() throws {
        let destination = ConfiguratorModelStore.url(forSnapId: snapId)
        try? FileManager.default.removeItem(at: destination)

        guard let cachesURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            XCTFail("Caches directory unavailable")
            return
        }

        let legacyURL = cachesURL.appendingPathComponent(destination.lastPathComponent)
        try Data("legacy-cache".utf8).write(to: legacyURL)
        defer { try? FileManager.default.removeItem(at: legacyURL) }

        _ = ConfiguratorModelStore.resolvedURL(forSnapId: snapId)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }
}
