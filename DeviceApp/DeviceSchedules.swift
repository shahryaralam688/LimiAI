//
//  DeviceSchedules.swift
//  LIMI AI Device
//
//  App-side scheduling: turn a device (or one channel) on/off at a set
//  time, once or on repeat days. Commands ride the same LimiTransport
//  pipeline as manual control.
//
//  iOS limitation (by design): the app can only send commands while it
//  is running. The engine checks every 30 seconds in the foreground and
//  fires any schedule that came due in the last few minutes when the app
//  becomes active. A local notification also fires at the scheduled time
//  so the user can open the app if it was closed.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Model

@Model
final class DeviceSchedule {
    @Attribute(.unique) var scheduleID: UUID
    /// For individual devices this is the chennalMac. For hubs it is the
    /// virtual device id (`vd-…`) — matches the list filter in the UI.
    var deviceID: String
    /// Display name at creation time, shown in list + notifications.
    var deviceName: String
    /// 0 = all channels, otherwise a specific 1-based channel.
    var channel: Int
    /// Total channels on the device (needed for "all channels").
    var channelCount: Int
    var hour: Int
    var minute: Int
    /// Calendar weekdays (1 = Sunday … 7 = Saturday). Empty = one-time.
    var repeatDays: [Int]
    var turnOn: Bool
    var isEnabled: Bool
    var lastFiredAt: Date?

    // MARK: - Hub routing (added; defaults keep old schedules valid)

    /// True when the target is a virtual master (hub). Routes via `virtual_light_control`.
    var isHub: Bool = false
    /// Virtual device id used for hub fan-out (`vd-…`).
    var virtualDeviceID: String = ""
    /// Comma-separated member MACs — fallback group fan-out when no virtual id.
    var memberMacsRaw: String = ""

    // MARK: - Behaviour (added; how the light looks when turned ON)

    var brightness: Int = 70
    var ww: Int = 100
    var cw: Int = 40
    var red: Int = 255
    var green: Int = 255
    var blue: Int = 255
    /// When true the ON command is RGB; otherwise CCT (ww/cw).
    var useRGB: Bool = false

    init(
        deviceID: String,
        deviceName: String,
        channel: Int,
        channelCount: Int,
        hour: Int,
        minute: Int,
        repeatDays: [Int],
        turnOn: Bool,
        isEnabled: Bool = true,
        isHub: Bool = false,
        virtualDeviceID: String = "",
        memberMacs: [String] = [],
        brightness: Int = 70,
        ww: Int = 100,
        cw: Int = 40,
        red: Int = 255,
        green: Int = 255,
        blue: Int = 255,
        useRGB: Bool = false
    ) {
        self.scheduleID = UUID()
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.channel = channel
        self.channelCount = channelCount
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.turnOn = turnOn
        self.isEnabled = isEnabled
        self.lastFiredAt = nil
        self.isHub = isHub
        self.virtualDeviceID = virtualDeviceID
        self.memberMacsRaw = memberMacs.joined(separator: ",")
        self.brightness = brightness
        self.ww = ww
        self.cw = cw
        self.red = red
        self.green = green
        self.blue = blue
        self.useRGB = useRGB
    }

