//
//  ThrottledSender.swift
//  Limi
//
//  Slider throttle that satisfies the firmware spec exactly:
//   • While dragging: send latest value every 30–50 ms; drop intermediate values.
//   • On release / deinit: send one guaranteed final value immediately.
//
//  Works equally for MQTT, WebSocket and BLE because it talks only to
//  LimiTransport.sendCommand(_:for:).
//

import Foundation

public final class ThrottledSender: ObservableObject {
    /// Per spec: 30–50 ms. We use 40 ms for the steady-state cadence.
    public static let throttleInterval: TimeInterval = 0.04

    private let deviceId: String
    private let transport: LimiTransport

    private var pending: LimiCommand?
    private var lastSent: Date = .distantPast
    private var scheduledWork: DispatchWorkItem?
    private let workQueue = DispatchQueue.main

    /// Last error surfaced by the underlying transport (for debug UI).
    @Published public private(set) var lastError: LimiTransportError?

    public init(deviceId: String, transport: LimiTransport = .shared) {
        self.deviceId = deviceId.uppercased()
        self.transport = transport
    }

    deinit {
        // Final-value guarantee even when the view goes away mid-drag.
        if let pendingCommand = pending {
            let id = deviceId
            let t = transport
            Task.detached {
                try? await t.sendCommand(pendingCommand, for: id)
            }
        }
        scheduledWork?.cancel()
    }

    // MARK: - Public API

    /// Call from slider `onChanged`. Coalesces with any earlier pending value
    /// (older one is dropped — never queued).
    public func update(_ command: LimiCommand) {
        pending = command
        let elapsed = Date().timeIntervalSince(lastSent)
        if elapsed >= Self.throttleInterval {
            fireNow()
        } else if scheduledWork == nil {
            let delay = Self.throttleInterval - elapsed
            scheduleFire(after: delay)
        }
        // If work is already scheduled, we just updated `pending`; the next
        // fire will pick up the newest value. Old values are silently dropped.
    }

    /// Call from slider `onEnded` / power toggles / explicit one-shot sends.
    /// Sends the latest value immediately and clears the pending state.
    public func flush() {
        scheduledWork?.cancel()
        scheduledWork = nil
        guard let command = pending else { return }
        pending = nil
        send(command)
    }

    /// Convenience for one-shot commands (power toggles, pattern selection)
    /// that don't go through a slider drag.
    public func sendOneShot(_ command: LimiCommand) {
        // Replace any pending slider value — a power toggle should win.
        scheduledWork?.cancel()
        scheduledWork = nil
        pending = nil
        send(command)
    }

    // MARK: - Internal

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
        workQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func send(_ command: LimiCommand) {
        lastSent = Date()
        let deviceId = self.deviceId
        let transport = self.transport
        Task { [weak self] in
            do {
                try await transport.sendCommand(command, for: deviceId)
                await MainActor.run { self?.lastError = nil }
            } catch let err as LimiTransportError {
                await MainActor.run { self?.lastError = err }
                print("⚠️ [ThrottledSender] \(deviceId) failed: \(err.localizedDescription)")
            } catch {
                await MainActor.run { self?.lastError = .deviceUnreachable }
                print("⚠️ [ThrottledSender] \(deviceId) unknown error: \(error.localizedDescription)")
            }
        }
    }
}
