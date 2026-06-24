//
//  LightControllingSocketAuthPolicyTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class LightControllingSocketAuthPolicyTests: XCTestCase {

    func testShouldRebuildWhenTokenChanges() {
        XCTAssertTrue(
            LightControllingSocketAuthPolicy.shouldRebuildSocket(
                lastToken: "old-token",
                currentToken: "new-token"
            )
        )
    }

    func testShouldNotRebuildWhenTokenUnchanged() {
        XCTAssertFalse(
            LightControllingSocketAuthPolicy.shouldRebuildSocket(
                lastToken: "same-token",
                currentToken: "same-token"
            )
        )
    }

    func testShouldForceDisconnectWhenTokenEmpty() {
        XCTAssertTrue(LightControllingSocketAuthPolicy.shouldForceDisconnect(token: ""))
    }

    func testShouldNotForceDisconnectWhenTokenPresent() {
        XCTAssertFalse(LightControllingSocketAuthPolicy.shouldForceDisconnect(token: "jwt"))
    }
}
