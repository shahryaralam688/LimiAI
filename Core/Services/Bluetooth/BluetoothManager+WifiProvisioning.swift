//
//  BluetoothManager+WifiProvisioning.swift
//  Limi
//

import CoreBluetooth
import Foundation

extension BluetoothManager {
    func provisionWifi(ssid: String, password: String, completion: @escaping ((status: String, message: String)) -> Void) {
        guard let peripheral = connectedPeripheral else {
            completion((status: "error", message: "No connected peripheral"))
            return
        }
        let maxSSID = 32
        let maxPass = 64
        var ssidBytes = Array(ssid.utf8)
        var passBytes = Array(password.utf8)
        if ssidBytes.count > maxSSID { ssidBytes = Array(ssidBytes.prefix(maxSSID)); print("ℹ️ SSID truncated to \(maxSSID) bytes") }
        if passBytes.count > maxPass { passBytes = Array(passBytes.prefix(maxPass)); print("ℹ️ Password truncated to \(maxPass) bytes") }
        guard let ssidChar = fbSSIDCharacteristic, let passChar = fbPasswordCharacteristic else {
            peripheral.discoverServices([FB01])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.fbSSIDCharacteristic == nil || self.fbPasswordCharacteristic == nil {
                    completion((status: "error", message: "Required characteristics FB02/FB03 not found"))
                } else {
                    self.provisionWifi(ssid: ssid, password: password, completion: completion)
                }
            }
            return
        }
        self.provisionCompletion = completion
        writeWithRetry(peripheral: peripheral, characteristic: ssidChar, data: Data(ssidBytes), retriesLeft: 2) { [weak self] ok1 in
            guard let self = self else { return }
            if !ok1 {
                self.provisionCompletion?((status: "error", message: "Failed to write SSID after retries"))
                self.provisionCompletion = nil
                return
            }
            self.writeWithRetry(peripheral: peripheral, characteristic: passChar, data: Data(passBytes), retriesLeft: 2) { ok2 in
                if !ok2 {
                    self.provisionCompletion?((status: "error", message: "Failed to write password after retries"))
                    self.provisionCompletion = nil
                    return
                }
                // Credentials are on the device; firmware reboots to join Wi-Fi.
                // Final success is confirmed via Bonjour/mDNS, not BLE notify.
                self.provisionTimeout?.cancel()
                self.provisionTimeout = nil
                self.provisionCompletion?((status: "credentials_sent", message: "Credentials sent to device"))
                self.provisionCompletion = nil
            }
        }
    }
    func fbo5Wifi(){
        readFB05()
    }

    func readFB05() {
        guard let peripheral = connectedPeripheral else {
            print("❌ readFB05: No connected peripheral")
            fb05ShouldRead = true
            return
        }
        guard peripheral.state == .connected else {
            print("⚠️ readFB05: Peripheral not connected — attempting reconnect")
            fb05ShouldRead = true
            attemptReconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readFB05()
            }
            return
        }
        if let ch = fb05Characteristic, ch.properties.contains(.read) {
            print("📤 readFB05: Using cached FB05 characteristic")
            peripheral.readValue(for: ch)
            return
        }
        // Need to (re)discover within FB01
        print("🔎 readFB05: Discovering FB01/FB05…")
        fb05ShouldRead = true
        peripheral.discoverServices([FB01])
    }

    func writeWithRetry(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data, retriesLeft: Int, completion: @escaping (Bool) -> Void) {
        pendingWritesByUUID[characteristic.uuid] = PendingWrite(retriesLeft: retriesLeft, data: data, completion: completion)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    /// Request Wi‑Fi SSID list from FB04 characteristic. Calls completion on main thread.
    func readWifiList(completion: @escaping ([String]) -> Void) {
        guard let peripheral = connectedPeripheral else {
            print("❌ readWifiList: No connected peripheral")
            completion([])
            return
        }
        guard peripheral.state == .connected else {
            print("⚠️ readWifiList: Peripheral not connected — attempting reconnect")
            wifiListCompletion = completion
            attemptReconnect()
            // Try again shortly after services rediscovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readWifiList(completion: completion)
            }
            return
        }

        wifiListCompletion = completion

        // If we already have the characteristic, read immediately
        if let fb04 = fbWifiListCharacteristic, fb04.properties.contains(.read) {
            print("📤 readWifiList: Using cached FB04 characteristic")
            peripheral.readValue(for: fb04)
            return
        }

        // Otherwise, rediscover FB01 service; didDiscoverCharacteristics will trigger read if waiting
        print("🔎 readWifiList: Discovering FB01/FB04…")
        peripheral.discoverServices([FB01])
    }

    /// Parse a string that looks like an array into [String]. Prefer JSON, fallback to comma-split.
    static func parseSSIDArrayString(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try JSON first
        if let data = trimmed.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any] {
            return arr.compactMap { elem in
                if let s = elem as? String { return s }
                if let n = elem as? NSNumber { return n.stringValue }
                return nil
            }
        }
        // Fallback: strip brackets and quotes, then split by comma
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if stripped.isEmpty { return [] }
        return stripped
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { s in
                var v = s
                if v.hasPrefix("\"") && v.hasSuffix("\"") {
                    v = String(v.dropFirst().dropLast())
                }
                return v
            }
    }
}
