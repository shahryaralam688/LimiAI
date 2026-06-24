//
//  RoomPlanUploadServiceTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class RoomPlanUploadServiceTests: XCTestCase {

    func testBuildMultipartBodyIncludesFileAndMetadata() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-scan-\(UUID().uuidString).usdz")
        let payload = Data("usdz-test".utf8)
        try payload.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let body = try RoomPlanUploadService.buildMultipartBody(
            fileURL: tempURL,
            metadata: ["name": "Living Room"],
            boundary: "test-boundary"
        )

        let text = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("test-boundary"))
        XCTAssertTrue(text.contains("filename=\"\(tempURL.lastPathComponent)\""))
        XCTAssertTrue(text.contains("metadata[name]"))
        XCTAssertTrue(text.contains("Living Room"))
        XCTAssertTrue(body.contains(payload))
    }
}
