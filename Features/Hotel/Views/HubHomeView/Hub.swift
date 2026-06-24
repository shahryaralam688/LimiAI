import Foundation
import CoreBluetooth

struct Hub: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral?

    init(name: String, id: UUID = UUID(), peripheral: CBPeripheral? = nil) {
        self.id = peripheral?.identifier ?? id
        self.name = peripheral?.name ?? name
        self.peripheral = peripheral
    }

    init(peripheral: CBPeripheral) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Device"
        self.peripheral = peripheral
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        peripheral = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

enum ControllerType: String, CaseIterable, Identifiable {
    case pwm2LED = "PWM"
    case dataRGB = "RGB"
    case miniController = "Mini Controller"

    var id: String { rawValue }
}
