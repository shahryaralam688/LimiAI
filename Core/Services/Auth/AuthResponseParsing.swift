import Foundation

enum AuthResponseParsing {
    /// Parses app JWT from standard login responses: `{ "data": { "token": "..." } }` or nested `data.data.token`.
    static func appToken(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return nil }

        if let dataField = json["data"] as? [String: Any] {
            if let token = dataField["token"] as? String { return token }
            if let inner = dataField["data"] as? [String: Any],
               let token = inner["token"] as? String {
                return token
            }
        }
        return nil
    }
}

/// Shared Apple ↔ backend exchange used by `GoogleAuthManager.signInWithApple()`.
enum AppleLoginAPI {
    enum ExchangeError: LocalizedError {
        case missingURL
        case emptyIdentityToken
        case invalidHTTPStatus(Int)
        case noTokenInBody

        var errorDescription: String? {
            switch self {
            case .missingURL:
                return "Sign in with Apple could not reach the server."
            case .emptyIdentityToken:
                return "Apple did not return a sign-in token. Try again."
            case .invalidHTTPStatus(let code):
                return "Sign in failed (HTTP \(code)). Try again or use another sign-in method."
            case .noTokenInBody:
                return "Server did not return a session. Check that Apple login is enabled on the API."
            }
        }
    }

    /// POST `identity_token` (JWT) + stable `user` id to `APIConstants.loginApple`.
    static func exchange(identityToken: String, appleUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !identityToken.isEmpty else {
            DispatchQueue.main.async { completion(.failure(ExchangeError.emptyIdentityToken)) }
            return
        }
        LimiHTTPClient.postJSON(
            urlString: APIConstants.loginApple,
            body: [
                "identity_token": identityToken,
                "user": appleUserId
            ],
            auth: .none
        ) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let status = response?.statusCode ?? -1
            guard (200 ... 299).contains(status) else {
                DispatchQueue.main.async { completion(.failure(ExchangeError.invalidHTTPStatus(status))) }
                return
            }
            guard let data, let token = AuthResponseParsing.appToken(from: data) else {
                DispatchQueue.main.async { completion(.failure(ExchangeError.noTokenInBody)) }
                return
            }
            AuthManager.shared.saveToken(token, updateAuthState: true)
            AuthManager.shared.clearRole()
            DispatchQueue.main.async { completion(.success(())) }
        }
    }
}
