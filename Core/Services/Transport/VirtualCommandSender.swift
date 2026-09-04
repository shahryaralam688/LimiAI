//
//  VirtualCommandSender.swift
//  Limi
//
//  Throttled Socket.IO sender for virtual (master) device light control.
//  Emits `virtual_light_control` with { virtual_device_id, command }.
//

import Foundation

// MARK: - Virtual command payload

extension LimiCommand {
    /// Backend virtual-device command shape (distinct from per-MAC `commandPayload()`).
    func toVirtualCommandPayload() -> [String: Any] {
        switch self {
        case .power(_, let on):
            return ["state": on ? "on" : "off"]
        case .cct(_, let brightness, let ww, let cw):
            return [
                "power": "on",
                "brightness": Self.clampVirtual(brightness, 0, 100),
                "ww": Self.clampVirtual(ww, 0, 100),
                "cw": Self.clampVirtual(cw, 0, 100),
            ]
        case .rgb(_, let brightness, let red, let green, let blue):
            return [
                "power": "on",
                "brightness": Self.clampVirtual(brightness, 0, 100),
                "red": Self.clampVirtual(red, 0, 255),
                "green": Self.clampVirtual(green, 0, 255),
                "blue": Self.clampVirtual(blue, 0, 255),
            ]
        case .pattern(let channel, let id, let speed, let intensity, let color):
            let safeColor: [Int] = (0..<3).map { idx in
                idx < color.count ? Self.clampVirtual(color[idx], 0, 255) : 0
            }
            return [
                "power": "on",
                "channel": channel,
                "pattern": [
                    "id": id,
                    "speed": Self.clampVirtual(speed, 0, 255),
                    "intensity": Self.clampVirtual(intensity, 0, 255),
                    "color": safeColor,
                ],
            ]
        }
    }

    private static func clampVirtual(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }
}

// MARK: - Throttled virtual sender

final class VirtualThrottledSender: ObservableObject {
    private let virtualDeviceId: String

    private var pending: LimiCommand?
    private var lastSent: Date = .distantPast
    private var scheduledWork: DispatchWorkItem?

    init(virtualDeviceId: String) {
        self.virtualDeviceId = virtualDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let pendingCommand = pending {
            LightControllingSocket.shared.sendVirtualLightControl(
                virtualDeviceId: virtualDeviceId,
                command: pendingCommand.toVirtualCommandPayload()
            )
        }
        scheduledWork?.cancel()
    }

    func update(_ command: LimiCommand) {
        pending = command
        let elapsed = Date().timeIntervalSince(lastSent)
        if elapsed >= ThrottledSender.throttleInterval {
            fireNow()
        } else if scheduledWork == nil {
            let delay = ThrottledSender.throttleInterval - elapsed
            scheduleFire(after: delay)
        }
    }

    func flush() {
        scheduledWork?.cancel()
        scheduledWork = nil
        guard let command = pending else { return }
        pending = nil
        send(command)
    }

    func sendOneShot(_ command: LimiCommand) {
        scheduledWork?.cancel()
        scheduledWork = nil
        pending = nil
        send(command)
    }

    private func fireNow() {
        guard let command = pending else { return }
        pending = nil
        send(command)
    }

    private func scheduleFire(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            self?.scheduledWork = nil
            self?.fireNow()
        }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func send(_ command: LimiCommand) {
        lastSent = Date()
        LightControllingSocket.shared.connect()
        LightControllingSocket.shared.sendVirtualLightControl(
            virtualDeviceId: virtualDeviceId,
            command: command.toVirtualCommandPayload()
        )
    }
}

// MARK: - Routes CCT UI to either per-device transport or virtual socket

public final class CommandRouter: ObservableObject {
    private let deviceSender: ThrottledSender?
    private let virtualSender: VirtualThrottledSender?

    public init(deviceId: String?, virtualDeviceId: String?) {
        let trimmedVirtual = virtualDeviceId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedVirtual.isEmpty {
            virtualSender = VirtualThrottledSender(virtualDeviceId: trimmedVirtual)
            deviceSender = nil
        } else {
            virtualSender = nil
            deviceSender = ThrottledSender(deviceId: (deviceId ?? "unknown").uppercased())
        }
    }

    public func update(_ command: LimiCommand) {
        if let virtualSender {
            virtualSender.update(command)
        } else {
            deviceSender?.update(command)
        }
    }

    public func flush() {
        if let virtualSender {
            virtualSender.flush()
        } else {
            deviceSender?.flush()
        }
    }

    public func sendOneShot(_ command: LimiCommand) {
        if let virtualSender {
            virtualSender.sendOneShot(command)
        } else {
            deviceSender?.sendOneShot(command)
        }
    }
}
