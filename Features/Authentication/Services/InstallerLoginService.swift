import Foundation

protocol InstallerLoginPerforming {
    func loginAsInstaller(completion: @escaping (Result<Void, Error>) -> Void)
}

struct DefaultInstallerLoginService: InstallerLoginPerforming {
    enum InstallerLoginError: LocalizedError {
        case noData
        case loginFailed(String)

        var errorDescription: String? {
            switch self {
            case .noData:
                return "No response from server"
            case .loginFailed(let message):
                return message
            }
        }
    }

    func loginAsInstaller(completion: @escaping (Result<Void, Error>) -> Void) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.LoginInstallerUser,
            body: [:],
            auth: .none
        ) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let http = response, !(200...299).contains(http.statusCode) {
                completion(.failure(InstallerLoginError.loginFailed("HTTP \(http.statusCode)")))
                return
            }

            guard let data, !data.isEmpty else {
                completion(.failure(InstallerLoginError.noData))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(InstallerLoginResponse.self, from: data)
                guard decoded.success,
                      let token = decoded.data?.token,
                      !token.isEmpty else {
                    let message = decoded.message ?? "Installer login failed"
                    completion(.failure(InstallerLoginError.loginFailed(message)))
                    return
                }

                AuthManager.shared.saveToken(token)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
