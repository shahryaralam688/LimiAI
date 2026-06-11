import Foundation

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false

    private let tokenKey = "authToken"
    private let expiryKey = "authTokenExpiry"
    private let roleKey = "authRole"

    init() {
        self.isAuthenticated = isTokenValid()
    }

    func saveToken(_ token: String, expiryInSeconds: TimeInterval = 600000, updateAuthState: Bool = true) {
        let expiryTime = Date().timeIntervalSince1970 + expiryInSeconds

        // Save values
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(expiryTime, forKey: expiryKey)
        UserDefaults.standard.synchronize()  // Ensure it's written immediately

        // Debugging logs
        print("Saved Token:", token)
        print("Expiry Time Set:", expiryTime)

        if updateAuthState {
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
        }
    }

    // MARK: - Role Persistence
    func saveRole(_ role: String) {
        UserDefaults.standard.set(role, forKey: roleKey)
        UserDefaults.standard.synchronize()
        print("Saved Role:", role)
    }

    func getRole() -> String? {
        UserDefaults.standard.string(forKey: roleKey)
    }
    func getToken() -> String? {
        if isTokenValid() {
            return UserDefaults.standard.string(forKey: tokenKey)
        } else {
            clearToken()
            return nil
        }
    }

    /// `Authorization` header value for API calls: ensures a single `Bearer` prefix.
    func authorizationHeaderValue() -> String? {
        guard let raw = getToken() else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            return trimmed
        }
        return "Bearer \(trimmed)"
    }

    func isTokenValid() -> Bool {
        let expiryTime = UserDefaults.standard.double(forKey: expiryKey)
        let currentTime = Date().timeIntervalSince1970
        print("Token Expiry Time:", expiryTime, "Current Time:", currentTime)

        if expiryTime > currentTime {
            return true
        } else {
            print("Token expired. Clearing token...")
            clearToken()
            return false
        }
    }


    func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)

        // Delete all scans from ForRealScans
        RoominatorFileManager.shared.deleteAllScans()

        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
    func clearRole() {
        UserDefaults.standard.removeObject(forKey: roleKey)

    }

}

//import Foundation
//
//class AuthManager: ObservableObject {
//
//    static let shared = AuthManager()
//
//    @Published var isAuthenticated: Bool = false
//
//    private let tokenKey = "authToken"          // 🔐 Keychain
//    private let expiryKey = "authTokenExpiry"   // UserDefaults
//    private let roleKey = "authRole"             // UserDefaults
//
//    init() {
//        self.isAuthenticated = isTokenValid()
//    }
//
//    // MARK: - Save Token (Keychain)
//    func saveToken(
//        _ token: String,
//        expiryInSeconds: TimeInterval = 600000,
//        updateAuthState: Bool = true
//    ) {
//        let expiryTime = Date().timeIntervalSince1970 + expiryInSeconds
//
//        // 🔐 Save token securely
//        KeychainHelper.shared.save(token, for: tokenKey)
//
//        // 📦 Save expiry (non-sensitive)
//        UserDefaults.standard.set(expiryTime, forKey: expiryKey)
//
//        print("🔐 Token saved in Keychain")
//        print("⏰ Expiry set:", expiryTime)
//
//        if updateAuthState {
//            DispatchQueue.main.async {
//                self.isAuthenticated = true
//            }
//        }
//    }
//
//    // MARK: - Role (Non-sensitive)
//    func saveRole(_ role: String) {
//        UserDefaults.standard.set(role, forKey: roleKey)
//        print("🔹 Saved Role:", role)
//    }
//
//    func getRole() -> String? {
//        UserDefaults.standard.string(forKey: roleKey)
//    }
//
//    // MARK: - Get Token
//    func getToken() -> String? {
//        if isTokenValid() {
//            return KeychainHelper.shared.read(tokenKey)
//        } else {
//            clearToken()
//            return nil
//        }
//    }
//
//    // MARK: - Token Validation
//    func isTokenValid() -> Bool {
//        let expiryTime = UserDefaults.standard.double(forKey: expiryKey)
//        let currentTime = Date().timeIntervalSince1970
//
//        print("⏳ Expiry:", expiryTime, "Now:", currentTime)
//
//        guard expiryTime > currentTime else {
//            print("❌ Token expired")
//            return false
//        }
//
//        return KeychainHelper.shared.read(tokenKey) != nil
//    }
//
//    // MARK: - Clear Auth
//    func clearToken() {
//        // 🔐 Remove secure token
//        KeychainHelper.shared.delete(tokenKey)
//
//        // 📦 Remove expiry
//        UserDefaults.standard.removeObject(forKey: expiryKey)
//
//        // 🧹 Your existing cleanup
//        RoominatorFileManager.shared.deleteAllScans()
//
//        DispatchQueue.main.async {
//            self.isAuthenticated = false
//        }
//    }
//
//    func clearRole() {
//        UserDefaults.standard.removeObject(forKey: roleKey)
//    }
//}
