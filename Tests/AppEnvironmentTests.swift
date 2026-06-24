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

    func testGetStartViewModelUsesMockInstallerLogin() {
        var login = MockInstallerLoginService()
        login.result = .success(())
        var env = AppEnvironment.mock
        env.installerLogin = login

        let viewModel = GetStartViewModel(environment: env)
        let expectation = expectation(description: "installer login")

        viewModel.continueWithRole(GetStart.Role.deafOrHardOfHearing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(viewModel.activeAuthRoute, .installerHome)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
