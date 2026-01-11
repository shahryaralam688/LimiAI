import SwiftUI

struct BLEStarterView: View {
    var body: some View {
        NavigationStack {
            BLEScanView()
                .navigationTitle("BLE Scanner")
        }
    }
}

#Preview {
    BLEStarterView()
}
