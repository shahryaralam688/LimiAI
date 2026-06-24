import SwiftUI

final class GetStartViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var activeAuthRoute: AuthRoute?
    @Published var errorMessage: String?

    private let installerLogin: InstallerLoginPerforming
    private let roleManager: UserRoleManager

    init(
        installerLogin: InstallerLoginPerforming = DefaultInstallerLoginService(),
        roleManager: UserRoleManager = .shared
    ) {
        self.installerLogin = installerLogin
        self.roleManager = roleManager
    }

    func continueWithRole(_ role: GetStart.Role?) {
        guard let role else { return }
        errorMessage = nil

        switch role {
        case .signLanguageInterpreter:
            roleManager.setRole(.user)
            activeAuthRoute = .login
        case .deafOrHardOfHearing:
            roleManager.setRole(.installer)
            loginAsInstaller()
        }
    }

    func dismissAuthRoute() {
        activeAuthRoute = nil
    }

    private func loginAsInstaller() {
        isLoading = true
        installerLogin.loginAsInstaller { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    self.activeAuthRoute = .installerHome
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("Installer login failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
