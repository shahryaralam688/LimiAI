//
//  LimiAPIAuthPolicy.swift
//  Limi
//
//  Single source of truth for Limi backend Authorization header rules.
//

import Foundation

/// Resolves how each Limi API path should be authenticated.
///
/// **Standard (Phase C):** authenticated REST routes use `Authorization: Bearer <jwt>`.
/// **Exceptions:**
/// - Pre-login routes — no auth
/// - `limi-ai/webhook` — raw JWT (no `Bearer` prefix); use `LimiHTTPClient.webhookAuthValue()`
/// - Socket.IO — raw JWT in connect param `auth` (not this HTTP header)
enum LimiAPIAuthPolicy {

    /// Socket.IO passes the session JWT as connect param `auth` (raw string, not Bearer).
    static let socketConnectUsesRawToken = true

    static func requirement(for urlString: String, method: String = "GET") -> LimiAuthRequirement {
        let path = apiPath(from: urlString)
        let httpMethod = method.uppercased()

        if isPreAuthPath(path) {
            return .none
        }

        if path.contains("limi-ai/webhook") {
            return .webhook
        }

        if path.contains("web-configurator/download") {
            return .none
        }

        if path.contains("admin/products/light-configs/"), !path.contains("check") {
            return .none
        }

        if path.contains("admin/products/users/light-configs/check") {
            return .optionalBearer
        }

        if path == "sendUserPreference" {
            return .optionalBearer
        }

        if path == "client/3d-models" {
            return httpMethod == "POST" ? .optionalBearer : .requiredBearer
        }

        if path.hasPrefix("client/3d-models/") {
            return .requiredBearer
        }

        return .requiredBearer
    }

    // MARK: - Private

    private static func isPreAuthPath(_ path: String) -> Bool {
        matchesAny(path, [
            "client/google/login",
            "client/apple/login",
            "client/installer_user",
            "client/send_otp",
            "client/verify_otp",
            "client/verify_production"
        ])
    }

    private static func apiPath(from urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        var path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty, let host = url.host, host.contains("limitless-lighting") {
            return ""
        }
        return path
    }

    private static func matchesAny(_ path: String, _ candidates: [String]) -> Bool {
        candidates.contains { path == $0 || path.hasSuffix($0) }
    }
}
