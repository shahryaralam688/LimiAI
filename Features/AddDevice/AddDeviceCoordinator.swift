import SwiftUI

/// Single entry for add-device flows (Phase G).
enum AddDeviceRoute: String, Identifiable, Equatable {
    case deviceScan
    case legacyInstallerFlow

    var id: String { rawValue }
}

enum AddDeviceCoordinator {
    @ViewBuilder
    static func destination(for route: AddDeviceRoute, onBack: (() -> Void)? = nil) -> some View {
        switch route {
        case .deviceScan:
            DemoScanDevicesView(onBack: onBack)
        case .legacyInstallerFlow:
            AddDeviceView()
        }
    }
}
