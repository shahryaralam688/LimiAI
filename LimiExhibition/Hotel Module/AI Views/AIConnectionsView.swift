import SwiftUI

struct AIConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneEnabled = true
    @State private var uberEnabled = true
    @State private var calendarEnabled = true
    @State private var bookingEnabled = true
    
    var body: some View {
        VStack(spacing: 0) {
            // App Bar
            AIAppBar(title: "AI Connections") {
                dismiss()
            }
            .padding(.top, 24)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(hex: "#393C43"))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 40,
                                bottomLeadingRadius: 40,
                                bottomTrailingRadius: 40,
                                topTrailingRadius: 40
                            )
                        )
                )
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: AIDesignTokens.spacingLG) {
                    // Info Banner
                    InfoBanner(
                        title: "Connected: 4 of 7 Services",
                        description: "Limi can access your Uber, Google Calendar, and Booking.com accounts.",
                        ctaText: "Connect More"
                    ) {
                        // Handle connect more action
                        print("Connect More tapped")
                    }
                    
                    // Connections List Header
                    HStack {
                        Text("Connections List")
                            .font(AIDesignTokens.h2Font)
                            .foregroundColor(AIDesignTokens.textPrimary)
                        Spacer()
                    }
                    
                    // Connection Rows
                    VStack(spacing: AIDesignTokens.spacingMD) {
                        ConnectionRow(
                            iconName: "phone.fill",
                            title: "Phone & Contacts",
                            subtitle: "Make calls, send texts, or contact your concierge",
                            isEnabled: $phoneEnabled
                        )
                        
                        ConnectionRow(
                            iconName: "car.fill",
                            title: "Uber",
                            subtitle: "Order rides from or to your hotel automatically",
                            isEnabled: $uberEnabled
                        )
                        
                        ConnectionRow(
                            iconName: "calendar",
                            title: "Google Calendar",
                            subtitle: "Check or schedule events",
                            isEnabled: $calendarEnabled
                        )
                        
                        ConnectionRow(
                            iconName: "bed.double.fill",
                            title: "Booking.com",
                            subtitle: "Manage or modify hotel reservations",
                            isEnabled: $bookingEnabled
                        )
                    }
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .padding(.top, AIDesignTokens.spacingLG)
            }
        }
        .background(AIDesignTokens.bgBase)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview {
    AIConnectionsView()
}
