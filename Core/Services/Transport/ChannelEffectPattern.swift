//
//  ChannelEffectPattern.swift
//  Limi
//
//  Named multi-channel light patterns for Master / hub control.
//  Wire shape (envelope):
//    { "deviceId": "<id>", "command": { "channel": 0, "pattern": { ... } } }
//  Socket event name is intentionally not bound here yet.
//

import Foundation

// MARK: - Pattern name

/// Firmware / backend pattern names (`pattern.name`).
public enum ChannelEffectPatternName: String, CaseIterable, Identifiable, Equatable, Sendable {
    case off
    case solid
    case wave
    case chase
    case breathe
    case alternate
    case sparkle
    case comet

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .off: return "Off"
        case .solid: return "Solid"
        case .wave: return "Wave"
        case .chase: return "Chase"
        case .breathe: return "Breathe"
        case .alternate: return "Alternate"
        case .sparkle: return "Sparkle"
        case .comet: return "Comet"
        }
    }

    /// Patterns that expect an explicit channel list in the payload.
    public var usesChannelList: Bool {
        switch self {
        case .chase, .alternate, .comet: return true
        case .off, .solid, .wave, .breathe, .sparkle: return false
        }
    }
}

// MARK: - Pattern payload

/// One named pattern ready to encode as `command.pattern`.
public struct ChannelEffectPattern: Equatable, Sendable {
    public var name: ChannelEffectPatternName
    /// Always `"channels"` for this family of effects.
    public var target: String
    /// Outer command channel (samples use `0`).
    public var commandChannel: Int
    public var brightness: Int?
    public var minBrightness: Int?
    public var ww: Int?
    public var cw: Int?
    public var speed: Int?
    /// 1-based hub / strip channel indices when the effect spans multiple channels.
    public var channels: [Int]?

    public init(
        name: ChannelEffectPatternName,
        target: String = "channels",
        commandChannel: Int = 0,
        brightness: Int? = nil,
        minBrightness: Int? = nil,
        ww: Int? = nil,
        cw: Int? = nil,
        speed: Int? = nil,
        channels: [Int]? = nil
    ) {
        self.name = name
        self.target = target
        self.commandChannel = commandChannel
        self.brightness = brightness
        self.minBrightness = minBrightness
        self.ww = ww
        self.cw = cw
        self.speed = speed
        self.channels = channels
    }

    /// Inner `pattern` object only.
    public func patternObject() -> [String: Any] {
        var pattern: [String: Any] = [
            "target": target,
            "name": name.rawValue,
        ]
        if let brightness { pattern["brightness"] = Self.clamp(brightness, 0, 100) }
        if let minBrightness { pattern["minBrightness"] = Self.clamp(minBrightness, 0, 100) }
        if let ww { pattern["ww"] = Self.clamp(ww, 0, 100) }
        if let cw { pattern["cw"] = Self.clamp(cw, 0, 100) }
        if let speed { pattern["speed"] = Self.clamp(speed, 0, 255) }
        if let channels, !channels.isEmpty {
            pattern["channels"] = channels.map { Self.clamp($0, 1, 64) }
        }
        return pattern
    }

    /// Inner `"command": { "channel": …, "pattern": { … } }`.
    public func commandPayload() -> [String: Any] {
        [
            "channel": commandChannel,
            "pattern": patternObject(),
        ]
    }

    /// Full envelope `{ "deviceId", "command" }` — use once the socket event is decided.
    public func toJSONEnvelope(deviceId: String) -> [String: Any] {
        [
            "deviceId": deviceId,
            "command": commandPayload(),
        ]
    }

    public func toJSONData(deviceId: String) -> Data {
        let envelope = toJSONEnvelope(deviceId: deviceId)
        return (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }
}

// MARK: - Catalog (defaults matching provided samples)

public enum ChannelEffectPatternCatalog {
    /// Presets for Master Device controller UI. Socket emit is left to the caller.
    public static let masterDefaults: [ChannelEffectPattern] = [
        .off,
        .solid(brightness: 80, ww: 100, cw: 100),
        .wave(brightness: 85, minBrightness: 10, ww: 100, cw: 100, speed: 140),
        .chase(channels: [1, 2, 3, 4], brightness: 100, minBrightness: 5, ww: 100, cw: 40, speed: 180),
        .breathe(brightness: 90, minBrightness: 15, ww: 70, cw: 100, speed: 100),
        .alternate(channels: [1, 2, 3, 4], brightness: 100, minBrightness: 0, ww: 100, cw: 100, speed: 120),
        .sparkle(brightness: 100, minBrightness: 10, ww: 100, cw: 80, speed: 180),
        .comet(channels: [1, 2, 3, 4, 5, 6, 7, 8], brightness: 100, minBrightness: 5, ww: 100, cw: 100, speed: 160),
    ]

    /// Hub-count aware presets: multi-channel patterns get `1…hubCount`.
    public static func masterDefaults(hubCount: Int) -> [ChannelEffectPattern] {
        let count = max(hubCount, 1)
        let hubChannels = Array(1...count)
        return [
            .off,
            .solid(brightness: 80, ww: 100, cw: 100),
            .wave(brightness: 85, minBrightness: 10, ww: 100, cw: 100, speed: 140),
            .chase(channels: hubChannels, brightness: 100, minBrightness: 5, ww: 100, cw: 40, speed: 180),
            .breathe(brightness: 90, minBrightness: 15, ww: 70, cw: 100, speed: 100),
            .alternate(channels: hubChannels, brightness: 100, minBrightness: 0, ww: 100, cw: 100, speed: 120),
            .sparkle(brightness: 100, minBrightness: 10, ww: 100, cw: 80, speed: 180),
            .comet(channels: hubChannels, brightness: 100, minBrightness: 5, ww: 100, cw: 100, speed: 160),
        ]
    }
}

// MARK: - Convenience builders

public extension ChannelEffectPattern {
    static let off = ChannelEffectPattern(name: .off)

    static func solid(brightness: Int, ww: Int, cw: Int) -> ChannelEffectPattern {
        ChannelEffectPattern(name: .solid, brightness: brightness, ww: ww, cw: cw)
    }

    static func wave(
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .wave,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed
        )
    }

    static func chase(
        channels: [Int],
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .chase,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed,
            channels: channels
        )
    }

    static func breathe(
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .breathe,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed
        )
    }

    static func alternate(
        channels: [Int],
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .alternate,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed,
            channels: channels
        )
    }

    static func sparkle(
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .sparkle,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed
        )
    }

    static func comet(
        channels: [Int],
        brightness: Int,
        minBrightness: Int,
        ww: Int,
        cw: Int,
        speed: Int
    ) -> ChannelEffectPattern {
        ChannelEffectPattern(
            name: .comet,
            brightness: brightness,
            minBrightness: minBrightness,
            ww: ww,
            cw: cw,
            speed: speed,
            channels: channels
        )
    }
}
