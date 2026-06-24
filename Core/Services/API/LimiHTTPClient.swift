//
//  LimiHTTPClient.swift
//  Limi
//
//  Thin shared helper for authenticated Limi backend requests.
//

import Foundation

/// How the backend expects the `Authorization` header on a given route.
enum LimiAuthHeaderStyle {
    /// Raw JWT from Keychain (legacy — prefer `.bearer` for new routes).
    case rawToken
    /// `Bearer <token>` via `AuthManager.authorizationHeaderValue()`.
    case bearer
}

/// Whether a request needs auth, or should attach it only when available.
enum LimiAuthRequirement {
    case none
    /// Raw JWT for `limi-ai/webhook` only (no `Bearer` prefix).
    case webhook
    case required(LimiAuthHeaderStyle)
    case optional(LimiAuthHeaderStyle)

    static var requiredBearer: LimiAuthRequirement { .required(.bearer) }
    static var optionalBearer: LimiAuthRequirement { .optional(.bearer) }

    /// Legacy alias — maps to Bearer per Phase C policy.
    static var requiredRaw: LimiAuthRequirement { .requiredBearer }
    static var optionalRaw: LimiAuthRequirement { .optionalBearer }
}

enum LimiHTTPClient {

    #if DEBUG
    /// Injected session for unit tests (`LimiHTTPClientTests`).
    internal static var debugURLSessionOverride: URLSession?
    internal static func setURLSessionOverride(_ session: URLSession) {
        debugURLSessionOverride = session
    }
    internal static func resetURLSessionOverride() {
        debugURLSessionOverride = nil
    }
    #endif

    private static var urlSession: URLSession {
        #if DEBUG
        if let override = debugURLSessionOverride { return override }
        #endif
        return .shared
    }

    /// Raw token for `limi-ai/webhook` (no `Bearer` prefix).
    static func webhookAuthValue() -> String? {
        guard let raw = AuthManager.shared.getToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().hasPrefix("bearer ") {
            return String(raw.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    /// Builds a request using `LimiAPIAuthPolicy` when `auth` is nil.
    static func buildRequest(
        url: URL,
        method: String = "GET",
        auth: LimiAuthRequirement? = nil,
        contentType: String? = "application/json"
    ) -> URLRequest? {
        let resolved = auth ?? LimiAPIAuthPolicy.requirement(for: url.absoluteString, method: method)
        return buildRequest(url: url, method: method, auth: resolved, contentType: contentType)
    }

    static func buildRequest(
        urlString: String,
        method: String = "GET",
        auth: LimiAuthRequirement? = nil,
        contentType: String? = "application/json"
    ) -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }
        return buildRequest(url: url, method: method, auth: auth, contentType: contentType)
    }

    /// Builds a request with an explicit auth requirement.
    static func buildRequest(
        url: URL,
        method: String,
        auth: LimiAuthRequirement,
        contentType: String?
    ) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        switch auth {
        case .none:
            return request
        case .webhook:
            guard let value = webhookAuthValue() else { return nil }
            request.setValue(value, forHTTPHeaderField: "Authorization")
            return request
        case .required(let style):
            guard let value = authorizationValue(for: style) else { return nil }
            request.setValue(value, forHTTPHeaderField: "Authorization")
            return request
        case .optional(let style):
            if let value = authorizationValue(for: style) {
                request.setValue(value, forHTTPHeaderField: "Authorization")
            }
            return request
        }
    }

    /// Backward-compatible helper used in Phase A call sites.
    static func authenticatedRequest(
        url: URL,
        method: String = "GET",
        authStyle: LimiAuthHeaderStyle = .bearer,
        requiresAuth: Bool = true
    ) -> URLRequest? {
        if requiresAuth {
            return buildRequest(url: url, method: method, auth: .required(authStyle))
        }
        return buildRequest(url: url, method: method, auth: .none)
    }

    static func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        urlSession.dataTask(with: request) { data, response, error in
            completion(data, response as? HTTPURLResponse, error)
        }.resume()
    }

    /// Raw transport — does not validate HTTP status.
    static func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LimiAPIError.emptyResponse
            }
            return (data, http)
        } catch {
            throw LimiAPIError.from(error)
        }
    }

    /// Validates 2xx and returns body; throws `LimiAPIError` otherwise.
    static func perform(
        urlString: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        auth: LimiAuthRequirement? = nil
    ) async throws -> Data {
        guard let request = try buildValidatedRequest(
            urlString: urlString,
            method: method,
            body: body,
            auth: auth
        ) else {
            throw LimiAPIError.missingAuth
        }
        let (data, http) = try await data(for: request)
        guard (200 ... 299).contains(http.statusCode) else {
            throw LimiAPIError.from(httpStatus: http.statusCode, data: data)
        }
        return data
    }

    static func get(
        urlString: String,
        auth: LimiAuthRequirement? = nil
    ) async throws -> Data {
        try await perform(urlString: urlString, method: "GET", auth: auth)
    }

    static func postJSON(
        urlString: String,
        body: [String: Any],
        auth: LimiAuthRequirement? = nil
    ) async throws -> Data {
        try await perform(urlString: urlString, method: "POST", body: body, auth: auth)
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw LimiAPIError.from(error)
        }
    }

    private static func buildValidatedRequest(
        urlString: String,
        method: String,
        body: [String: Any]?,
        auth: LimiAuthRequirement?
    ) throws -> URLRequest? {
        guard let url = URL(string: urlString) else {
            throw LimiAPIError.invalidURL
        }
        guard var request = buildRequest(url: url, method: method, auth: auth) else {
            return nil
        }
        if let body {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                throw LimiAPIError.invalidBody
            }
            request.httpBody = jsonData
        }
        return request
    }

    static func get(
        urlString: String,
        auth: LimiAuthRequirement? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        guard let url = URL(string: urlString),
              let request = buildRequest(url: url, method: "GET", auth: auth) else {
            completion(nil, nil, LimiAPIError.missingAuth)
            return
        }
        perform(request, completion: completion)
    }

    static func postJSON(
        urlString: String,
        body: [String: Any],
        auth: LimiAuthRequirement? = nil,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        guard let url = URL(string: urlString),
              var request = buildRequest(url: url, method: "POST", auth: auth) else {
            completion(nil, nil, LimiAPIError.missingAuth)
            return
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil, LimiAPIError.invalidBody)
            return
        }

        request.httpBody = jsonData
        perform(request, completion: completion)
    }

    static func download(
        urlString: String,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil, nil, URLError(.badURL))
            return
        }
        let request = URLRequest(url: url)
        perform(request, completion: completion)
    }

    private static func authorizationValue(for style: LimiAuthHeaderStyle) -> String? {
        switch style {
        case .rawToken:
            guard let token = AuthManager.shared.getToken(), !token.isEmpty else { return nil }
            return token
        case .bearer:
            return AuthManager.shared.authorizationHeaderValue()
        }
    }
}

enum LimiHTTPClientError: LocalizedError {
    case missingAuth
    case invalidBody

    var errorDescription: String? {
        switch self {
        case .missingAuth: return LimiAPIError.missingAuth.errorDescription
        case .invalidBody: return LimiAPIError.invalidBody.errorDescription
        }
    }
}
