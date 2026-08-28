//
//  BluetoothManager+GATTWrite.swift
//  Limi
//

import CoreBluetooth

extension BluetoothManager {
    func writeDataToFF03(_ bytes: [UInt8], toPeripheralUUID uuidString: String? = nil) {
        let resolved = resolveWriteTarget(uuidString)
        guard let peripheral = resolved?.peripheral else {
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        guard let characteristic = resolved?.characteristic ?? targetCharacteristic else {
            enqueue(bytes)
            peripheral.discoverServices(nil)
            return
        }
        
        let dataToSend = Data(bytes)
        let props = characteristic.properties
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : (props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        peripheral.writeValue(dataToSend, for: characteristic, type: writeType)
    }

    private func resolveWriteTarget(_ uuidString: String?) -> (peripheral: CBPeripheral, characteristic: CBCharacteristic?)? {
        if let uuidString, !uuidString.isEmpty {
            if let entry = connectedEntry(forPeripheralUUID: uuidString) {
                return (entry.peripheral, entry.characteristic)
            }
            if let connected = connectedPeripheral,
               connected.identifier.uuidString.caseInsensitiveCompare(uuidString) == .orderedSame {
                return (connected, targetCharacteristic)
            }
            return nil
        }
        if let connected = connectedPeripheral {
            return (connected, targetCharacteristic)
        }
        return nil
    }

    func writeValue(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral else {
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        writeDataToFF03(bytes)
    }

    /// Convenience: send UTF-8 string payloads over FF03
    func writeString(_ text: String) {
        let bytes = Array(text.utf8)
        writeValue(bytes)
    }

    /// Simple helper requested: send a plain string message to the connected BLE device.
    /// Logs whether it is queued (not yet connected/ready) or being sent now.
    func BLESend(message: String) {
        writeString(message)
    }

    // MARK: - Pending write helpers
    func enqueue(_ bytes: [UInt8]) {
        pendingWrites.append(bytes)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    func flushPendingWrites() {
        guard !pendingWrites.isEmpty else { return }
        let writes = pendingWrites
        pendingWrites.removeAll()
        for payload in writes {
            writeDataToFF03(payload)
        }
    }
    func readValue() {
        guard let peripheral = connectedPeripheral else {
            return
        }
        
        if peripheral.state != .connected {
            attemptReconnect()
            return
        }
        
        // Find FF02 characteristic in all services
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == CBUUID(string: "FF02") {
                    peripheral.readValue(for: characteristic)
                    return
                }
            }
        }
        
        peripheral.discoverServices(nil)
    }
}
