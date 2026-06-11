import SwiftUI

struct DemoConnectedWifiView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    let deviceName: String?
    @State private var showDemoScanDevicesView = false

    var body: some View {
        VStack {
            VStack(spacing: 16) {
                AnimatedSearchButton(iconName: "checkmark.circle.fill")
                    .padding(.top, 100)

                Text(deviceName ?? "Device")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .multilineTextAlignment(.center)

                Text("Device added Successfully")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: {
                showDemoScanDevicesView = true
            }) {
                HStack {
                    Spacer()
                    Text("Add Your First Device")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextInverse)
                    Image("Monotone arrow right")
                        .foregroundColor(.appTextInverse)
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color.themeWhite)
                .foregroundColor(.themeBlack)
                .clipShape(Capsule(style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 27)
        }
        .background(Color.appCanvasPrimary)
        .fullScreenCover(isPresented: $showDemoScanDevicesView) {
            ConnectedDevicesView()
        }
    }
}

#Preview {
    DemoConnectedWifiView(deviceName: "xyz")
}
