import Foundation

/// Modal / full-screen destinations from `HomeView` (replaces scattered boolean flags).
enum HomeRoute: String, Identifiable, Equatable {
    case voice
    case moduler
    case wifiProvisioning
    case connectedDevices
    case configurator
    case arView
    case roomScan
    case voicePendantScan
    case webView

    var id: String { rawValue }

    /// Sheet vs full-screen cover presentation.
    var usesSheet: Bool {
        switch self {
        case .configurator, .webView:
            return true
        default:
            return false
        }
    }
}
