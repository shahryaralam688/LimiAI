//
//  AppEnvironmentTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class AppEnvironmentTests: XCTestCase {

    func testMockAuthProvidesToken() {
        let env = AppEnvironment.mock
        XCTAssertEqual(env.auth.getToken(), "mock-token")
        XCTAssertTrue(env.auth.isAuthenticated)
    }

    func testMockHTTPPerformerRecordsRequests() {
        let http = MockHTTPPerformer()
        var env = AppEnvironment.mock
        env.http = http

        let request = URLRequest(url: URL(string: "https://example.com")!)
        http.perform(request) { _, _, _ in }

        XCTAssertEqual(http.performedRequests.count, 1)
        XCTAssertEqual(http.performedRequests.first?.url?.absoluteString, "https://example.com")
    }
}