    /// Member MACs for hub fan-out fallback.
    var memberMacs: [String] {
        memberMacsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension DeviceSchedule {
    var timeText: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var repeatText: String {
        if repeatDays.isEmpty { return "Once" }
        if Set(repeatDays) == Set(1...7) { return "Every day" }
        let weekdays = Set(2...6)
        if Set(repeatDays) == weekdays { return "Weekdays" }
        if Set(repeatDays) == Set([1, 7]) { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return repeatDays.sorted()
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
    }

    var actionText: String { turnOn ? "Turn On" : "Turn Off" }

    var channelText: String {
        channel == 0 ? "All channels" : "Channel \(channel)"
    }
}

// MARK: - Engine

@MainActor
final class DeviceScheduleEngine: ObservableObject {
    static let shared = DeviceScheduleEngine()

    /// A schedule still fires if the app becomes active within this window
    /// after its due time (e.g. user opens the app from the notification).
    private static let graceInterval: TimeInterval = 5 * 60

    private var container: ModelContainer?
    private var timer: Timer?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
        startTimer()
        checkNow()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNow() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Fires every enabled schedule whose occurrence came due within the
    /// grace window and hasn't fired for that occurrence yet.
    func checkNow() {
        guard let container else { return }
        let context = container.mainContext
        let now = Date()

        guard let schedules = try? context.fetch(
            FetchDescriptor<DeviceSchedule>(predicate: #Predicate { $0.isEnabled })
        ) else { return }

        var didChange = false
        for schedule in schedules {
            guard let dueDate = latestOccurrence(of: schedule, before: now) else { continue }
            guard now.timeIntervalSince(dueDate) <= Self.graceInterval else { continue }
            if let lastFired = schedule.lastFiredAt, lastFired >= dueDate { continue }

            fire(schedule)
            schedule.lastFiredAt = now
            if schedule.repeatDays.isEmpty {
                schedule.isEnabled = false
            }
            didChange = true
        }
        if didChange { try? context.save() }
    }

    /// Most recent date (today, or the last matching repeat day) at which
    /// this schedule was due, at or before `reference`.
    private func latestOccurrence(of schedule: DeviceSchedule, before reference: Date) -> Date? {
        let calendar = Calendar.current

        for daysBack in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: -daysBack, to: reference),
                  let candidate = calendar.date(
                    bySettingHour: schedule.hour,
                    minute: schedule.minute,
                    second: 0,
                    of: day
                  ) else { continue }
            guard candidate <= reference else { continue }

            if schedule.repeatDays.isEmpty {
                return candidate
            }
            let weekday = calendar.component(.weekday, from: candidate)
            if schedule.repeatDays.contains(weekday) {
                return candidate
            }
        }
        return nil
    }

    private func fire(_ schedule: DeviceSchedule) {
        if schedule.isHub {
            fireHub(schedule)
        } else {
            fireIndividual(schedule)
        }
    }

    /// Command that describes how the light should behave for a channel.
    private func command(for schedule: DeviceSchedule, channel: Int) -> LimiCommand {
        guard schedule.turnOn else {
            return .power(channel: channel, on: false)
        }
        if schedule.useRGB {
            return .rgb(
                channel: channel,
                brightness: schedule.brightness,
                red: schedule.red,
                green: schedule.green,
                blue: schedule.blue
            )
        }
        return .cct(
            channel: channel,
            brightness: schedule.brightness,
            ww: schedule.ww,
            cw: schedule.cw
        )
    }

    /// Individual device: per-MAC transport, one command per targeted channel.
    private func fireIndividual(_ schedule: DeviceSchedule) {
        let deviceId = schedule.deviceID.uppercased()
        let channels: [Int] = schedule.channel == 0
            ? Array(1...max(schedule.channelCount, 1))
            : [schedule.channel]

        for channel in channels {
            let cmd = command(for: schedule, channel: channel)
            Task {
                try? await LimiTransport.shared.sendCommand(cmd, for: deviceId)
            }
            // Keep the control screens' persisted power state in sync.
            let key = "\(schedule.deviceID)-\(channel)"
            UserDefaults.standard.set(schedule.turnOn, forKey: "cct-lamp-state-\(key)")
            UserDefaults.standard.set(schedule.turnOn, forKey: "rgb-lamp-state-\(key)")
        }
    }

    /// Hub (virtual master): same path as the hub control screen —
    /// one `virtual_light_control` to the hub's virtual id, group fan-out as fallback.
    private func fireHub(_ schedule: DeviceSchedule) {
        let cmd = command(for: schedule, channel: 1)
        let virtualId = schedule.virtualDeviceID.trimmingCharacters(in: .whitespaces)
        let members = schedule.memberMacs

        LightControllingSocket.shared.connect()
        Task { @MainActor in
            if LightControllingSocket.shared.connectionStatus != .connected {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            if !virtualId.isEmpty, LightControllingSocket.shared.connectionStatus == .connected {
                LightControllingSocket.shared.sendVirtualLightControl(
                    virtualDeviceId: virtualId,
                    command: cmd.toVirtualCommandPayload()
                )
                return
            }

            if !members.isEmpty {
                try? await LimiTransport.shared.sendGroupCommand(cmd, deviceIds: members)
            }
        }
    }

    // MARK: - Local notifications

    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// (Re)registers the local notifications for a schedule.
    func syncNotifications(for schedule: DeviceSchedule) {
        removeNotifications(for: schedule)
        guard schedule.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "LIMI Schedule"
        content.body = "\(schedule.actionText): \(schedule.deviceName). Open the app to make sure it runs."
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        if schedule.repeatDays.isEmpty {
            var components = DateComponents()
            components.hour = schedule.hour
            components.minute = schedule.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: notificationID(schedule, weekday: nil),
                content: content,
                trigger: trigger
            ))
        } else {
            for weekday in schedule.repeatDays {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = schedule.hour
                components.minute = schedule.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(
                    identifier: notificationID(schedule, weekday: weekday),
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }

    func removeNotifications(for schedule: DeviceSchedule) {
        let ids = [notificationID(schedule, weekday: nil)] + (1...7).map { notificationID(schedule, weekday: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func notificationID(_ schedule: DeviceSchedule, weekday: Int?) -> String {
        if let weekday {
            return "limi-schedule-\(schedule.scheduleID.uuidString)-\(weekday)"
        }
        return "limi-schedule-\(schedule.scheduleID.uuidString)-once"
    }
}
