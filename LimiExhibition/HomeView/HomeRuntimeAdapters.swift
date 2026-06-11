import SwiftUI
import Combine

protocol HomeBluetoothControlling: ObservableObject {
    var isBluetoothOn: Bool { get }
    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void)
    func stopScanning()
    func selectAndConnect(name: String, uuidString: String)
    func readWifiList(completion: @escaping ([String]) -> Void)
}

protocol HomeBonjourBrowsing: ObservableObject {
    var discoveredWiFiDevices: [BLEDevice] { get }
    func startBrowsing()
    func stopBrowsing()
}

protocol HomeModulesManaging: ObservableObject {
    var addedModules: [Module] { get }
    func toggleModuleStatus(for id: Int)
}

protocol HomeContextManaging {
    func updateContext(screen: String, metadata: [String: String])
    func updateHomeTab(_ tab: Int)
    func clearHomeWelcomeOverlay()
}

protocol HomeUserDataRefreshing {
    func refreshUserData()
}

protocol HomeRoleProviding {
    func role() -> String
}

protocol HomeWelcomeCoordinating {
    func runFirstHomeWelcomeIfNeeded(contextManager: HomeContextManaging)
}

final class HomeBluetoothAdapter: HomeBluetoothControlling {
    @Published private(set) var isBluetoothOn = false

    private let manager: BluetoothManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BluetoothManager = .shared) {
        self.manager = manager
        self.isBluetoothOn = manager.isBluetoothOn

        manager.$isBluetoothOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isBluetoothOn = $0 }
            .store(in: &cancellables)
    }

    func startScanning(completion: @escaping ([(name: String, id: String)]) -> Void) {
        manager.startScanning(completion: completion)
    }

    func stopScanning() {
        manager.stopScanning()
    }

    func selectAndConnect(name: String, uuidString: String) {
        manager.selectAndConnect(name: name, uuidString: uuidString)
    }

    func readWifiList(completion: @escaping ([String]) -> Void) {
        manager.readWifiList(completion: completion)
    }
}

final class HomeBonjourAdapter: HomeBonjourBrowsing {
    @Published private(set) var discoveredWiFiDevices: [BLEDevice] = []

    private let browser: BonjourServiceBrowser
    private var cancellables: Set<AnyCancellable> = []

    init(browser: BonjourServiceBrowser = .shared) {
        self.browser = browser
        self.discoveredWiFiDevices = browser.discoveredWiFiDevices

        browser.$discoveredWiFiDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.discoveredWiFiDevices = $0 }
            .store(in: &cancellables)
    }

    func startBrowsing() {
        browser.startBrowsing()
    }

    func stopBrowsing() {
        browser.stopBrowsing()
    }
}

final class HomeModulesAdapter: HomeModulesManaging {
    @Published private(set) var addedModules: [Module] = []

    private let manager: ModulesManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: ModulesManager = .shared) {
        self.manager = manager
        self.addedModules = manager.getAddedModules()

        manager.$modules
            .receive(on: DispatchQueue.main)
            .sink { [weak self] modules in
                self?.addedModules = modules.filter { $0.status == .added }
            }
            .store(in: &cancellables)
    }

    func toggleModuleStatus(for id: Int) {
        manager.toggleModuleStatus(for: id)
    }
}

struct DefaultHomeContextManager: HomeContextManaging {
    func updateContext(screen: String, metadata: [String: String]) {
        ContextManager.shared.updateContext(screen: screen, metadata: metadata)
    }

    func updateHomeTab(_ tab: Int) {
        ContextManager.shared.updateHomeTab(tab)
    }

    func clearHomeWelcomeOverlay() {
        ContextManager.shared.clearHomeWelcomeOverlay()
    }
}

struct DefaultHomeUserDataRefresher: HomeUserDataRefreshing {
    func refreshUserData() {
        UserDataManager.shared.refreshUserData()
    }
}

struct DefaultHomeRoleProvider: HomeRoleProviding {
    func role() -> String {
        AuthManager.shared.getRole() ?? ""
    }
}

struct DefaultHomeWelcomeCoordinator: HomeWelcomeCoordinating {
    func runFirstHomeWelcomeIfNeeded(contextManager: HomeContextManaging) {
        let userDefaults = UserDefaults.standard
        let keys = ContextManager.PendingHomeWelcome.self
        guard userDefaults.bool(forKey: keys.pendingFlag) else { return }

        let name = userDefaults.string(forKey: keys.nameKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let useCase = userDefaults.string(forKey: keys.useCaseKey) ?? ""
        let goals = userDefaults.string(forKey: keys.goalsKey) ?? ""

        userDefaults.set(false, forKey: keys.pendingFlag)
        userDefaults.removeObject(forKey: keys.nameKey)
        userDefaults.removeObject(forKey: keys.useCaseKey)
        userDefaults.removeObject(forKey: keys.goalsKey)

        contextManager.updateContext(screen: "HomeView", metadata: [
            "first_home_after_personalize": "true",
            "welcome_user_name": name,
            "welcome_use_case": useCase,
            "welcome_goals": goals,
            "assistant_behavior": Self.firstHomeWelcomeAssistantBehavior(name: name, useCase: useCase, goals: goals)
        ])

        let voice = FloatingAssistantManager.shared.voiceClient
        switch voice.state {
        case .connected:
            voice.sendContextEvent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                voice.requestProactiveAssistantTurn()
            }
        case .disconnected, .error:
            voice.start()
        case .connecting:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard FloatingAssistantManager.shared.voiceClient.state == .connected else { return }
                FloatingAssistantManager.shared.voiceClient.sendContextEvent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    FloatingAssistantManager.shared.voiceClient.requestProactiveAssistantTurn()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            contextManager.clearHomeWelcomeOverlay()
        }
    }

    private static func firstHomeWelcomeAssistantBehavior(name: String, useCase: String, goals: String) -> String {
        let n = name.isEmpty ? "(name not provided)" : name
        let u = useCase.isEmpty ? "unspecified" : useCase
        let g = goals.isEmpty ? "unspecified" : goals
        return """
        FIRST HOME VISIT right after Personalize — treat this as the user’s first time on Home.
        User name: \(n). Where they use Limi: \(u). Their selected goals: \(g).

        Deliver ONE coherent spoken response in order (single turn, conversational):
        1) Warm welcome using their name.
        2) Short Limi AI intro tied to their context — smart lighting, control, and spatial / home features at a high level (not a lecture).
        3) Brief Home UI orientation using the `ui_guide` metadata: bottom navigation, main scroll, weather when present, floating orb for realtime voice.
        4) Close by asking what they would like to do next.

        Match the user’s spoken language when possible; otherwise English. Calm, premium, concise.
        """
    }
}
