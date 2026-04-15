import SwiftUI

struct RequestSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: RequestMainItem       // 👈 pichle view se aayega
    let requestTime: String
    let deliveredBy: String
    let summary: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header with rounded corners
            VStack(spacing: 0) {
                HStack {
                    LimiBackButton { dismiss() }
                    
                    Spacer()
                    
                    Text("Request Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    
                    Spacer()
                    
                    // Invisible placeholder for centering
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
            
            // Content area
            VStack(spacing: 16) {
                // Request Name Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Name")
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
                    
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.themeWhite)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.appSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Request Time Card
                VStack(alignment: .leading, spacing: 24) {
                    Text("Request Time")
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
                    
                    Text(requestTime)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text("Delivered by")
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
                    
                    Text(deliveredBy)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.themeWhite)
                    Text("Summary")
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
                    
                    Text(summary)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.themeWhite)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.appSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                
                Spacer()
                
                // Feedback Button
                LimiPrimaryButton(title: "Feedback") {
                    print("Feedback tapped")
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
    }
}

#Preview {
    RequestSummaryView(
        item: .init(iconName: "takeoutbag.and.cup.and.straw.fill", title: "Ordered Food", subtitle: "Food Delivered"),
        requestTime: "23 Sept 2025, 08:45 PM",
        deliveredBy: "Andrew Marshal",
        summary: "Your food order of 1x Margherita Pizza and 2x Cola was successfully delivered to Room 1205 on 23 Sept 2025 at 09:10 PM."
    )
}


struct RequestMainItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let subtitle: String
}
