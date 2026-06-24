//
//  RoomCaptureViewModelTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

@MainActor
final class RoomCaptureViewModelTests: XCTestCase {

    func testResetScanStateClearsFlags() {
        let viewModel = RoomCaptureViewModel()
        viewModel.showSaveButton = true
        viewModel.isScanComplete = true
        viewModel.uploadError = "failed"

        viewModel.resetScanState()

        XCTAssertFalse(viewModel.showSaveButton)
        XCTAssertFalse(viewModel.isScanComplete)
        XCTAssertNil(viewModel.uploadError)
    }

    func testMarkScanCompleteSetsSaveUI() {
        let viewModel = RoomCaptureViewModel()

        viewModel.markScanComplete()

        XCTAssertTrue(viewModel.showSaveButton)
        XCTAssertTrue(viewModel.isScanComplete)
    }
}
