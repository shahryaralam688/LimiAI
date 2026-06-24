//
//  LimiAPIError.swift
//  Limi
//
//  Shared API error mapping for LimiHTTPClient async layer.
//

import Foundation

enum LimiAPIError: LocalizedError, Equatable {
    case invalidURL
    case missingAuth
    case invalidBody
    case emptyResponse
    case httpStatus(Int, message: String?)
    case transport(URLError.Code)
    case decoding(String)
    case backend(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .missingAuth:
            return "Authentication required."
        case .invalidBody:
            return "Could not encode request body."
        case .emptyResponse:
            return "Empty server response."
        case .httpStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Request failed (HTTP \(code)): \(message)"
            }
            return "Request failed (HTTP \(code))."
        case .transport(let code):
            return "Network error (\(code.rawValue))."
        case .decoding(let detail):
            return "Could not read server response: \(detail)"
        case .backend(let message):
            return message
        }
    }

    static func == (lhs: LimiAPIError, rhs: LimiAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.missingAuth, .missingAuth),
             (.invalidBody, .invalidBody),
             (.emptyResponse, .emptyResponse):
            return true
        case (.httpStatus(let lc, let lm), .httpStatus(let rc, let rm)):
            return lc == rc && lm == rm
        case (.transport(let lc), .transport(let rc)):
            return lc == rc
        case (.decoding(let ld), .decoding(let rd)):
            return ld == rd
        case (.backend(let lm), .backend(let rm)):
            return lm == rm
        default:
            return false
        }
    }

    static func from(httpStatus statusCode: Int, data: Data?) -> LimiAPIError {
        let message = data.flatMap { parseBackendMessage(from: $0) }
        return .httpStatus(statusCode, message: message)
    }

    static func from(_ error: Error) -> LimiAPIError {
        if let api = error as? LimiAPIError { return api }
        if let client = error as? LimiHTTPClientError {
            switch client {
            case .missingAuth: return .missingAuth
            case .invalidBody: return .invalidBody
            }
        }
        if let urlError = error as? URLError {
            return .transport(urlError.code)
        }
        if let decoding = error as? DecodingError {
            return .decoding(decoding.localizedDescription)
        }
        return .backend(message: error.localizedDescription)
    }

    private static func parseBackendMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let msg = json["error_message"] as? String, !msg.isEmpty { return msg }
        if let msg = json["message"] as? String, !msg.isEmpty { return msg }
        if let msg = json["error"] as? String, !msg.isEmpty { return msg }
        return nil
    }
}
