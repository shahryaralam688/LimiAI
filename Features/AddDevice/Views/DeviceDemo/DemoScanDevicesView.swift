import SwiftUI

/// Legacy entry point — delegates to the unified single-session add-device flow.
struct DemoScanDevicesView: View {
    var onBack: (() -> Void)? = nil

    var body: some View {
        AddDeviceFlowView(onFinished: { outcome in
            if outcome == .cancelled {
                onBack?()
            }
        })
    }
}

#Preview { DemoScanDevicesView() }
