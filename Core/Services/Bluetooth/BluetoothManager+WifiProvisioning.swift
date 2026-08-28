//
//  BluetoothManager+WifiProvisioning.swift
//  Limi
//

import CoreBluetooth
import Foundation

extension BluetoothManager {
    func provisionWifi(
        ssid: String,
        password: String,
        expectedPeripheralUUID: String? = nil,
        completion: @escaping ((status: String, message: String)) -> Void
    ) {
        // Prefer the hub we intend to provision (device #2 must not write to device #1).
        if let expected = expectedPeripheralUUID,
           let uuid = UUID(uuidString: expected),
           let entry = connectedDevices[uuid],
           entry.peripheral.state == .connected {
            connectedPeripheral = entry.peripheral
            DeviceConsole.log(.ble, "provisionWifi — using expected peripheral \(expected)")
        }

        guard let peripheral = connectedPeripheral, peripheral.state == .connected else {
            DeviceConsole.log(
                .ble,
                "provisionWifi FAIL — no connected peripheral SSID=\(ssid) expected=\(expectedPeripheralUUID ?? "nil") current=\(connectedPeripheral?.identifier.uuidString ?? "nil") connectedCount=\(connectedDevices.count)"
            )
            completion((status: "error", message: "No connected peripheral"))
            return
        }

        if let expected = expectedPeripheralUUID,
           peripheral.identifier.uuidString.caseInsensitiveCompare(expected) != .orderedSame {
            DeviceConsole.log(
                .ble,
                "provisionWifi FAIL — wrong peripheral have=\(peripheral.identifier.uuidString) want=\(expected)"
            )
            completion((status: "error", message: "No connected peripheral"))
            return
        }

        DeviceConsole.log(
            .ble,
            "provisionWifi START peripheral=\(peripheral.name ?? "?") uuid=\(peripheral.identifier.uuidString) SSID=\(ssid) passwordLen=\(password.count) state=\(peripheral.state.rawValue)"
        )
        let maxSSID = 32
        let maxPass = 64
        var ssidBytes = Array(ssid.utf8)
        var passBytes = Array(password.utf8)
        if ssidBytes.count > maxSSID { ssidBytes = Array(ssidBytes.prefix(maxSSID)); }
        if passBytes.count > maxPass { passBytes = Array(passBytes.prefix(maxPass)); }
        guard provisioningCharacteristicsReady(for: peripheral),
              let ssidChar = fbSSIDCharacteristic,
              let passChar = fbPasswordCharacteristic else {
            DeviceConsole.log(.ble, "provisionWifi — FB02/FB03 missing or stale, rediscovering FB01…")
            clearProvisioningCharacteristics()
            peripheral.discoverServices([FB01])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if !self.provisioningCharacteristicsReady(for: peripheral) {
                    DeviceConsole.log(.ble, "provisionWifi FAIL — FB02/FB03 not found after rediscover")
                    completion((status: "error", message: "Required characteristics FB02/FB03 not found"))
                } else {
                    DeviceConsole.log(.ble, "provisionWifi — characteristics found, retrying write")
                    self.provisionWifi(
                        ssid: ssid,
                        password: password,
                        expectedPeripheralUUID: peripheral.identifier.uuidString,
                        completion: completion
                    )
                }
            }
            return
        }
        self.provisionCompletion = completion
        writeWithRetry(peripheral: peripheral, characteristic: ssidChar, data: Data(ssidBytes), retriesLeft: 2) { [weak self] ok1 in
            guard let self = self else { return }
            if !ok1 {
                DeviceConsole.log(.ble, "provisionWifi FAIL — SSID write failed")
                self.provisionCompletion?((status: "error", message: "Failed to write SSID after retries"))
                self.provisionCompletion = nil
                return
            }
            DeviceConsole.log(.ble, "provisionWifi — SSID written OK (\(ssidBytes.count) bytes)")
            self.writeWithRetry(peripheral: peripheral, characteristic: passChar, data: Data(passBytes), retriesLeft: 2) { ok2 in
                if !ok2 {
                    DeviceConsole.log(.ble, "provisionWifi FAIL — password write failed")
                    self.provisionCompletion?((status: "error", message: "Failed to write password after retries"))
                    self.provisionCompletion = nil
                    return
                }
                DeviceConsole.log(.ble, "provisionWifi — password written OK (\(passBytes.count) bytes) → device should reboot/join Wi-Fi")
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
            fb05ShouldRead = true
            return
        }
        guard peripheral.state == .connected else {
            fb05ShouldRead = true
            attemptReconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readFB05()
            }
            return
        }
        if let ch = fb05Characteristic, ch.properties.contains(.read) {
            peripheral.readValue(for: ch)
            return
        }
        // Need to (re)discover within FB01
        fb05ShouldRead = true
        peripheral.discoverServices([FB01])
    }

    func writeWithRetry(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data, retriesLeft: Int, completion: @escaping (Bool) -> Void) {
        var pending = PendingWrite(retriesLeft: retriesLeft, data: data, completion: completion)
        let charUUID = characteristic.uuid
        let timeout = DispatchWorkItem { [weak self] in
            guard let self,
                  var stuck = self.pendingWritesByUUID[charUUID] else { return }
            self.pendingWritesByUUID.removeValue(forKey: charUUID)
            stuck.timeoutWork = nil
            DeviceConsole.log(.ble, "writeWithRetry TIMEOUT char=\(charUUID.uuidString)")
            stuck.completion(false)
        }
        pending.timeoutWork = timeout
        pendingWritesByUUID[charUUID] = pending
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    /// Request Wi‑Fi SSID list from FB04 characteristic. Calls completion on main thread.
    func readWifiList(completion: @escaping ([String]) -> Void) {
        guard let peripheral = connectedPeripheral else {
            DeviceConsole.log(.ble, "readWifiList — no connectedPeripheral")
            completion([])
            return
        }
        guard peripheral.state == .connected else {
            wifiListCompletion = completion
            attemptReconnect()
            // Try again shortly after services rediscovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.readWifiList(completion: completion)
            }
            return
        }

        wifiListCompletion = completion
        let readToken = UUID()
        wifiListReadToken = readToken

        // Hard timeout so Add Device never stays on "Connecting…" forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) { [weak self] in
            guard let self else { return }
            guard self.wifiListReadToken == readToken, self.wifiListCompletion != nil else { return }
            DeviceConsole.log(.ble, "readWifiList TIMEOUT — returning empty list")
            let done = self.wifiListCompletion
            self.wifiListCompletion = nil
            self.wifiListReadToken = nil
            done?([])
        }

        // If we already have the characteristic, read immediately
        if let fb04 = fbWifiListCharacteristic, fb04.properties.contains(.read) {
            peripheral.readValue(for: fb04)
            return
        }

        // Otherwise, rediscover FB01 service; didDiscoverCharacteristics will trigger read if waiting
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
