import SwiftUI

struct AIConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneEnabled = true
    @State private var uberEnabled = true
    @State private var calendarEnabled = true
    @State private var bookingEnabled = true
    @State private var appeared = false

    var body: some View {
        ZStack {
            DeepSpaceBackground(showParticles: false)

            VStack(spacing: 0) {
                AIAppBar(title: "Connections") {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        InfoBanner(
                            title: "Connected: 4 of 7 Services",
                            description: "Limi can access your Uber, calendar, and Booking.com accounts.",
                            ctaText: "Connect More"
                        ) {
                            // Handle connect more
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                        LimiSectionHeader(title: "Services")

                        VStack(spacing: 10) {
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
                                title: "Calendar",
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

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

#Preview {
    AIConnectionsView()
}
