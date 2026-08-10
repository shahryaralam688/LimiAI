//
//  RoomControlViewModel.swift
//  LIMI AI Device
//
//  Room / group controller. Applies power / brightness / CCT / RGB with a
//  single Socket.IO group envelope (`GroupID` + `deviceIds` + `command`)
//  on event `group_light_control`.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class RoomControlViewModel: ObservableObject {
    let roomName: String

    @Published private(set) var devices: [WifiDevice]
    @Published var isOn = true
    /// 0…1 — maps to 0…100 brightness on the wire.
    @Published var brightness: Double = 0.7
    /// 0…1 CCT temperature dial (same mapping as CCTLEDPreviewView).
    @Published var temperature: Double = 0.15
    /// 0…1 hue for RGB channels.
    @Published var hue: Double = 0.08
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false
    @Published private(set) var isBusy = false
    @Published private(set) var canRetry = false

    private let displayNameProvider: (WifiDevice) -> String
    private var sendTask: Task<Void, Never>?
    private var lastCommand: LimiCommand?
    private var lastSuccessLabel: String?

    init(
        roomName: String,
        devices: [WifiDevice],
        displayNameProvider: @escaping (WifiDevice) -> String = { $0.deviceName }
    ) {
        self.roomName = roomName
        self.devices = devices.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
        self.displayNameProvider = displayNameProvider
    }

    func updateDevices(_ devices: [WifiDevice]) {
        self.devices = devices.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
    }

    // MARK: - Derived

    var onlineDevices: [WifiDevice] { devices.filter(\.isOnline) }
    var offlineCount: Int { devices.count - onlineDevices.count }
    var canControl: Bool { !onlineDeviceIds().isEmpty }

    var hasCCTChannels: Bool {
        devices.contains { device in
            (1...max(device.chennalCount, 1)).contains { channelType(for: device, channel: $0) == "CCT" }
        }
    }

    var hasRGBChannels: Bool {
        devices.contains { device in
            (1...max(device.chennalCount, 1)).contains { channelType(for: device, channel: $0) == "RGB" }
        }
    }

    func displayName(for device: WifiDevice) -> String {
        displayNameProvider(device)
    }

    // MARK: - Actions

    func setPower(_ on: Bool) {
        guard canControl else {
            presentBlocked()
            return
        }
        isOn = on
        let command: LimiCommand = on ? preferredLightCommand() : .power(channel: 1, on: false)
        enqueueSend(label: on ? "on" : "off", command: command)
    }

    func applyBrightness() {
        guard isOn else { return }
        guard canControl else {
            presentBlocked()
            return
        }
        enqueueSend(label: "updated", command: preferredLightCommand())
    }

    func applyCCT() {
        guard isOn, hasCCTChannels else { return }
        guard canControl else {
            presentBlocked()
            return
        }
        enqueueSend(label: "updated", command: cctCommand())
    }

    func applyRGB() {
        guard isOn, hasRGBChannels else { return }
        guard canControl else {
            presentBlocked()
            return
        }
        enqueueSend(label: "updated", command: rgbCommand())
    }

    func retryLastCommand() {
        guard let command = lastCommand, let label = lastSuccessLabel else { return }
        enqueueSend(label: label, command: command)
    }

    private func presentBlocked() {
        statusIsError = true
        canRetry = false
        statusMessage = DeviceAppGuidance.noOnlineInRoom
        DeviceAppGuidance.warningNotification()
    }

    private func enqueueSend(label: String, command: LimiCommand) {
        lastCommand = command
        lastSuccessLabel = label
        sendTask?.cancel()
        sendTask = Task { @MainActor in
            await sendGroup(command, successLabel: label)
        }
        print("🏠 [RoomControl] \(roomName) queued \(label)")
    }

    // MARK: - Group send (single emit)

    private func sendGroup(_ command: LimiCommand, successLabel: String) async {
        let deviceIds = onlineDeviceIds()
        guard !deviceIds.isEmpty else {
            presentBlocked()
            return
        }

        isBusy = true
        canRetry = false
        statusIsError = false
        statusMessage = "Sending to \(deviceIds.count) device\(deviceIds.count == 1 ? "" : "s")…"
        defer { isBusy = false }

        if Task.isCancelled { return }

        do {
            try await LimiTransport.shared.sendGroupCommand(
                command,
                groupId: LimiCommand.defaultGroupID,
                deviceIds: deviceIds
            )
            guard !Task.isCancelled else { return }
            statusIsError = false
            canRetry = false
            statusMessage = "Updated \(deviceIds.count) device\(deviceIds.count == 1 ? "" : "s")"
            DeviceAppGuidance.successNotification()
            print("🏠 [RoomControl] \(roomName) group → \(deviceIds.count) \(successLabel)")
        } catch {
            guard !Task.isCancelled else { return }
            statusIsError = true
            canRetry = true
            statusMessage = DeviceAppGuidance.message(for: error)
            DeviceAppGuidance.warningNotification()
            print("❌ [RoomControl] group send failed: \(error)")
        }
    }

    private func onlineDeviceIds() -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for device in onlineDevices {
            let id = LimiDeviceNaming.normalizedHardwareId(device.chennalMac)
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            ids.append(id)
        }
        return ids
    }

    // MARK: - Command builders

    private func preferredLightCommand() -> LimiCommand {
        if hasCCTChannels {
            return cctCommand()
        }
        if hasRGBChannels {
            return rgbCommand()
        }
        return cctCommand()
    }

    private func cctCommand() -> LimiCommand {
        let bri = Int(min(max((brightness * 100).rounded(), 0), 100))
        let levels = warmCoolLevels(for: temperature * 100)
        return .cct(
            channel: 1,
            brightness: bri,
            ww: levels.warm,
            cw: levels.cool
        )
    }

    private func rgbCommand() -> LimiCommand {
        let bri = Int(min(max((brightness * 100).rounded(), 0), 100))
        let rgb = rgbFromHue(hue)
        return .rgb(
            channel: 1,
            brightness: bri,
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue
        )
    }

    private func channelType(for device: WifiDevice, channel: Int) -> String {
        let index = channel - 1
        guard device.channelTypes.indices.contains(index) else { return "CCT" }
        return device.channelTypes[index].uppercased() == "RGB" ? "RGB" : "CCT"
    }

    /// Same mapping as CCTLEDPreviewView.
    private func warmCoolLevels(for sliderValue: Double) -> (cool: Int, warm: Int) {
        let clampedValue = min(max(sliderValue, 0), 100)
        if clampedValue == 50 {
            return (cool: 100, warm: 100)
        } else if clampedValue < 50 {
            let progressToWarm = (50 - clampedValue) / 50.0
            let coolLevel = Int((1.0 - progressToWarm) * 100.0)
            return (cool: max(0, min(100, coolLevel)), warm: 100)
        } else {
            let progressToCool = (clampedValue - 50) / 50.0
            let warmLevel = Int((1.0 - progressToCool) * 100.0)
            return (cool: 100, warm: max(0, min(100, warmLevel)))
        }
    }

    private func rgbFromHue(_ hue: Double) -> (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(hue: CGFloat(hue), saturation: 1, brightness: 1, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
