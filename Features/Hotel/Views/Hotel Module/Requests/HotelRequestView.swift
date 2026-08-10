//
// HotelRequestView.swift
// Limi
//
// Created by Faizan Ali on 03/10/2025.
//

import SwiftUI

// MARK: - Data Models
private struct HotelRequest: Identifiable, Equatable {
    let id = UUID()
    let imageName: String
    let category: String
    let title: String
    let time: String
    let progress: Double? // For active requests
    let isCompleted: Bool
    
    init(imageName: String, category: String, title: String, time: String, progress: Double? = nil, isCompleted: Bool = false) {
        self.imageName = imageName
        self.category = category
        self.title = title
        self.time = time
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

struct HotelRequestView: View {
    enum Tab: String, CaseIterable {
        case active = "Active"
        case history = "History"
        case cancelled = "Cancelled"
    }

    @State private var selectedTab: Tab = .active
    @State private var selectedItem: HotelRequest? = nil

    // MARK: - Sample Data
    private let activeRequests: [HotelRequest] = [
        HotelRequest(imageName: "cleaning_service", category: "Room Service", title: "Cleaning Service", time: "", progress: 0.6),
        HotelRequest(imageName: "pizza_image", category: "Ordered Food", title: "Ordered Pizza", time: "", progress: 0.8)
    ]

    private let cancelledRequests: [HotelRequest] = [
        HotelRequest(imageName: "spa_service", category: "Spa Service", title: "Massage Therapy", time: "Cancelled", isCompleted: false),
        HotelRequest(imageName: "room_service", category: "Room Service", title: "Extra Towels", time: "Cancelled", isCompleted: false)
    ]

    // History data with sections
    private let historySections: [(date: String, items: [HotelRequest])] = [
        ("Today", [
            HotelRequest(imageName: "cleaning_service", category: "Room Service", title: "Cleaning Service", time: "03:23 pm", isCompleted: true),
            HotelRequest(imageName: "pizza_image", category: "Ordered Food", title: "Ordered Pizza", time: "03:00 pm", isCompleted: true)
        ]),
        ("Yesterday", [
            HotelRequest(imageName: "cleaning_service", category: "Room Service", title: "Cleaning Service", time: "03:23 pm", isCompleted: true)
        ])
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerView
            

            
            // Content
            contentView
        }
        .background(Color.appCanvasPrimary)
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selectedItem) { item in
            RequestSummaryView(
                item: RequestMainItem(
                    iconName: item.imageName,
                    title: item.title,
                    subtitle: item.category
                ),
                requestTime: item.time.isEmpty ? "23 Sept 2025, 08:45 PM" : item.time,
                deliveredBy: "Andrew Marshal",
                summary: getSummaryText(for: item)
            )
        }
    }
    
    // MARK: - Helper Functions
    private func getSummaryText(for request: HotelRequest) -> String {
        switch request.category {
        case "Room Service":
            if request.title == "Cleaning Service" {
                return "Your room cleaning service has been completed. The housekeeping team has thoroughly cleaned your room, changed the linens, and restocked amenities."
            } else {
                return "Your room service request for \(request.title) has been completed successfully."
            }
        case "Ordered Food":
            return "Your food order of 1x Margherita Pizza and 2x Cola was successfully delivered to Room 1205 on 23 Sept 2025 at 09:10 PM."
        case "Spa Service":
            return "Your spa service appointment for \(request.title) has been scheduled and completed as requested."
        default:
            return "Your request for \(request.title) has been processed and completed successfully."
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("My Requests")
                    .font(LimiTypography.largeTitle)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Tab Selector
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
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(LimiTypography.headline)
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
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .active:
                    activeRequestsView
                case .history:
                    historyRequestsView
                case .cancelled:
                    cancelledRequestsView
                }
            }
            .padding(.horizontal, 20)
            .limiFloatingOrbClearance()
        }
    }
    
    // MARK: - Active Requests View
    private var activeRequestsView: some View {
        ForEach(activeRequests) { request in
            ActiveRequestCard(request: request)
                .onTapGesture {
                    selectedItem = request
                }
        }
    }
    
    // MARK: - History Requests View
    private var historyRequestsView: some View {
        ForEach(historySections, id: \.date) { section in
            VStack(alignment: .leading, spacing: 24) {
                // Date Header
                HStack {
                    Text(section.date)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appBrandPrimary)
                        )
                    Spacer()
                }
                
                // Requests for this date
                ForEach(section.items) { request in
                    HistoryRequestCard(request: request)
                        .onTapGesture {
                            selectedItem = request
                        }
                }
            }
        }
    }
    
    // MARK: - Cancelled Requests View
    private var cancelledRequestsView: some View {
        ForEach(cancelledRequests) { request in
            CancelledRequestCard(request: request)
                .onTapGesture {
                    selectedItem = request
                }
        }
    }
}

// MARK: - Active Request Card
private struct ActiveRequestCard: View {
    let request: HotelRequest
    
    var body: some View {
        HStack(spacing: 16) {
            // Image thumbnail
            RoundedRectangle(cornerRadius: 16)
//                .fill(Color.appBorderPrimary.opacity(0.45))
                .fill(Color.appInputFill)

                .frame(width: 80, height: 80)
                .overlay(
                    Image(getSystemImageName())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.appTextPrimary)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(request.category)
                    .font(LimiTypography.footnote)
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
                Text(request.title)
                    .font(LimiTypography.button)
                    .foregroundColor(.appTextPrimary)
                
                // Progress Bar
                if let progress = request.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .appTextPrimary))
                        .scaleEffect(y: 2)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appInputFill)
        )
    }
    
    private func getSystemImageName() -> String {
        switch request.category {
        case "Room Service":
            return "cleaning_service"
        case "Ordered Food":
            return "ordered_pizza"
        default:
            return "star.fill"
        }
    }
}

// MARK: - History Request Card
private struct HistoryRequestCard: View {
    let request: HotelRequest
    
    var body: some View {
        HStack(spacing: 16) {
            // Image thumbnail
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appInputFill)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(getSystemImageName())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.appTextPrimary)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(request.category)
                    .font(LimiTypography.footnote)
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
                Text(request.title)
                    .font(LimiTypography.button)
                    .foregroundColor(.appTextPrimary)
                
                // Time with clock icon
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(LimiTypography.caption)
                        .foregroundColor(.appTextMuted)
                    
                    Text(request.time)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appTextMuted)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appInputFill)
        )
    }
    
    private func getSystemImageName() -> String {
        switch request.category {
        case "Room Service":
            return "cleaning_service"
        case "Ordered Food":
            return "ordered_pizza"
        default:
            return "star.fill"
        }
    }
}

// MARK: - Cancelled Request Card
private struct CancelledRequestCard: View {
    let request: HotelRequest
    
    var body: some View {
        HStack(spacing: 16) {
            // Image thumbnail with red overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appBorderPrimary.opacity(0.45))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "xmark.circle.fill")
                        .font(LimiTypography.title2)
                        .foregroundColor(.appDanger)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(request.category)
                    .font(LimiTypography.footnote)
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
                
                Text(request.title)
                    .font(LimiTypography.button)
                    .foregroundColor(.appTextPrimary)
                
                Text("Cancelled")
                    .font(LimiTypography.callout)
                    .foregroundColor(.appDanger)
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


// MARK: - Extensions
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue:  Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}

#Preview {
    HotelRequestView()
}
