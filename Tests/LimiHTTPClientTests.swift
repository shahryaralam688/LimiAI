//
//  LimiHTTPClientTests.swift
//  LimiTests
//

import XCTest
@testable import LIMI_AI

final class LimiHTTPClientTests: XCTestCase {

    override func tearDown() {
        LimiHTTPClient.resetURLSessionOverride()
        LimiURLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testGetReturns200Data() async throws {
        let url = URL(string: "https://example.test/client/ping")!
        LimiURLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }
        LimiHTTPClient.setURLSessionOverride(LimiURLProtocolStub.makeSession())

        let data = try await LimiHTTPClient.perform(
            urlString: url.absoluteString,
            method: "GET",
            auth: LimiAuthRequirement.none
        )
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"ok\":true}")
    }

    func testPerformMaps401ToLimiAPIError() async {
        let url = URL(string: "https://example.test/client/secure")!
        LimiURLProtocolStub.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error_message\":\"Unauthorized\"}".utf8))
        }
        LimiHTTPClient.setURLSessionOverride(LimiURLProtocolStub.makeSession())

        do {
            _ = try await LimiHTTPClient.perform(
                urlString: url.absoluteString,
                method: "GET",
                auth: LimiAuthRequirement.none
            )
            XCTFail("Expected LimiAPIError.httpStatus")
        } catch let error as LimiAPIError {
            XCTAssertEqual(error, .httpStatus(401, message: "Unauthorized"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDecodeMapsJSON() throws {
        struct Ping: Decodable, Equatable { let ok: Bool }
        let decoded = try LimiHTTPClient.decode(Ping.self, from: Data("{\"ok\":true}".utf8))
        XCTAssertEqual(decoded, Ping(ok: true))
    }
}
