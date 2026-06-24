import SwiftUI

struct HubHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)
            Spacer()
        }
    }
}
