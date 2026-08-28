//
//  HomeUI1BottomBar.swift
//  LIMI AI Device — Home UI 1
//
//  Floating capsule overlay — raised dock + inset/raised tabs.
//  No full-width background strip; sits over content.
//

import SwiftUI

struct HomeUI1BottomBar: View {
    @Binding var selectedTab: DeviceRootTab

    var body: some View {
        HStack(spacing: 8) {
            tabButton(.home, systemImage: "house.fill", title: "Home")
            tabButton(.schedule, systemImage: "calendar", title: "Schedule")
            tabButton(.rooms, systemImage: "square.grid.2x2.fill", title: "Rooms")
            tabButton(.profile, systemImage: "person.fill", title: "Profile")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(HomeUI1Color.surface)
                .shadow(color: HomeUI1Color.shadowDark.opacity(0.65), radius: 10, x: 6, y: 8)
                .shadow(color: HomeUI1Color.shadowLight.opacity(0.28), radius: 10, x: -6, y: -8)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(HomeUI1Color.border.opacity(0.45), lineWidth: 0.8)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: DeviceRootTab, systemImage: String, title: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            DeviceAppGuidance.lightImpact()
            withAnimation(HomeUI1Motion.soft) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(HomeUI1Type.caption(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? HomeUI1Color.textPrimary : HomeUI1Color.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .homeUI1CapsuleElevation(
                isSelected ? .recessed : .one,
                fill: HomeUI1Color.surface
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct HomeUI1MenuButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .frame(width: 40, height: 40)
                .homeUI1CircleElevation(.one, fill: HomeUI1Color.surface)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open theme menu")
    }
}
