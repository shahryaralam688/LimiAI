import SwiftUI

/// Top-level routes after splash (Phase C — central routing).
enum AppRootRoute: Equatable {
    case onboarding
    case signIn
    case locationPrompt
    case home
}

enum AppRouter {
    static func rootRoute(
        isAuthenticated: Bool,
        hasLaunchedBefore: Bool,
        hasCompletedOnboarding: Bool,
        storedLocationEmpty: Bool,
        locationPromptSkipped: Bool
    ) -> AppRootRoute {
        if isAuthenticated {
            if storedLocationEmpty && !locationPromptSkipped {
                return .locationPrompt
            }
            return .home
        }
        if !hasCompletedOnboarding {
            return .onboarding
        }
        return .signIn
    }

    @ViewBuilder
    static func destination(for route: AppRootRoute) -> some View {
        switch route {
        case .onboarding:
            OnboardingView()
                .ignoresSafeArea()
        case .signIn:
            SignInView(managesPostLoginNavigation: false)
                .ignoresSafeArea()
        case .locationPrompt:
            LocationStorageView(showSkipButton: true)
                .ignoresSafeArea()
        case .home:
            HomeView()
                .ignoresSafeArea()
        }
    }
}
