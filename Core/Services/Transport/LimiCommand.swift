//
//  LimiCommand.swift
//  Limi
//
//  Unified command model for all three transport doors (MQTT / WebSocket / BLE).
//  Produces firmware-correct JSON, binary, and CSV from a single source of truth.
//
//  See APP_CONTROL_PROTOCOL.md for the canonical wire format.
//

import Foundation

/// One light command. The same value can be encoded for MQTT/WebSocket (JSON)
/// or for BLE (binary or CSV depending on what the firmware accepts).
///
/// Channel is always 1-based. Single-channel devices use channel 1.
public enum LimiCommand: Equatable {
    /// CCT (warm/cool white) command. brightness/ww/cw are 0…100.
    case cct(channel: Int, brightness: Int, ww: Int, cw: Int)

    /// RGB color command. brightness 0…100, red/green/blue 0…255.
    case rgb(channel: Int, brightness: Int, red: Int, green: Int, blue: Int)

    /// Power on/off for a channel. brightness state is preserved by the device.
    case power(channel: Int, on: Bool)

    /// Built-in pattern command. speed/intensity 0…255. color in 0…255 RGB triplet.
    /// Not supported on the BLE door (firmware does not specify a binary format).
    case pattern(channel: Int, id: Int, speed: Int, intensity: Int, color: [Int])

    /// 1-based channel this command targets.
    public var channel: Int {
        switch self {
        case .cct(let c, _, _, _): return c
        case .rgb(let c, _, _, _, _): return c
        case .power(let c, _): return c
        case .pattern(let c, _, _, _, _): return c
        }
    }
}

// MARK: - JSON encoding (MQTT + WebSocket)

extension LimiCommand {
    /// Builds the wire-shape `{"deviceId": "...", "command": {...}}` envelope
    /// expected by both `device/<id>/command` (MQTT) and `ws://<ip>/ws` (WebSocket).
    public func toJSON(deviceId: String) -> Data {
        let envelope: [String: Any] = [
            "deviceId": deviceId.uppercased(),
            "command": commandPayload()
        ]
        // .sortedKeys is stable; firmware ignores key order but it makes logs readable.
        return (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
    }

    /// Inner `"command": { ... }` payload. Exposed for debug / tests.
    public func commandPayload() -> [String: Any] {
        switch self {
        case .cct(let channel, let brightness, let ww, let cw):
            return [
                "channel": channel,
                "brightness": clamp(brightness, 0, 100),
                "ww": clamp(ww, 0, 100),
                "cw": clamp(cw, 0, 100)
            ]
        case .rgb(let channel, let brightness, let red, let green, let blue):
            return [
                "channel": channel,
                "brightness": clamp(brightness, 0, 100),
                "red": clamp(red, 0, 255),
                "green": clamp(green, 0, 255),
                "blue": clamp(blue, 0, 255)
            ]
        case .power(let channel, let on):
            // Spec accepts {on:false}, {power:false}, or {state:"off"}.
            // We use {state:"off"} / {state:"on"} for max compatibility with all firmware revs.
            return [
                "channel": channel,
                "state": on ? "on" : "off"
            ]
        case .pattern(let channel, let id, let speed, let intensity, let color):
            let safeColor: [Int] = (0..<3).map { idx in
                idx < color.count ? clamp(color[idx], 0, 255) : 0
            }
            return [
                "channel": channel,
                "pattern": [
                    "id": id,
                    "speed": clamp(speed, 0, 255),
                    "intensity": clamp(intensity, 0, 255),
                    "color": safeColor
                ]
            ]
        }
    }
}

// MARK: - BLE encoding

extension LimiCommand {
    /// Binary BLE payload for write to characteristic 0xFF03.
    /// - CCT: `[0x01, ww, cw, brightness, channel]`
    /// - RGB: `[0x02, red, green, blue, brightness, channel]`
    /// - Power / Pattern: returns `nil` (use `toBLECSV()` for power; pattern is unsupported on BLE).
    public func toBLEBytes() -> Data? {
        switch self {
        case .cct(let channel, let brightness, let ww, let cw):
            let bytes: [UInt8] = [
                0x01,
                UInt8(clamp(ww, 0, 100)),
                UInt8(clamp(cw, 0, 100)),
                UInt8(clamp(brightness, 0, 100)),
                UInt8(clamp(channel, 0, 255))
            ]
            return Data(bytes)
        case .rgb(let channel, let brightness, let red, let green, let blue):
            let bytes: [UInt8] = [
                0x02,
                UInt8(clamp(red, 0, 255)),
                UInt8(clamp(green, 0, 255)),
                UInt8(clamp(blue, 0, 255)),
                UInt8(clamp(brightness, 0, 100)),
                UInt8(clamp(channel, 0, 255))
            ]
            return Data(bytes)
        case .power, .pattern:
            return nil
        }
    }

    /// UTF-8 text payload for write to characteristic 0xFF03 (alternative to binary).
    /// - CCT: `"ww,cw,brightness"`
    /// - Power: `"on"` / `"off"`
    /// - RGB / Pattern: returns `nil`.
    public func toBLECSV() -> String? {
        switch self {
        case .cct(_, let brightness, let ww, let cw):
            return "\(clamp(ww, 0, 100)),\(clamp(cw, 0, 100)),\(clamp(brightness, 0, 100))"
        case .power(_, let on):
            return on ? "on" : "off"
        case .rgb, .pattern:
            return nil
        }
    }
}

// MARK: - Helpers

@inline(__always)
private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
    return min(max(value, low), high)
}
