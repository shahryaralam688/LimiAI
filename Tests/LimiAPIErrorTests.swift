//
//  LimiAPIErrorTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class LimiAPIErrorTests: XCTestCase {

    func testFromHTTPStatusParsesErrorMessageKey() {
        let data = Data("{\"error_message\":\"Unauthorized\"}".utf8)
        let error = LimiAPIError.from(httpStatus: 401, data: data)

        XCTAssertEqual(error, .httpStatus(401, message: "Unauthorized"))
        XCTAssertEqual(error.errorDescription, "Request failed (HTTP 401): Unauthorized")
    }

    func testFromHTTPStatusParsesMessageKey() {
        let data = Data("{\"message\":\"Not found\"}".utf8)
        let error = LimiAPIError.from(httpStatus: 404, data: data)

        XCTAssertEqual(error, .httpStatus(404, message: "Not found"))
    }

    func testFromHTTPStatusFallsBackToPlainTextBody() {
        let data = Data("Service unavailable".utf8)
        let error = LimiAPIError.from(httpStatus: 503, data: data)

        XCTAssertEqual(error, .httpStatus(503, message: "Service unavailable"))
    }

    func testFromURLErrorMapsTransport() {
        let urlError = URLError(.notConnectedToInternet)
        let error = LimiAPIError.from(urlError)

        XCTAssertEqual(error, .transport(.notConnectedToInternet))
    }

    func testFromLimiHTTPClientErrorMapsMissingAuth() {
        let error = LimiAPIError.from(LimiHTTPClientError.missingAuth)

        XCTAssertEqual(error, .missingAuth)
        XCTAssertEqual(error.errorDescription, "Authentication required.")
    }

    func testFromUnknownErrorWrapsBackendMessage() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "Something broke" }
        }

        let error = LimiAPIError.from(SampleError())

        XCTAssertEqual(error, .backend(message: "Something broke"))
    }
}
