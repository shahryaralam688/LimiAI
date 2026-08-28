//
//  HomeUI2HomeView.swift
//  LIMI AI Device — Home UI 2 Dark sage
//
//  Layout matched to the shared dark smart-home reference, wired to
//  real LIMI devices / rooms / moods (not mock furniture demos).
//

import SwiftUI

struct DeviceHomeUIVariantTwoView: View {
    let userName: String
    let greeting: String
    var avatarImage: UIImage?
    let rooms: [String]
    @Binding var selectedRoom: String?
    let selectedMood: DeviceLightMood
    let items: [DeviceHomeUIPreviewItem]
    var onlineDeviceCount: Int
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onSelectMood: (DeviceLightMood) -> Void
    var onAdd: () -> Void
    var onConnectedDevices: (() -> Void)? = nil

    private var weatherIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 18 { return "sun.max.fill" }
        return "moon.stars.fill"
    }

    private var weatherCondition: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 12 { return "Morning" }
        if hour >= 12 && hour < 18 { return "Afternoon" }
        return "Evening"
    }

    private var homeTitle: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "User" || trimmed == "Guest" {
            return "LIMI Home"
        }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return "\(first)'s Home"
    }

    var body: some View {
        ZStack {
            HomeUI2Color.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI2Header(
                        userName: userName,
                        greeting: "Welcome Back,",
                        avatarImage: avatarImage,
                        onNotifications: nil,
                        onConnectedDevices: onConnectedDevices
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    HStack(alignment: .top, spacing: 12) {
                        HomeUI2HomeSummaryCard(
                            homeTitle: homeTitle,
                            userCountLabel: onlineLabel,
                            avatarImage: avatarImage,
                            onMenu: nil
                        )
                        .frame(maxWidth: .infinity)

                        HomeUI2WeatherCard(
                            temperatureLabel: timeLabel,
                            condition: weatherCondition,
                            systemImage: weatherIcon
                        )
                        .frame(width: 118)
                    }
                    .padding(.horizontal, 20)

                    HomeUI2ScenesCard(
                        selectedMood: selectedMood,
                        onSelect: onSelectMood,
                        onAdd: onAdd
                    )
                    .padding(.horizontal, 20)

                    HomeUI2RoomChips(rooms: rooms, selectedRoom: $selectedRoom)

                    if items.isEmpty {
                        emptyState
                            .padding(.horizontal, 20)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(items) { item in
                                HomeUI2DeviceTile(
                                    item: item,
                                    onOpen: { onOpen(item.id) },
                                    onToggle: { onToggle(item.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 28)
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var onlineLabel: String {
        let n = onlineDeviceCount
        if n == 0 { return "No devices online" }
        if n == 1 { return "1 Online" }
        return "\(n) Online"
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(HomeUI2Color.accent)
            Text(selectedRoom == nil ? "No Devices" : "No Matches")
                .font(HomeUI2Type.title(18))
                .foregroundStyle(HomeUI2Color.textPrimary)
            Text(
                selectedRoom == nil
                    ? "Add a LIMI device to see it here."
                    : "No devices in this room. Try All Device."
            )
            .font(HomeUI2Type.regular(13))
            .foregroundStyle(HomeUI2Color.textSecondary)
            .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Text("Add Device")
                    .font(HomeUI2Type.body(14))
                    .foregroundStyle(HomeUI2Color.textOnAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(HomeUI2Color.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .homeUI2Card(fill: HomeUI2Color.surface)
    }
}
