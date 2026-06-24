import SwiftUI

struct BLEStarterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BLEScanView()
                .limiModalNavigationBar(title: "BLE Scanner", onClose: { dismiss() })
        }
    }
}

#Preview {
    BLEStarterView()
}
