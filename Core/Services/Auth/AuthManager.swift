import Foundation
import Security

extension Notification.Name {
    /// Posted when the auth token is saved or cleared (login, logout, refresh).
    static let limiAuthSessionDidChange = Notification.Name("limiAuthSessionDidChange")
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false

    private let tokenKey = "authToken"
    private let expiryKey = "authTokenExpiry"
    private let roleKey = "authRole"

    init() {
        migrateTokenFromUserDefaultsIfNeeded()
        self.isAuthenticated = isTokenValid()
    }

    func saveToken(_ token: String, expiryInSeconds: TimeInterval = 600000, updateAuthState: Bool = true) {
        let expiryTime = Date().timeIntervalSince1970 + expiryInSeconds

        AuthTokenKeychain.save(token, account: tokenKey)
        UserDefaults.standard.set(expiryTime, forKey: expiryKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)

        #if DEBUG
        #endif

        if updateAuthState {
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
        }

        NotificationCenter.default.post(name: .limiAuthSessionDidChange, object: nil)
    }

    // MARK: - Role Persistence
    func saveRole(_ role: String) {
        UserDefaults.standard.set(role, forKey: roleKey)
        UserDefaults.standard.synchronize()
        #if DEBUG
        #endif
    }

    func getRole() -> String? {
        UserDefaults.standard.string(forKey: roleKey)
    }

    func getToken() -> String? {
        if isTokenValid() {
            return AuthTokenKeychain.read(account: tokenKey)
        } else {
            clearToken()
            return nil
        }
    }

    /// Standard `Authorization` header for Limi REST API calls (`Bearer <jwt>`).
    /// Use via `LimiHTTPClient` / `LimiAPIAuthPolicy` — do not set headers manually.
    func authorizationHeaderValue() -> String? {
        guard let raw = getToken() else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            return trimmed
        }
        return "Bearer \(trimmed)"
    }

    /// Stable per-account key for phone-local caches (virtual devices, removed devices, etc.).
    func sessionCacheKey() -> String {
        guard let token = getToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return ""
        }
        if let subject = Self.jwtSubject(from: token) {
            return subject
        }
        return "token-\(token.hashValue)"
    }

    private static func jwtSubject(from token: String) -> String? {
        let raw = token.hasPrefix("Bearer ") ? String(token.dropFirst(7)) : token
        let parts = raw.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        for key in ["sub", "userId", "user_id", "id", "_id"] {
            if let value = json[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let value = json[key] as? Int {
                return String(value)
            }
        }
        return nil
    }

    func isTokenValid() -> Bool {
        let expiryTime = UserDefaults.standard.double(forKey: expiryKey)
        let currentTime = Date().timeIntervalSince1970

        guard expiryTime > currentTime else {
            #if DEBUG
            #endif
            clearToken()
            return false
        }

        guard AuthTokenKeychain.read(account: tokenKey) != nil else {
            clearToken()
            return false
        }

        return true
    }

    func clearToken() {
        AuthTokenKeychain.delete(account: tokenKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)

        RoominatorFileManager.shared.deleteAllScans()

        DispatchQueue.main.async {
            self.isAuthenticated = false
        }

        #if DEBUG
        #endif

        NotificationCenter.default.post(name: .limiAuthSessionDidChange, object: nil)
    }

    func clearRole() {
        UserDefaults.standard.removeObject(forKey: roleKey)
    }

    // MARK: - One-time migration

    private func migrateTokenFromUserDefaultsIfNeeded() {
        guard AuthTokenKeychain.read(account: tokenKey) == nil else { return }
        guard let legacyToken = UserDefaults.standard.string(forKey: tokenKey),
              !legacyToken.isEmpty else { return }

        AuthTokenKeychain.save(legacyToken, account: tokenKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

// MARK: - Keychain (token only)

private enum AuthTokenKeychain {
    private static let service = Bundle.main.bundleIdentifier ?? "osi.shahryar.LimitLess.Exhibition.v1"

    static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
