//
//  SchedulingView.swift
//  Limi
//
//  Created by LIMI on 03/11/2025.
//

import SwiftUI

// MARK: - Shared Model

/// Single schedule / routine item
/// Acts like an IoT light schedule: type, time, description, completed flag.
final class Schedule: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published var iconName: String
    @Published var type: String          // e.g. "Morning Routine ☀️"
    @Published var time: Date            // scheduled time
    @Published var notes: String         // user-written description (1–2 lines)
    @Published var isCompleted: Bool     // run successfully / in the past
    
    init(
        iconName: String,
        type: String,
        time: Date,
        notes: String,
        isCompleted: Bool = false
    ) {
        self.iconName = iconName
        self.type = type
        self.time = time
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

// MARK: - Main View

struct SchedulingView: View {
    enum Tab: String, CaseIterable {
        case active = "Active"
        case upcoming = "Upcoming"
        case completed = "Completed"
    }
    
    @State private var selectedTab: Tab = .active
    @State private var schedules: [Schedule] = SampleSchedules.initial()
    @State private var selectedSchedule: Schedule? = nil
    
    // MARK: - Time Helpers
    
    private var now: Date { Date() }
    private var oneHourFromNow: Date {
        Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
    }
    
    // MARK: - Derived Lists
    
    /// Schedules running within the next 1 hour (today)
    private var activeSchedules: [Schedule] {
        schedules.filter { schedule in
            guard !schedule.isCompleted else { return false }
            return schedule.time >= now &&
                   schedule.time <= oneHourFromNow &&
                   Calendar.current.isDate(schedule.time, inSameDayAs: now)
        }
    }
    
    /// Schedules coming later today but not in the 1-hour active window
    private var upcomingSchedules: [Schedule] {
        schedules.filter { schedule in
            guard !schedule.isCompleted else { return false }
            return schedule.time > oneHourFromNow &&
                   Calendar.current.isDate(schedule.time, inSameDayAs: now)
        }
    }
    
    /// Schedules that already ran (or explicitly marked completed)
    private var completedSchedules: [Schedule] {
        schedules.filter { schedule in
            schedule.isCompleted || schedule.time < now
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                headerView
                contentView
            }
        }
        .sheet(item: $selectedSchedule) { schedule in
            SchedulingSummaryView(schedule: schedule)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("My Routines")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.themeWhite)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            tabSelectorView
        }
        .padding(.top, 24)
        .padding(.bottom, 38)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.appSurfaceTertiary)
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 40,
                        bottomTrailingRadius: 40,
                        topTrailingRadius: 0
                    )
                )
        )
    }
    
    // MARK: - Tab Selector
    
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(LimiMotion.quick) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(selectedTab == tab ? .themeWhite : Color.appSurfaceChip)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedTab == tab ? Color.appSurfaceChip : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appInputFill)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .active:
                    if activeSchedules.isEmpty {
                        emptyState(text: "No active routines in the next hour.")
                    } else {
                        ForEach(activeSchedules) { schedule in
                            ScheduleCard(schedule: schedule)
                                .onTapGesture { selectedSchedule = schedule }
                        }
                    }
                    
                case .upcoming:
                    if upcomingSchedules.isEmpty {
                        emptyState(text: "No more routines scheduled for today.")
                    } else {
                        ForEach(upcomingSchedules) { schedule in
                            ScheduleCard(schedule: schedule)
                                .onTapGesture { selectedSchedule = schedule }
                        }
                    }
                    
                case .completed:
                    if completedSchedules.isEmpty {
                        emptyState(text: "No completed routines yet.")
                    } else {
                        ForEach(completedSchedules) { schedule in
                            ScheduleCard(schedule: schedule, showCompletedBadge: true)
                                .onTapGesture { selectedSchedule = schedule }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    private func emptyState(text: String) -> some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.appSurfaceChip)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Schedule Card

private struct ScheduleCard: View {
    @ObservedObject var schedule: Schedule
    var showCompletedBadge: Bool = false
    
    private var timeString: String {
        schedule.time.formatted(date: .omitted, time: .shortened)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail / Icon
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appInputFill)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(schedule.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.themeWhite)
                )
            
            // Text content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(schedule.type)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appTextPrimary)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .stroke(Color.appBrandAccent, lineWidth: 0.8)
                                .background(
                                    Capsule().fill(Color.appSurfaceTertiary)
                                )
                        )
                    
                    if showCompletedBadge {
                        Text("Completed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appSuccess)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule()
                                    .fill(Color.themeBlack.opacity(0.4))
                            )
                    }
                }
                
                Text(timeString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.themeWhite)
                
                Text(schedule.notes)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.themeWhite.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appInputFill)
        )
    }
}

// MARK: - Sample Data

private enum SampleSchedules {
    static func initial() -> [Schedule] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            // Active (within 1 hour)
            Schedule(
                iconName: "cleaning_service",
                type: "Morning Routine ☀️",
                time: calendar.date(byAdding: .minute, value: 30, to: now) ?? now,
                notes: "Slowly turn on bedroom and bathroom lights, then open blinds."
            ),
            Schedule(
                iconName: "pizza_image",
                type: "Breakfast Lights 🍳",
                time: calendar.date(byAdding: .minute, value: 50, to: now) ?? now,
                notes: "Warm white over kitchen island and soft ambient in dining area."
            ),
            
            // Upcoming (later today)
            Schedule(
                iconName: "cleaning_service",
                type: "Workout Routine 💪",
                time: calendar.date(byAdding: .hour, value: 3, to: now) ?? now,
                notes: "Bright cool white in gym and hallway for an energizing vibe."
            ),
            
            // Completed (earlier today / yesterday)
            Schedule(
                iconName: "spa_service",
                type: "Night Wind-Down 🌙",
                time: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                notes: "Dim warm lights in bedroom and living room, switch off hallway.",
                isCompleted: true
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    SchedulingView()
}
