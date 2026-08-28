import SwiftUI

struct DemoConnectedWifiView: View {
    let deviceName: String?
    var deviceId: String?
    var onContinue: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
            LimiPairingOverlay(
                deviceName: deviceName ?? "LIMI Device",
                deviceId: deviceId,
                mode: .connected("Credentials confirmed"),
                modelName: LimiPairingAssets.bundledName(forDeviceId: deviceId),
                placement: .centered,
                onPrimary: { onContinue?() },
                onDismiss: { onContinue?() }
            )
        }
    }
}

#Preview {
    DemoConnectedWifiView(deviceName: "1 CH-HUB")
}
