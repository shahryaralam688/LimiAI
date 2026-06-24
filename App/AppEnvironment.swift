import SwiftUI

/// App-wide dependency container (Phase L pilot: Home + Login).
struct AppEnvironment {
    var auth: AuthProviding
    var http: HTTPPerforming
    var transport: LimiTransporting
    var bluetooth: HomeBluetoothMaking
    var installerLogin: InstallerLoginPerforming
    var roleManager: UserRoleManager

    static let live = AppEnvironment(
        auth: LiveAuthProvider(),
        http: LiveHTTPPerformer(),
        transport: LiveLimiTransport(),
        bluetooth: LiveHomeBluetoothFactory(),
        installerLogin: DefaultInstallerLoginService(),
        roleManager: .shared
    )

    static let mock = AppEnvironment(
        auth: MockAuthProvider(),
        http: MockHTTPPerformer(),
        transport: MockLimiTransport(),
        bluetooth: LiveHomeBluetoothFactory(),
        installerLogin: MockInstallerLoginService(),
        roleManager: .shared
    )
}

// MARK: - Environment injection

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.live
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - Live adapters

final class LiveAuthProvider: AuthProviding {
    private let manager = AuthManager.shared

    var isAuthenticated: Bool { manager.isAuthenticated }

    func getToken() -> String? { manager.getToken() }

    func authorizationHeaderValue() -> String? { manager.authorizationHeaderValue() }

    func getRole() -> String? { manager.getRole() }
}

struct LiveHTTPPerformer: HTTPPerforming {
    func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        LimiHTTPClient.perform(request, completion: completion)
    }

    func get(
        urlString: String,
        auth: LimiAuthRequirement?,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        LimiHTTPClient.get(urlString: urlString, auth: auth, completion: completion)
    }
}

final class LiveLimiTransport: LimiTransporting {
    private let transport: LimiTransport

    init(transport: LimiTransport = .shared) {
        self.transport = transport
    }

    func door(for deviceId: String) -> Door {
        transport.door(for: deviceId)
    }

    func firmwareDoor(for deviceId: String) -> Door {
        transport.firmwareDoor(for: deviceId)
    }
}

struct LiveHomeBluetoothFactory: HomeBluetoothMaking {
    func makeHomeBluetoothAdapter() -> HomeBluetoothAdapter {
        HomeBluetoothAdapter()
    }
}

// MARK: - ViewModel factories

extension HomeViewModel {
    convenience init(environment: AppEnvironment, deviceService: DeviceServiceProtocol = DeviceService()) {
        self.init(
            deviceService: deviceService,
            authProvider: HomeAuthProviderAdapter(auth: environment.auth),
            networkPerformer: HomeHTTPPerformerAdapter(http: environment.http)
        )
    }
}

extension GetStartViewModel {
    convenience init(environment: AppEnvironment) {
        self.init(
            installerLogin: environment.installerLogin,
            roleManager: environment.roleManager
        )
    }
}

private struct HomeAuthProviderAdapter: HomeAuthProviding {
    let auth: AuthProviding

    func token() -> String? { auth.getToken() }
}

private struct HomeHTTPPerformerAdapter: HomeNetworkPerforming {
    let http: HTTPPerforming

    func perform(_ request: URLRequest) {
        http.perform(request) { _, _, _ in }
    }
}

// MARK: - Test mocks

final class MockAuthProvider: AuthProviding {
    var isAuthenticated = true
    var token: String? = "mock-token"
    var role: String? = "User"

    func getToken() -> String? { token }
    func authorizationHeaderValue() -> String? {
        token.map { "Bearer \($0)" }
    }
    func getRole() -> String? { role }
}

final class MockHTTPPerformer: HTTPPerforming {
    private(set) var performedRequests: [URLRequest] = []
    var getHandler: ((String) -> (Data?, HTTPURLResponse?, Error?))?

    func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        performedRequests.append(request)
        completion(nil, HTTPURLResponse(), nil)
    }

    func get(
        urlString: String,
        auth: LimiAuthRequirement?,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        if let handler = getHandler {
            let (data, response, error) = handler(urlString)
            completion(data, response, error)
            return
        }
        completion(Data(), HTTPURLResponse(), nil)
    }
}

final class MockLimiTransport: LimiTransporting {
    var doors: [String: Door] = [:]

    func door(for deviceId: String) -> Door {
        doors[deviceId] ?? .ble
    }

    func firmwareDoor(for deviceId: String) -> Door {
        doors[deviceId] ?? .ble
    }
}

struct MockInstallerLoginService: InstallerLoginPerforming {
    var result: Result<Void, Error> = .success(())

    func loginAsInstaller(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(result)
    }
}