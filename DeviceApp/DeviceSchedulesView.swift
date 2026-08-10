//
//  DeviceSchedulesView.swift
//  LIMI AI Device
//
//  Native per-device schedule list + editor (iOS Clock alarm style).
//

import SwiftUI
import SwiftData

struct DeviceSchedulesView: View {
    let device: WifiDevice
    let displayName: String

    @Environment(\.modelContext) private var modelContext
    @Query private var allSchedules: [DeviceSchedule]
    @State private var editingSchedule: DeviceSchedule?
    @State private var showNewSchedule = false

    private var schedules: [DeviceSchedule] {
        allSchedules
            .filter { $0.deviceID == device.chennalMac }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    var body: some View {
        Group {
            if schedules.isEmpty {
                ContentUnavailableView {
                    Label("No Schedules", systemImage: "clock")
                } description: {
                    Text("Schedule \(displayName) to turn on or off automatically at a set time.")
                } actions: {
                    Button {
                        showNewSchedule = true
                    } label: {
                        Label("Add Schedule", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section {
                        ForEach(schedules, id: \.scheduleID) { schedule in
                            scheduleRow(schedule)
                        }
                        .onDelete(perform: deleteSchedules)
                    } footer: {
                        Text("Schedules run while the app is open or recently active. A notification reminds you at the scheduled time.")
                    }
                }
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewSchedule = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Schedule")
            }
        }
        .sheet(isPresented: $showNewSchedule) {
            DeviceScheduleEditView(device: device, displayName: displayName, schedule: nil)
        }
        .sheet(item: $editingSchedule) { schedule in
            DeviceScheduleEditView(device: device, displayName: displayName, schedule: schedule)
        }
    }

    private func scheduleRow(_ schedule: DeviceSchedule) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.timeText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)
                Text(rowSubtitle(schedule))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { enabled in
                    schedule.isEnabled = enabled
                    schedule.lastFiredAt = nil
                    try? modelContext.save()
                    DeviceScheduleEngine.shared.syncNotifications(for: schedule)
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { editingSchedule = schedule }
    }

    private func rowSubtitle(_ schedule: DeviceSchedule) -> String {
        var parts = [schedule.actionText, schedule.repeatText]
        if device.chennalCount > 1 {
            parts.append(schedule.channelText)
        }
        return parts.joined(separator: " • ")
    }

    private func deleteSchedules(at offsets: IndexSet) {
        let items = schedules
        for index in offsets {
            let schedule = items[index]
            DeviceScheduleEngine.shared.removeNotifications(for: schedule)
            modelContext.delete(schedule)
        }
        try? modelContext.save()
    }
}

// MARK: - Editor

extension DeviceSchedule: Identifiable {
    public var id: UUID { scheduleID }
}

struct DeviceScheduleEditView: View {
    let device: WifiDevice
    let displayName: String
    /// nil = creating a new schedule.
    let schedule: DeviceSchedule?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var time = Date()
    @State private var turnOn = true
    @State private var channel = 0
    @State private var repeatDays: Set<Int> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section {
                    Picker("Action", selection: $turnOn) {
                        Text("Turn On").tag(true)
                        Text("Turn Off").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if device.chennalCount > 1 {
                        Picker("Channel", selection: $channel) {
                            Text("All channels").tag(0)
                            ForEach(1...device.chennalCount, id: \.self) { ch in
                                Text("Channel \(ch)").tag(ch)
                            }
                        }
                    }
                }

                Section("Repeat") {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            if repeatDays.contains(weekday) {
                                repeatDays.remove(weekday)
                            } else {
                                repeatDays.insert(weekday)
                            }
                        } label: {
                            HStack {
                                Text(Calendar.current.weekdaySymbols[weekday - 1])
                                    .foregroundStyle(.primary)
                                Spacer()
                                if repeatDays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DeviceTheme.accent)
                                }
                            }
                        }
                    }
                } 

                Section {
                } footer: {
                    Text(repeatDays.isEmpty
                         ? "Runs once at the next \(timeOnlyText)."
                         : "Repeats every \(DeviceScheduleEditView.repeatSummary(repeatDays)).")
                }
            }
            .navigationTitle(schedule == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var timeOnlyText: String {
        time.formatted(date: .omitted, time: .shortened)
    }

    private static func repeatSummary(_ days: Set<Int>) -> String {
        if days == Set(1...7) { return "day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.sorted()
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
    }

    private func loadExisting() {
        guard let schedule else { return }
        var components = DateComponents()
        components.hour = schedule.hour
        components.minute = schedule.minute
        time = Calendar.current.date(from: components) ?? Date()
        turnOn = schedule.turnOn
        channel = schedule.channel
        repeatDays = Set(schedule.repeatDays)
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let target: DeviceSchedule
        if let schedule {
            schedule.hour = hour
            schedule.minute = minute
            schedule.turnOn = turnOn
            schedule.channel = channel
            schedule.repeatDays = Array(repeatDays)
            schedule.isEnabled = true
            schedule.lastFiredAt = nil
            target = schedule
        } else {
            target = DeviceSchedule(
                deviceID: device.chennalMac,
                deviceName: displayName,
                channel: channel,
                channelCount: device.chennalCount,
                hour: hour,
                minute: minute,
                repeatDays: Array(repeatDays),
                turnOn: turnOn
            )
            modelContext.insert(target)
        }

        try? modelContext.save()
        DeviceScheduleEngine.shared.requestNotificationPermissionIfNeeded()
        DeviceScheduleEngine.shared.syncNotifications(for: target)
        dismiss()
    }
}
