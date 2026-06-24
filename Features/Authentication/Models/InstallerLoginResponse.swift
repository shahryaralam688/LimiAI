import Foundation

struct InstallerLoginResponse: Decodable {
    let success: Bool
    let message: String?
    let data: DataContainer?

    struct DataContainer: Decodable {
        let data: UserData?
        let token: String?
    }

    struct UserData: Decodable {
        let username: String?
        let email: String?
        let roles: String?
        let _id: String?
    }
}
