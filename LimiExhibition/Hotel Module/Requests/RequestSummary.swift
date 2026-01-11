import SwiftUI

struct RequestSummaryView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let item: RequestMainItem       // 👈 pichle view se aayega
    let requestTime: String
    let deliveredBy: String
    let summary: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header with rounded corners
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("Solid arrow right sm")
                            .foregroundColor(.alabaster)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Spacer()
                    
                    Text("Request Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.alabaster)
                    
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
            .background(Color(hex: "#393C43"))
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
                        .foregroundColor(.alabaster)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .stroke(Color(hex: "#00FF8C"), lineWidth: 0.8)
                                .background(
                                    Capsule().fill(Color(hex: "#393C43"))
                                )
                        )
                    
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(hex: "#24262B"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Request Time Card
                VStack(alignment: .leading, spacing: 24) {
                    Text("Request Time")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.alabaster)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .stroke(Color(hex: "#00FF8C"), lineWidth: 0.8)
                                .background(
                                    Capsule().fill(Color(hex: "#393C43"))
                                )
                        )
                    
                    Text(requestTime)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Delivered by")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.alabaster)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .stroke(Color(hex: "#00FF8C"), lineWidth: 0.8)
                                .background(
                                    Capsule().fill(Color(hex: "#393C43"))
                                )
                        )
                    
                    Text(deliveredBy)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Summary")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.alabaster)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .stroke(Color(hex: "#00FF8C"), lineWidth: 0.8)
                                .background(
                                    Capsule().fill(Color(hex: "#393C43"))
                                )
                        )
                    
                    Text(summary)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(hex: "#24262B"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                
                Spacer()
                
                // Feedback Button
                Button(action: {
                    print("Feedback tapped")
                }) {
                    Text("Feedback")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.emerald)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(Color.black.ignoresSafeArea())
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
