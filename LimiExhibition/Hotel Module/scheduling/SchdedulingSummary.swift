//
//  SchedulingSummary.swift
//  Limi
//
//  Created by LIMI on 03/11/2025.
//

import SwiftUI

struct SchedulingSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var schedule: Schedule   // comes from SchedulingView
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    routineNameCard
                    timeAndNotesCard
                    completionCard
                    
                    Spacer(minLength: 24)
                    
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 34)
            }
        }
        .background(Color.themeBlack.ignoresSafeArea())
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                LimiBackButton { dismiss() }
                
                Spacer()
                
                Text("Schedule Summary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.alabaster)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.appSurfaceTertiary)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
    }
    
    // MARK: - Cards
    
    /// Routine name / type
    private var routineNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            chipLabel(text: "Routine Name")
            
            TextField("e.g. Morning Routine", text: $schedule.type)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.themeWhite)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    /// Time + description notes (IoT-style simple form)
    private var timeAndNotesCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            chipLabel(text: "Schedule Time")
            
            DatePicker(
                "Time",
                selection: $schedule.time,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.emerald)
            .colorScheme(.dark)
            
            chipLabel(text: "Description")
            
            TextField(
                "What should Limi do at this time?",
                text: $schedule.notes,
                axis: .vertical
            )
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.themeWhite)
            .lineLimit(3)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    /// Mark as completed / toggle
    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            chipLabel(text: "Status")
            
            Toggle(isOn: $schedule.isCompleted) {
                Text(schedule.isCompleted ? "Marked as completed" : "This routine will run as scheduled")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.themeWhite)
            }
            .tint(Color.emerald)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        LimiPrimaryButton(title: "Save Changes", height: 56) {
            print("✅ Schedule updated: \(schedule.type) at \(schedule.time)")
            dismiss()
        }
    }
    
    // MARK: - Helpers
    
    private func chipLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.alabaster)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .stroke(Color.appBrandAccent, lineWidth: 0.8)
                    .background(
                        Capsule().fill(Color.appSurfaceTertiary)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let sample = Schedule(
        iconName: "cleaning_service",
        type: "Morning Routine ☀️",
        time: calendar.date(byAdding: .minute, value: 45, to: now) ?? now,
        notes: "Turn on bedroom lights to 20%, then warm ambient in living room."
    )
    
    return SchedulingSummaryView(schedule: sample)
}
