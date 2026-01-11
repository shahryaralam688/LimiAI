//
//  SmartHomeApp.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//

import CoreBluetooth
let demoHubs: [Hub] = [
    Hub(name: "Living Room"),
    Hub(name: "Bedroom"),
    Hub(name: "Kitchen")
]
struct Hub: Identifiable, Codable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral?
    
    init(peripheral: CBPeripheral?) {
        self.peripheral = peripheral
        self.id = peripheral?.identifier ?? UUID()
        self.name = peripheral?.name ?? "Unknown Hub"
    }
    
    // Convenience initializer for previews/testing.
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.peripheral = nil
    }
    
    static func == (lhs: Hub, rhs: Hub) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case peripheral
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        peripheral = nil
    }
}


enum ControllerType: String, CaseIterable, Identifiable {
    case pwm2LED = "PWM 2 LED"
    case dataRGB = "1 Data RGB"
    case miniController = "Mini Controller"
    
    var id: String { self.rawValue }
}


