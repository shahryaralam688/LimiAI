import UIKit
import Combine

final class FloatingAssistantManager {
    static let shared = FloatingAssistantManager()

    private var floatingWindow: FloatingWindow?
    private var rootController: FloatingRootViewController?
    private var sceneObserver: NSObjectProtocol?
    private var stateObserver: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var didBindAuthAndContext = false
    /// While the Personalize (`OnboardingFlowView`) flow is visible, show the orb even though auth is not set until the final step.
    private var isPersonalizeFlowActive = false

    let voiceClient = WebRTCVoiceClient(
        backendBaseURL: URL(string: "https://dev.api.limitless-lighting.co.uk/")!
    )

    private init() {}

    // MARK: - Bootstrap

    func setup() {
        sceneObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.floatingWindow == nil,
                  let scene = notification.object as? UIWindowScene else { return }
            self.createWindow(in: scene)
        }

        if let activeScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            createWindow(in: activeScene)
        }

        applyFloatingVisibilityPolicy()
    }

    // MARK: - Window Creation

    private func createWindow(in scene: UIWindowScene) {
        let window = FloatingWindow(windowScene: scene)
        let rootVC = FloatingRootViewController()
        rootVC.onBubbleTapped = { [weak self] in self?.handleBubbleTap() }
        window.rootViewController = rootVC
        window.makeKeyAndVisible()

        DispatchQueue.main.async {
            scene.windows.first(where: { !($0 is FloatingWindow) })?.makeKey()
        }

        self.floatingWindow = window
        self.rootController = rootVC
        observeVoiceState()
        bindAuthContextAndVisibility()
        applyFloatingVisibilityPolicy()
    }

    /// Call after login/logout or when onboarding completion changes, if not using the Combine path.
    func refreshFloatingVisibility() {
        applyFloatingVisibilityPolicy()
    }

    /// Toggle when `OnboardingFlowView` (Personalize) appears / disappears so the floating orb is visible during that flow.
    func setPersonalizeFlowActive(_ active: Bool) {
        isPersonalizeFlowActive = active
        applyFloatingVisibilityPolicy()
    }

    /// Shows the orb only after onboarding is done **and** the user has a valid session (logged in), unless Personalize is active.
    private func applyFloatingVisibilityPolicy() {
        if isPersonalizeFlowActive {
            show()
            return
        }
        let onboardingDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let authed = AuthManager.shared.isAuthenticated
        if onboardingDone && authed {
            show()
        } else {
            hide()
        }
    }

    private func bindAuthContextAndVisibility() {
        guard !didBindAuthAndContext else { return }
        didBindAuthAndContext = true

        AuthManager.shared.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFloatingVisibilityPolicy()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .limiScreenContextDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.voiceClient.state == .connected else { return }
                self.voiceClient.sendContextEvent()
            }
            .store(in: &cancellables)
    }

    // MARK: - Show / Hide

    func show() {
        floatingWindow?.isHidden = false
    }

    func hide() {
        floatingWindow?.isHidden = true
    }

    // MARK: - Voice State Observation

    private func observeVoiceState() {
        stateObserver = voiceClient.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connected:
                    self.rootController?.setBubbleActive(true)
                    // Context + optional proactive greeting are sent when the Realtime data channel opens
                    // (`WebRTCVoiceClient.flushContextAndProactiveGreeting`), not here — `.connected` can fire before DC is open.
                case .disconnected, .error:
                    self.rootController?.setBubbleActive(false)
                case .connecting:
                    break
                }
            }
    }

    // MARK: - Tap -> Voice Toggle

    private func handleBubbleTap() {
        switch voiceClient.state {
        case .disconnected, .error:
            voiceClient.start()
        case .connected:
            voiceClient.stop()
        case .connecting:
            // Cancel a stuck session so the user can tap again to start fresh
            voiceClient.stop()
        }
    }
}
