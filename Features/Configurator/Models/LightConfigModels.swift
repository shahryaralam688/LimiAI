import Foundation

struct LightConfigItem: Identifiable, Codable {
    let id: String
    let name: String
    let config: LightConfig

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case config
    }
}

struct LightConfig: Codable {
    let lightType: String
    let lightAmount: Int
    let cableColor: String
    let baseType: String
    let downloadId: String

    enum CodingKeys: String, CodingKey {
        case lightType = "light_type"
        case lightAmount = "light_amount"
        case cableColor = "cable_color"
        case baseType = "base_type"
        case downloadId = "download_Id"
    }
}

struct ARDisplayItem: Identifiable {
    let id: String
    let name: String
    let downloadId: String
    let isPreset: Bool
}
