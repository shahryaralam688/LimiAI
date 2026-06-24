import SwiftUI

private struct LimiBackendBaseURLKey: EnvironmentKey {
    static let defaultValue = LimiAPIConfiguration.baseURLValue
}

extension EnvironmentValues {
    var limiBackendBaseURL: URL {
        get { self[LimiBackendBaseURLKey.self] }
        set { self[LimiBackendBaseURLKey.self] = newValue }
    }
}
