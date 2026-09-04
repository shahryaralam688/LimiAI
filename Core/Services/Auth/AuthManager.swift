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
    private let keychainQueue = DispatchQueue(label: "limi.auth.keychain", qos: .utility)
    /// Set immediately on logout so getToken / sessionCacheKey stop returning
    /// the old JWT before the async Keychain delete finishes.
    private var sessionInvalidated = false
    /// Survives the logout→login race: a pending Keychain delete must not drop
    /// a token we just saved in this process.
    private var memoryToken: String?
    private var keychainGeneration = 0

    init() {
        // Keep init off the main-thread watchdog path: no SecItemDelete, no
        // filesystem wipe. Expired sessions are cleaned lightly / async.
        migrateTokenFromUserDefaultsIfNeeded()
        self.memoryToken = AuthTokenKeychain.read(account: tokenKey)
        self.isAuthenticated = peekTokenValid()
    }

    func saveToken(_ token: String, expiryInSeconds: TimeInterval = 600000, updateAuthState: Bool = true) {
        let expiryTime = Date().timeIntervalSince1970 + expiryInSeconds
        sessionInvalidated = false
        memoryToken = token
        // Invalidate any in-flight logout delete so it cannot erase this login.
        keychainGeneration += 1

        AuthTokenKeychain.save(token, account: tokenKey)
        UserDefaults.standard.set(expiryTime, forKey: expiryKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)

        if updateAuthState {
            let publish: () -> Void = { self.isAuthenticated = true }
            if Thread.isMainThread {
                publish()
            } else {
                DispatchQueue.main.async(execute: publish)
            }
        }

        NotificationCenter.default.post(name: .limiAuthSessionDidChange, object: nil)
    }

    // MARK: - Role Persistence
    func saveRole(_ role: String) {
        UserDefaults.standard.set(role, forKey: roleKey)
        UserDefaults.standard.synchronize()
    }

    func getRole() -> String? {
        UserDefaults.standard.string(forKey: roleKey)
    }

    func getToken() -> String? {
        guard peekTokenValid() else {
            if !sessionInvalidated {
                invalidateSessionLightly(deleteScans: false)
            }
            return nil
        }
        if let memoryToken, !memoryToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return memoryToken
        }
        return AuthTokenKeychain.read(account: tokenKey)
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
    /// Read-only — must not invalidate the session (that stalled splash / flipped auth).
    func sessionCacheKey() -> String {
        guard isTokenValid(),
              let token = (memoryToken ?? AuthTokenKeychain.read(account: tokenKey))?
                .trimmingCharacters(in: .whitespacesAndNewlines),
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

    /// Read-only validity check — never deletes Keychain / scans (safe at launch).
    func isTokenValid() -> Bool {
        peekTokenValid()
    }

    /// Explicit sign-out. Heavy cleanup (Keychain + RoomPlan files) runs off-main.
    func clearToken() {
        invalidateSessionLightly(deleteScans: true)
    }

    func clearRole() {
        UserDefaults.standard.removeObject(forKey: roleKey)
    }

    // MARK: - Private

    /// Expiry + Keychain presence only. No deletes.
    private func peekTokenValid() -> Bool {
        guard !sessionInvalidated else { return false }
        let token = (memoryToken ?? AuthTokenKeychain.read(account: tokenKey))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            return false
        }

        let currentTime = Date().timeIntervalSince1970
        var expiryTime = UserDefaults.standard.double(forKey: expiryKey)

        // Legacy sessions sometimes have a Keychain token but no client expiry
        // (0). Treating that as expired caused Profile to show "token expired"
        // / wipe the session even when the JWT was still good.
        if expiryTime <= 0 {
            if let jwtExp = Self.jwtExpiry(from: token) {
                expiryTime = jwtExp
            } else {
                expiryTime = currentTime + 600_000
            }
            UserDefaults.standard.set(expiryTime, forKey: expiryKey)
        }

        return expiryTime > currentTime
    }

    private static func jwtExpiry(from token: String) -> TimeInterval? {
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
        if let exp = json["exp"] as? TimeInterval {
            return exp
        }
        if let exp = json["exp"] as? Int {
            return TimeInterval(exp)
        }
        return nil
    }

    /// Clears session state without blocking the main thread on Keychain/FS.
    private func invalidateSessionLightly(deleteScans: Bool) {
        sessionInvalidated = true
        memoryToken = nil
        keychainGeneration += 1
        let generation = keychainGeneration
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)

        let account = tokenKey
        let shouldWipeScans = deleteScans
        keychainQueue.async {
            guard generation == self.keychainGeneration else { return }
            AuthTokenKeychain.delete(account: account)
            if shouldWipeScans {
                RoominatorFileManager.shared.deleteAllScans()
            }
        }

        let publish: () -> Void = {
            self.isAuthenticated = false
            NotificationCenter.default.post(name: .limiAuthSessionDidChange, object: nil)
        }
        if Thread.isMainThread {
            publish()
        } else {
            DispatchQueue.main.async(execute: publish)
        }
    }

    // MARK: - One-time migration

    private func migrateTokenFromUserDefaultsIfNeeded() {
        // Only migrate when legacy UserDefaults token exists — avoid Keychain
        // round-trips that can stall launch under the debugger.
        guard let legacyToken = UserDefaults.standard.string(forKey: tokenKey),
              !legacyToken.isEmpty else { return }
        if AuthTokenKeychain.read(account: tokenKey) == nil {
            AuthTokenKeychain.save(legacyToken, account: tokenKey)
        }
        UserDefaults.standard.removeObject(forKey: tokenKey)
        if UserDefaults.standard.double(forKey: expiryKey) <= 0 {
            let fallback = Date().timeIntervalSince1970 + 600_000
            UserDefaults.standard.set(fallback, forKey: expiryKey)
        }
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
