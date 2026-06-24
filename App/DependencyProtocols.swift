import Foundation

// MARK: - Dependency protocols (Phase L)

protocol AuthProviding: AnyObject {
    var isAuthenticated: Bool { get }
    func getToken() -> String?
    func authorizationHeaderValue() -> String?
    func getRole() -> String?
}

protocol HTTPPerforming {
    func perform(
        _ request: URLRequest,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    )
    func get(
        urlString: String,
        auth: LimiAuthRequirement?,
        completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    )
}

protocol LimiTransporting: AnyObject {
    func door(for deviceId: String) -> Door
    func firmwareDoor(for deviceId: String) -> Door
}

protocol HomeBluetoothMaking {
    func makeHomeBluetoothAdapter() -> HomeBluetoothAdapter
}
