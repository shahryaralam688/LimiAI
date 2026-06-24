//
//  BluetoothManager+GATTWrite.swift
//  Limi
//

import CoreBluetooth

extension BluetoothManager {
    func writeDataToFF03(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found! Reconnecting...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        guard let characteristic = targetCharacteristic else {
            print("⚠️ FF03 characteristic is missing! Rediscovering...")
            enqueue(bytes)
            peripheral.discoverServices(nil)
            return
        }
        
        let dataToSend = Data(bytes)
        let props = characteristic.properties
        let writeType: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : (props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📤 Writing to FF03 (type=\(writeType == .withResponse ? "withResponse" : "withoutResponse")) | name=\(peripheral.name ?? "Unknown"), id=\(peripheral.identifier.uuidString) | bytes=\(bytes) | hex=\(hex)")
        peripheral.writeValue(dataToSend, for: characteristic, type: writeType)
    }

    func writeValue(_ bytes: [UInt8]) {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found! Reconnecting...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            enqueue(bytes)
            attemptReconnect()
            return
        }
        
        writeDataToFF03(bytes)
    }

    /// Convenience: send UTF-8 string payloads over FF03
    func writeString(_ text: String) {
        let bytes = Array(text.utf8)
        print("📝 Preparing to send string (UTF-8): \(text)")
        writeValue(bytes)
    }

    /// Simple helper requested: send a plain string message to the connected BLE device.
    /// Logs whether it is queued (not yet connected/ready) or being sent now.
    func BLESend(message: String) {
        print("➡️ BLESend called with message: \(message)")
        writeString(message)
    }

    // MARK: - Pending write helpers
    func enqueue(_ bytes: [UInt8]) {
        pendingWrites.append(bytes)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("🕓 Queued write until connected/ready: bytes=\(bytes) | hex=\(hex)")
    }

    func flushPendingWrites() {
        guard !pendingWrites.isEmpty else { return }
        print("🚀 Flushing \(pendingWrites.count) pending write(s)...")
        let writes = pendingWrites
        pendingWrites.removeAll()
        for payload in writes {
            writeDataToFF03(payload)
        }
    }
    func readValue() {
        guard let peripheral = connectedPeripheral else {
            print("❌ No connected peripheral found!")
            return
        }
        
        if peripheral.state != .connected {
            print("⚠️ Peripheral is disconnected! Attempting to reconnect...")
            attemptReconnect()
            return
        }
        
        // Find FF02 characteristic in all services
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == CBUUID(string: "FF02") {
                    print("📥 Sending read request for FF02")
                    peripheral.readValue(for: characteristic)
                    return
                }
            }
        }
        
        print("⚠️ FF02 characteristic not found! Rediscovering services...")
        peripheral.discoverServices(nil)
    }
}
