//
//  AuthManagerTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class AuthManagerTests: XCTestCase {

    private let tokenKey = "authToken"
    private let expiryKey = "authTokenExpiry"
    private let roleKey = "authRole"

    override func tearDown() {
        let manager = AuthManager()
        manager.clearToken()
        manager.clearRole()
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
        super.tearDown()
    }

    func testSaveAndReadTokenRoundTrip() {
        let manager = AuthManager()
        manager.saveToken("test-jwt-token", expiryInSeconds: 3600, updateAuthState: true)

        XCTAssertEqual(manager.getToken(), "test-jwt-token")
        XCTAssertTrue(manager.isTokenValid())
    }

    func testExpiredTokenReturnsNil() {
        let manager = AuthManager()
        manager.saveToken("expired-token", expiryInSeconds: -10, updateAuthState: false)

        XCTAssertNil(manager.getToken())
        XCTAssertFalse(manager.isTokenValid())
    }

    func testMigratesLegacyTokenFromUserDefaults() {
        UserDefaults.standard.set("legacy-token", forKey: tokenKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + 3600, forKey: expiryKey)

        let manager = AuthManager()

        XCTAssertEqual(manager.getToken(), "legacy-token")
        XCTAssertNil(UserDefaults.standard.string(forKey: tokenKey))
    }

    func testAuthorizationHeaderPrefixesBearer() {
        let manager = AuthManager()
        manager.saveToken("header-token", expiryInSeconds: 3600, updateAuthState: false)

        XCTAssertEqual(manager.authorizationHeaderValue(), "Bearer header-token")
    }

    func testClearTokenClearsAuthenticatedState() {
        let manager = AuthManager()
        manager.saveToken("clear-me", expiryInSeconds: 3600, updateAuthState: true)

        let expectation = expectation(description: "auth cleared")
        manager.clearToken()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(manager.isAuthenticated)
            XCTAssertNil(manager.getToken())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSaveAndReadRole() {
        let manager = AuthManager()
        manager.saveRole("Installer")

        XCTAssertEqual(manager.getRole(), "Installer")
    }
}
