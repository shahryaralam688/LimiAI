import SwiftUI

/// Post–GetStart authentication destinations (Phase E).
enum AuthRoute: String, Identifiable, Equatable {
    case login
    case productionUserLogin
    case installerHome

    var id: String { rawValue }
}

enum AuthCoordinator {
    @ViewBuilder
    static func destination(for route: AuthRoute) -> some View {
        switch route {
        case .login:
            LoginView()
        case .productionUserLogin:
            PULoginView()
        case .installerHome:
            HotelHomeView()
        }
    }
}
