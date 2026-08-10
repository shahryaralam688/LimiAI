import Foundation

protocol GoogleSignInPerforming {
    func signIn(completion: @escaping (Bool) -> Void)
}

protocol InstallerUserCreating {
    func createInstallerUser(completion: @escaping (Result<Void, Error>) -> Void)
}

struct DefaultGoogleSignInPerformer: GoogleSignInPerforming {
    private let authManager: GoogleAuthManager

    init(authManager: GoogleAuthManager = GoogleAuthManager()) {
        self.authManager = authManager
    }

    func signIn(completion: @escaping (Bool) -> Void) {
        authManager.signInWithGoogle(completion: completion)
    }
}

struct DefaultInstallerUserCreator: InstallerUserCreating {
    enum InstallerUserError: LocalizedError {
        case invalidURL
        case noData
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .invalidResponse:
                return "Invalid response from server"
            }
        }
    }

    func createInstallerUser(completion: @escaping (Result<Void, Error>) -> Void) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.LoginInstallerUser,
            body: [:],
            auth: .none
        ) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data, !data.isEmpty else {
                completion(.failure(InstallerUserError.noData))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(InstallerUserResponse.self, from: data)
                if decoded.success, let token = decoded.data?.token, !token.isEmpty {
                    AuthManager.shared.saveToken(token)
                    let roleMessage = decoded.message ?? "Installer User created"
                    AuthManager.shared.saveRole(roleMessage)
                    completion(.success(()))
                } else {
                    completion(.failure(InstallerUserError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

final class SignInViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showHomeView = false
    @Published var showLoginView = false
    @Published var showPrivacyPolicy = false
    @Published var appeared = false
    @Published var signInErrorMessage: String?
    @Published private(set) var postLoginShowsHomeDirectly = false

    private let managesPostLoginNavigation: Bool
    private let googleSignInPerformer: GoogleSignInPerforming
    private let installerUserCreator: InstallerUserCreating

    init(
        managesPostLoginNavigation: Bool = true,
        googleSignInPerformer: GoogleSignInPerforming = DefaultGoogleSignInPerformer(),
        installerUserCreator: InstallerUserCreating = DefaultInstallerUserCreator()
    ) {
        self.managesPostLoginNavigation = managesPostLoginNavigation
        self.googleSignInPerformer = googleSignInPerformer
        self.installerUserCreator = installerUserCreator
    }

    func showEmailLogin() {
        showLoginView = true
    }

    func showPrivacy() {
        showPrivacyPolicy = true
    }

    func signInWithGoogle() {
        signInErrorMessage = nil
        isLoading = true
        googleSignInPerformer.signIn { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                guard success else {
                    self.signInErrorMessage = "Google sign-in failed. Please try again."
                    return
                }
                self.handleSuccessfulSignIn()
            }
        }
    }

    func continueAsGuest() {
        isLoading = true
        installerUserCreator.createInstallerUser { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                if case .success = result {
                    self?.handleSuccessfulSignIn()
                }
            }
        }
    }

    private func handleSuccessfulSignIn() {
        guard AuthManager.shared.getToken() != nil else {
            signInErrorMessage = "Could not start your session. Please try again."
            return
        }

        let personalizeCompleted = isPersonalizeCompleted()
        postLoginShowsHomeDirectly = personalizeCompleted

        if personalizeCompleted {
            AuthManager.shared.isAuthenticated = true
        }

        if !managesPostLoginNavigation, personalizeCompleted {
            return
        }

        showHomeView = true
    }

    private func isPersonalizeCompleted() -> Bool {
        if UserDefaults.standard.bool(forKey: "hasCompletedPersonalize") {
            return true
        }
        guard let data = UserDefaults.standard.data(forKey: "onboarding_data"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["bluetoothAllowed"] != nil else {
            return false
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedPersonalize")
        return true
    }
}

private struct InstallerUserResponse: Decodable {
    let success: Bool
    let message: String?
    let data: DataContainer?

    struct DataContainer: Decodable {
        let data: String?
        let token: String?
    }
}
