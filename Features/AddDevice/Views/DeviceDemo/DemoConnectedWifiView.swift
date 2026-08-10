import SwiftUI

struct DemoConnectedWifiView: View {
    let deviceName: String?
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                AnimatedSearchButton(iconName: "checkmark.circle.fill")
                    .padding(.top, 100)

                Text(deviceName ?? "Device")
                    .font(LimiTypography.title3)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Device added Successfully")
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Your device is online and ready to control.")
                    .font(LimiTypography.subheadline)
                    .foregroundColor(.appTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }

            Spacer()

            LimiPrimaryButton(title: "Continue") {
                onContinue?()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .limiFloatingOrbClearance()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appCanvasPrimary)
    }
}

#Preview {
    DemoConnectedWifiView(deviceName: "xyz")
}
