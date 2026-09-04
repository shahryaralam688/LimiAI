//
//  DeviceSchedulesView.swift
//  LIMI AI Device
//
//  Native per-device schedule list + editor (iOS Clock alarm style).
//  Home UI 1: neumorphic Soft UI with smooth transitions.
//

import SwiftUI
import SwiftData

struct DeviceSchedulesView: View {
    let device: WifiDevice
    let displayName: String

    @Environment(\.modelContext) private var modelContext
    @Query private var allSchedules: [DeviceSchedule]
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    @State private var editingSchedule: DeviceSchedule?
    @State private var showNewSchedule = false

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }
    private var usesHomeUI2: Bool { homeUITheme.selected == .two }

    private var schedules: [DeviceSchedule] {
        allSchedules
            .filter { $0.deviceID == device.chennalMac }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private var morphAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.88)
    }

    var body: some View {
        Group {
            if usesHomeUI1 {
                homeUI1Body
            } else if usesHomeUI2 {
                homeUI2Body
            } else {
                systemBody
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
        .homeUI2ControlNavigationChrome(enabled: usesHomeUI2)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if usesHomeUI1 {
                    Button {
                        DeviceAppGuidance.lightImpact()
                        showNewSchedule = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HomeUI1Color.accentGreen)
                            .frame(width: 34, height: 34)
                            .homeUI1CircleElevation(.two)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Schedule")
                } else if usesHomeUI2 {
                    Button {
                        DeviceAppGuidance.lightImpact()
                        showNewSchedule = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HomeUI2Color.textOnAccent)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(HomeUI2Color.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Schedule")
                } else {
                    Button {
                        showNewSchedule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Schedule")
                }
            }
        }
        .sheet(isPresented: $showNewSchedule) {
            DeviceScheduleEditView(device: device, displayName: displayName, schedule: nil)
        }
        .sheet(item: $editingSchedule) { schedule in
            DeviceScheduleEditView(device: device, displayName: displayName, schedule: schedule)
        }
        .animation(morphAnimation, value: schedules.count)
        .animation(HomeUI1Motion.soft, value: usesHomeUI1)
        .animation(HomeUI2Motion.soft, value: usesHomeUI2)
    }

    // MARK: - Home UI 1

    private var homeUI1Body: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if schedules.isEmpty {
                        HomeUI1EmptyStateCard(
                            title: "No Schedules",
                            message: "Schedule \(displayName) to turn on or off automatically at a set time.",
                            showsProgress: false,
                            onAdd: nil
                        )
                        Button {
                            DeviceAppGuidance.lightImpact()
                            showNewSchedule = true
                        } label: {
                            Label("Add Schedule", systemImage: "plus")
                                .font(HomeUI1Type.body(15))
                                .foregroundStyle(HomeUI1Color.accentGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeUI1ControlSectionCard(
                            title: displayName,
                            footer: "Schedules run while the app is open or recently active. A notification reminds you at the scheduled time."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(schedules, id: \.scheduleID) { schedule in
                                    homeUI1ScheduleRow(schedule)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .scale(scale: 0.96))
                                        ))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteSchedule(schedule)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func homeUI1ScheduleRow(_ schedule: DeviceSchedule) -> some View {
        HStack(spacing: 12) {
            Button {
                DeviceAppGuidance.lightImpact()
                editingSchedule = schedule
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.timeText)
                        .font(HomeUI1Type.title(22))
                        .foregroundStyle(
                            schedule.isEnabled
                                ? HomeUI1Color.textPrimary
                                : HomeUI1Color.textSecondary
                        )
                    Text(rowSubtitle(schedule))
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                DeviceAppGuidance.lightImpact()
                withAnimation(morphAnimation) {
                    schedule.isEnabled.toggle()
                    schedule.lastFiredAt = nil
                    try? modelContext.save()
                }
                DeviceScheduleEngine.shared.syncNotifications(for: schedule)
            } label: {
                Text(schedule.isEnabled ? "On" : "Off")
                    .font(HomeUI1Type.body(13))
                    .foregroundStyle(
                        schedule.isEnabled
                            ? HomeUI1Color.accentGreen
                            : HomeUI1Color.textSecondary
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .homeUI1Elevation(
                        schedule.isEnabled ? .recessed : .one,
                        cornerRadius: HomeUI1Radius.nav,
                        fill: HomeUI1Color.surface
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        .animation(morphAnimation, value: schedule.isEnabled)
    }

    // MARK: - Home UI 2

    private var homeUI2Body: some View {
        ZStack {
            HomeUI2ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if schedules.isEmpty {
                        HomeUI2EmptyStateCard(
                            title: "No Schedules",
                            message: "Schedule \(displayName) to turn on or off automatically at a set time.",
                            showsProgress: false,
                            onAdd: nil
                        )
                        Button {
                            DeviceAppGuidance.lightImpact()
                            showNewSchedule = true
                        } label: {
                            Label("Add Schedule", systemImage: "plus")
                                .font(HomeUI2Type.body(15))
                                .foregroundStyle(HomeUI2Color.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: HomeUI2Radius.sm, style: .continuous)
                                        .fill(HomeUI2Color.accent)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        HomeUI2ControlSectionCard(
                            title: displayName,
                            footer: "Schedules run while the app is open or recently active. A notification reminds you at the scheduled time."
                        ) {
                            VStack(spacing: 10) {
                                ForEach(schedules, id: \.scheduleID) { schedule in
                                    homeUI2ScheduleRow(schedule)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteSchedule(schedule)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func homeUI2ScheduleRow(_ schedule: DeviceSchedule) -> some View {
        HStack(spacing: 12) {
            Button {
                DeviceAppGuidance.lightImpact()
                editingSchedule = schedule
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.timeText)
                        .font(HomeUI2Type.title(22))
                        .foregroundStyle(
                            schedule.isEnabled
                                ? HomeUI2Color.textPrimary
                                : HomeUI2Color.textSecondary
                        )
                    Text(rowSubtitle(schedule))
                        .font(HomeUI2Type.caption(12))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                DeviceAppGuidance.lightImpact()
                withAnimation(morphAnimation) {
                    schedule.isEnabled.toggle()
                    schedule.lastFiredAt = nil
                    try? modelContext.save()
                }
                DeviceScheduleEngine.shared.syncNotifications(for: schedule)
            } label: {
                Text(schedule.isEnabled ? "On" : "Off")
                    .font(HomeUI2Type.body(13))
                    .foregroundStyle(
                        schedule.isEnabled
                            ? HomeUI2Color.textOnAccent
                            : HomeUI2Color.textSecondary
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(schedule.isEnabled ? HomeUI2Color.accent : HomeUI2Color.surfaceRaised)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surfaceRaised)
        .animation(morphAnimation, value: schedule.isEnabled)
    }

    // MARK: - System

    @ViewBuilder
    private var systemBody: some View {
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
                        systemScheduleRow(schedule)
                    }
                    .onDelete(perform: deleteSchedules)
                } footer: {
                    Text("Schedules run while the app is open or recently active. A notification reminds you at the scheduled time.")
                }
            }
        }
    }

    private func systemScheduleRow(_ schedule: DeviceSchedule) -> some View {
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

    private func deleteSchedule(_ schedule: DeviceSchedule) {
        withAnimation(morphAnimation) {
            DeviceScheduleEngine.shared.removeNotifications(for: schedule)
            modelContext.delete(schedule)
            try? modelContext.save()
        }
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
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    @State private var time = Date()
    @State private var turnOn = true
    @State private var channel = 0
    @State private var repeatDays: Set<Int> = []
    @State private var saveErrorMessage: String?

    // Behaviour when turned ON.
    @State private var brightness: Double = 70
    /// 0 = warm (ww 100 / cw 0) … 100 = cool (ww 0 / cw 100).
    @State private var coolness: Double = 40
    @State private var lightColor: Color = .white

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }

    /// RGB color control only for RGB channels on individual devices; hubs use CCT.
    private var isRGBSelection: Bool {
        if device.isVirtualMaster { return false }
        let types = device.channelTypes
        if channel == 0 {
            return !types.isEmpty && types.allSatisfy { $0.uppercased() == "RGB" }
        }
        let index = channel - 1
        return types.indices.contains(index) && types[index].uppercased() == "RGB"
    }

    private func rgbComponents(_ color: Color) -> (Int, Int, Int) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesHomeUI1 {
                    homeUI1Editor
                } else {
                    systemEditor
                }
            }
            .navigationTitle(schedule == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .homeUI1ControlNavigationChrome(enabled: usesHomeUI1)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        DeviceAppGuidance.lightImpact()
                        save()
                    }
                    .fontWeight(usesHomeUI1 ? .semibold : .regular)
                    .foregroundStyle(usesHomeUI1 ? HomeUI1Color.accentGreen : Color.accentColor)
                }
            }
            .onAppear(perform: loadExisting)
            .alert(
                "Couldn't Save Schedule",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "Something went wrong. Please try again.")
            }
        }
    }

    // MARK: - Home UI 1 editor

    private var homeUI1Editor: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1ControlSectionCard(title: "Time") {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .colorScheme(.light)
                    }

                    HomeUI1ControlSectionCard(title: "Action") {
                        HStack(spacing: 8) {
                            actionChip(title: "Turn On", selected: turnOn) {
                                withAnimation(HomeUI1Motion.soft) { turnOn = true }
                            }
                            actionChip(title: "Turn Off", selected: !turnOn) {
                                withAnimation(HomeUI1Motion.soft) { turnOn = false }
                            }
                        }

                        if !device.isVirtualMaster && device.chennalCount > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Channel")
                                    .font(HomeUI1Type.caption(12))
                                    .foregroundStyle(HomeUI1Color.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        channelChip(title: "All", value: 0)
                                        ForEach(1...device.chennalCount, id: \.self) { ch in
                                            channelChip(title: "Ch \(ch)", value: ch)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if turnOn {
                        HomeUI1ControlSectionCard(title: "Light") {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Brightness")
                                            .font(HomeUI1Type.caption(12))
                                            .foregroundStyle(HomeUI1Color.textSecondary)
                                        Spacer()
                                        Text("\(Int(brightness))%")
                                            .font(HomeUI1Type.caption(12))
                                            .foregroundStyle(HomeUI1Color.textSecondary)
                                    }
                                    Slider(value: $brightness, in: 1...100, step: 1)
                                        .tint(HomeUI1Color.accentGreen)
                                }

                                if isRGBSelection {
                                    ColorPicker(selection: $lightColor, supportsOpacity: false) {
                                        Text("Color")
                                            .font(HomeUI1Type.body(14))
                                            .foregroundStyle(HomeUI1Color.textPrimary)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Warm")
                                                .font(HomeUI1Type.caption(12))
                                                .foregroundStyle(HomeUI1Color.textSecondary)
                                            Spacer()
                                            Text("Cool")
                                                .font(HomeUI1Type.caption(12))
                                                .foregroundStyle(HomeUI1Color.textSecondary)
                                        }
                                        Slider(value: $coolness, in: 0...100, step: 1)
                                            .tint(HomeUI1Color.accentGreen)
                                    }
                                }
                            }
                        }
                    }

                    HomeUI1ControlSectionCard(
                        title: "Repeat",
                        footer: repeatDays.isEmpty
                            ? "Runs once at the next \(timeOnlyText)."
                            : "Repeats every \(DeviceScheduleEditView.repeatSummary(repeatDays))."
                    ) {
                        VStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { weekday in
                                let selected = repeatDays.contains(weekday)
                                Button {
                                    DeviceAppGuidance.lightImpact()
                                    withAnimation(HomeUI1Motion.soft) {
                                        if selected {
                                            repeatDays.remove(weekday)
                                        } else {
                                            repeatDays.insert(weekday)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(Calendar.current.weekdaySymbols[weekday - 1])
                                            .font(HomeUI1Type.body(15))
                                            .foregroundStyle(HomeUI1Color.textPrimary)
                                        Spacer()
                                        if selected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(HomeUI1Color.accentGreen)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .homeUI1Elevation(
                                        selected ? .recessed : .one,
                                        cornerRadius: HomeUI1Radius.nav,
                                        fill: HomeUI1Color.surface
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func actionChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(HomeUI1Type.body(13))
                .foregroundStyle(selected ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .homeUI1Elevation(
                    selected ? .recessed : .one,
                    cornerRadius: HomeUI1Radius.nav,
                    fill: HomeUI1Color.surface
                )
        }
        .buttonStyle(.plain)
    }

    private func channelChip(title: String, value: Int) -> some View {
        let selected = channel == value
        return Button {
            withAnimation(HomeUI1Motion.soft) { channel = value }
        } label: {
            Text(title)
                .font(HomeUI1Type.body(12))
                .foregroundStyle(selected ? HomeUI1Color.accentGreen : HomeUI1Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .homeUI1Elevation(
                    selected ? .recessed : .one,
                    cornerRadius: HomeUI1Radius.nav,
                    fill: HomeUI1Color.surface
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - System editor

    private var systemEditor: some View {
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

                if !device.isVirtualMaster && device.chennalCount > 1 {
                    Picker("Channel", selection: $channel) {
                        Text("All channels").tag(0)
                        ForEach(1...device.chennalCount, id: \.self) { ch in
                            Text("Channel \(ch)").tag(ch)
                        }
                    }
                }
            }

            if turnOn {
                Section("Light") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Brightness")
                            Spacer()
                            Text("\(Int(brightness))%").foregroundStyle(.secondary)
                        }
                        Slider(value: $brightness, in: 1...100, step: 1)
                    }

                    if isRGBSelection {
                        ColorPicker("Color", selection: $lightColor, supportsOpacity: false)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Warm")
                                Spacer()
                                Text("Cool").foregroundStyle(.secondary)
                            }
                            Slider(value: $coolness, in: 0...100, step: 1)
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
        brightness = Double(schedule.brightness)
        coolness = Double(schedule.cw)
        lightColor = Color(
            red: Double(schedule.red) / 255,
            green: Double(schedule.green) / 255,
            blue: Double(schedule.blue) / 255
        )
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let useRGB = isRGBSelection
        let (r, g, b) = rgbComponents(lightColor)
        let cwValue = Int(coolness.rounded())
        let wwValue = 100 - cwValue
        let brightnessValue = Int(brightness.rounded())
        let isHub = device.isVirtualMaster
        let virtualID = device.uuid
        let members = device.memberChannelMacs ?? []

        let target: DeviceSchedule
        if let schedule {
            schedule.hour = hour
            schedule.minute = minute
            schedule.turnOn = turnOn
            schedule.channel = channel
            schedule.repeatDays = Array(repeatDays)
            schedule.isEnabled = true
            schedule.lastFiredAt = nil
            schedule.isHub = isHub
            schedule.virtualDeviceID = virtualID
            schedule.memberMacsRaw = members.joined(separator: ",")
            schedule.brightness = brightnessValue
            schedule.ww = wwValue
            schedule.cw = cwValue
            schedule.red = r
            schedule.green = g
            schedule.blue = b
            schedule.useRGB = useRGB
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
                turnOn: turnOn,
                isHub: isHub,
                virtualDeviceID: virtualID,
                memberMacs: members,
                brightness: brightnessValue,
                ww: wwValue,
                cw: cwValue,
                red: r,
                green: g,
                blue: b,
                useRGB: useRGB
            )
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
        } catch {
            if schedule == nil {
                modelContext.delete(target)
            }
            saveErrorMessage = "Your schedule couldn't be saved. Please try again."
            return
        }

        DeviceScheduleEngine.shared.requestNotificationPermissionIfNeeded()
        DeviceScheduleEngine.shared.syncNotifications(for: target)
        dismiss()
    }
}
