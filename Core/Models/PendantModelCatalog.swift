//
//  PendantModelCatalog.swift
//  Limi
//
//  Maps backend `pendantTypes` (from Socket.IO `device_status`) to bundled
//  USDZ names under art.scnassets. UNKNOWN / missing → a default pendant.
//

import Combine
import Foundation

enum PendantModelCatalog {
    /// Bundled resource names (no `.usdz`) under `art.scnassets`.
    static let models: [String] = [
        "ball_Chrome_pendant",
        "ball_Neils_pendant",
        "bar_orbit_pendant",
        "bar_pendant",
        "bar_speaker_pendant",
        "bar_veum_pendant"
    ]

    /// Used when firmware reports UNKNOWN / empty / unrecognized.
    static let unknownDefault = "ball_Chrome_pendant"

    /// Common backend / firmware aliases → bundled stem.
    private static let aliases: [String: String] = [
        "CHROME": "ball_Chrome_pendant",
        "BALLCHROME": "ball_Chrome_pendant",
        "BALLCHROMEPENDANT": "ball_Chrome_pendant",
        "NEILS": "ball_Neils_pendant",
        "BALLNEILS": "ball_Neils_pendant",
        "BALLNEILSPENDANT": "ball_Neils_pendant",
        "ORBIT": "bar_orbit_pendant",
        "BARORBIT": "bar_orbit_pendant",
        "BARORBITPENDANT": "bar_orbit_pendant",
        "BAR": "bar_pendant",
        "BARPENDANT": "bar_pendant",
        "SPEAKER": "bar_speaker_pendant",
        "BARSPEAKER": "bar_speaker_pendant",
        "BARSPEAKERPENDANT": "bar_speaker_pendant",
        "VEUM": "bar_veum_pendant",
        "BARVEUM": "bar_veum_pendant",
        "BARVEUMPENDANT": "bar_veum_pendant"
    ]

    /// Resolve a 3D model name from a raw `pendantTypes` string.
    static func bundledName(for pendantTypes: String?) -> String {
        let raw = (pendantTypes ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return unknownDefault }

        let upper = raw.uppercased()
        if upper == "UNKNOWN" || upper == "NONE" || upper == "N/A" {
            return unknownDefault
        }

        let normalized = normalize(raw)

        if let alias = aliases[normalized] ?? aliases[upper] {
            return alias
        }

        // Exact match on bundled file stem (with or without .usdz).
        for model in models {
            let modelNorm = normalize(model)
            if normalized == modelNorm || normalized == modelNorm + "USDZ" {
                return model
            }
        }

        // Partial / token match: "Chrome", "bar_veum", "Neils Pendant", etc.
        for model in models {
            let modelNorm = normalize(model)
            if normalized.contains(modelNorm) || modelNorm.contains(normalized) {
                return model
            }
            let tokens = model
                .split(separator: "_")
                .map { normalize(String($0)) }
                .filter { !$0.isEmpty && $0 != "PENDANT" && $0 != "BALL" && $0 != "BAR" }
            if tokens.contains(where: { normalized.contains($0) || $0.contains(normalized) }) {
                return model
            }
        }

        return unknownDefault
    }

    /// Convenience: look up the last known pendant type for a device MAC / ID.
    static func bundledName(forDeviceId deviceId: String?) -> String {
        bundledName(for: DevicePendantTypeStore.shared.pendantType(for: deviceId))
    }

    private static func normalize(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: ".USDZ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

/// Caches `pendantTypes` from Socket.IO `device_status` per device ID.
final class DevicePendantTypeStore: ObservableObject {
    static let shared = DevicePendantTypeStore()

    @Published private(set) var pendantTypesByDeviceId: [String: String] = [:]

    private init() {}

    func pendantType(for deviceId: String?) -> String? {
        guard let key = Self.normalizedId(deviceId), !key.isEmpty else { return nil }
        return pendantTypesByDeviceId[key]
    }

    func update(deviceId: String, pendantTypes: String?) {
        guard let key = Self.normalizedId(deviceId), !key.isEmpty else { return }
        let trimmed = pendantTypes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return }

        let apply = { [weak self] in
            guard let self, self.pendantTypesByDeviceId[key] != trimmed else { return }
            self.pendantTypesByDeviceId[key] = trimmed
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Aligns app IDs (`LIMI1CH-80B54ECCA7F4`) with socket IDs (`80B54ECCA7F4`).
    private static func normalizedId(_ deviceId: String?) -> String? {
        guard let raw = deviceId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        let upper = raw.uppercased()

        if let dash = upper.lastIndex(of: "-") {
            let suffix = String(upper[upper.index(after: dash)...])
            if isTwelveHex(suffix) { return suffix }
        }

        let hexOnly = upper.filter(\.isHexDigit)
        if hexOnly.count >= 12 {
            return String(hexOnly.suffix(12))
        }
        return upper
    }

    private static func isTwelveHex(_ value: String) -> Bool {
        value.count == 12 && value.allSatisfy(\.isHexDigit)
    }
}
