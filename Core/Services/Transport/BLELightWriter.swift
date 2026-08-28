//
//  BLELightWriter.swift
//  Limi
//
//  Thin wrapper around BluetoothManager.writeDataToFF03(_:) that knows how to
//  encode a LimiCommand for the BLE door:
//    • CCT  → binary  [0x01, ww, cw, brightness, channel]
//    • RGB  → binary  [0x02, red, green, blue, brightness, channel]
//    • Power → UTF-8  "on" / "off"
//    • Pattern → unsupported on BLE per firmware spec.
//

import Foundation

public final class BLELightWriter {
    public static let shared = BLELightWriter()

    /// The transport we delegate raw writes to. Defaults to BluetoothManager.shared.
    public var bleTransport: BLEFF03Writing = BluetoothManager.shared

    private init() {}

    /// Encode and write a single command on the BLE door.
    /// - Throws `LimiTransportError.operationNotSupported(.ble)` for `.pattern`
    ///   (firmware did not specify a binary pattern format).
    /// - Throws `LimiTransportError.doorUnavailable(.ble)` if no peripheral is
    ///   currently connected.
    public func send(_ command: LimiCommand, toPeripheralUUID uuid: String? = nil) throws {
        switch command {
        case .cct, .rgb:
            guard let data = command.toBLEBytes() else {
                throw LimiTransportError.badCommand
            }
            try writeRaw([UInt8](data), description: "binary command", toPeripheralUUID: uuid)
        case .power:
            guard let csv = command.toBLECSV() else {
                throw LimiTransportError.badCommand
            }
            try writeRaw(Array(csv.utf8), description: "power '\(csv)'", toPeripheralUUID: uuid)
        case .pattern:
            throw LimiTransportError.operationNotSupported(door: .ble)
        }
    }

    private func writeRaw(_ bytes: [UInt8], description: String, toPeripheralUUID uuid: String? = nil) throws {
        if let uuid, !uuid.isEmpty {
            let ble = BluetoothManager.shared
            guard ble.isLiveConnected(forPeripheralUUID: uuid) || ble.isReady(forPeripheralUUID: uuid) else {
                throw LimiTransportError.doorUnavailable(.ble)
            }
            ble.writeDataToFF03(bytes, toPeripheralUUID: uuid)
            return
        }
        guard bleTransport.isPeripheralConnected else {
            throw LimiTransportError.doorUnavailable(.ble)
        }
        bleTransport.writeFF03(bytes)
    }
}

// MARK: - Indirection so we can mock BluetoothManager in tests/previews.

public protocol BLEFF03Writing {
    var isPeripheralConnected: Bool { get }
    func writeFF03(_ bytes: [UInt8])
}

extension BluetoothManager: BLEFF03Writing {
    public var isPeripheralConnected: Bool { isConnected }
    public func writeFF03(_ bytes: [UInt8]) { writeDataToFF03(bytes) }
}
