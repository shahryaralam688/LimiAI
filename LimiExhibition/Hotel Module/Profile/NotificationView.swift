
import SwiftUI

struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss
    let onBack: () -> Void = {}

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    @State private var notificationTitles: [String] = []
    @State private var notifStates: [String: Bool] = [:]

    init() {
        let titles = [
            "New Device Discovery",
            "Firmware Updates",
            "Device Offline Alerts",
            "Scene Suggestions",
            "Energy Usage Reports",
            "Promotions"
        ]
        _notificationTitles = State(initialValue: titles)
        var dict: [String: Bool] = [:]
        titles.forEach { dict[$0] = true }
        _notifStates = State(initialValue: dict)
    }

    var body: some View {
        VStack{
            VStack{
                HStack {
                    Button(action: {
                        onBack()
                        dismiss()
                    }) {
                        Image("Solid arrow right sm")
                            .foregroundColor(.alabaster)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color.appInputFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    }
                    
                    Text("Notification Settings")
                        .font(AIDesignTokens.h1Font)
                        .foregroundColor(AIDesignTokens.textPrimary)
                    
                    Spacer()
                }
                .padding(.top)
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .frame(height: 124)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.appSurfaceTertiary)
                        .clipShape(
                        .rect(
                            topLeadingRadius: 40,
                            bottomLeadingRadius: 40,
                            bottomTrailingRadius: 40,
                            topTrailingRadius: 40
                        )
                    )
                )

            }
            Spacer()
            ScrollView{
                VStack(spacing: 12) {
                    ForEach(notificationTitles, id: \.self) { title in
                        let isOn = Binding<Bool>(
                            get: { notifStates[title] ?? false },
                            set: { notifStates[title] = $0 }
                        )
                        NotificationToggleCard(title: title, isOn: isOn)
                    }
                }
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .padding(.bottom, 24)
                .padding(.top, 12)
            }

        }
        .background(AIDesignTokens.bgBase)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
#Preview {
    NotificationView()
}

struct NotificationToggleCard: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .regular))
                
                .foregroundColor(.alabaster)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.appSurfaceTertiary)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 16
                            )
                        ).frame(width: 48 , height: 48)
                )
                .padding()
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.alabaster)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.emerald)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.themeWhite.opacity(0.06), lineWidth: 1)
        )
    }
}
