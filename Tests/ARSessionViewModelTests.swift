//
//  ARSessionViewModelTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

@MainActor
final class ARSessionViewModelTests: XCTestCase {

    private func sampleItem(id: String = "cfg-1", downloadId: String = "snap-1") -> LightConfigItem {
        LightConfigItem(
            id: id,
            name: "Living Room",
            config: LightConfig(
                lightType: "ceiling",
                lightAmount: 4,
                cableColor: "black",
                baseType: "round",
                downloadId: downloadId
            )
        )
    }

    func testDisplayItemsMapsOnlineConfigs() {
        let viewModel = ARSessionViewModel()
        viewModel.items = [sampleItem()]
        viewModel.loadAttempted = true

        XCTAssertEqual(viewModel.displayItems.count, 1)
        XCTAssertEqual(viewModel.displayItems.first?.downloadId, "snap-1")
        XCTAssertFalse(viewModel.displayItems.first?.isPreset == true)
    }

    func testSelectItemUpdatesStateManager() {
        let stateManager = ARModelStateManager.shared
        let viewModel = ARSessionViewModel(stateManager: stateManager)
        let item = ARDisplayItem(id: "cfg-2", name: "Bedroom", downloadId: "snap-2", isPreset: false)

        viewModel.selectItem(item)

        XCTAssertEqual(stateManager.selectedModelId, "cfg-2")
        XCTAssertEqual(stateManager.selectedDownloadId, "snap-2")
        XCTAssertEqual(stateManager.selectedModelName, "Bedroom")
    }

    func testIsUsingPresetsWhenFetchAttemptedWithNoItems() {
        let viewModel = ARSessionViewModel()
        viewModel.loadAttempted = true

        XCTAssertTrue(viewModel.isUsingPresets)
    }
}
