import SwiftUI

struct HubHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(LimiTypography.title3)
                .foregroundColor(.appTextPrimary)
            Spacer()
        }
    }
}
