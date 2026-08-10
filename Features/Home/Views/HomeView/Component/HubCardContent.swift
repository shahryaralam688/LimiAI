//
//  HubCardContent.swift
//  Limi
//

import SwiftUI

struct HubCardContent: View {
    let hub: Hub
    var pulseAnimation: Bool
    var isExpanded: Bool
    @ObservedObject var bluetoothManager: HomeBluetoothAdapter
    @State private var isOn = false

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "house.fill")
                    .font(LimiTypography.title2)
                    .foregroundColor(.brandHighlight)
                Spacer()
            }
            .padding(10)

            HStack {
                Text(bluetoothManager.connectedDeviceName ?? hub.name)
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 10)

            Spacer()

            HStack {
                Text("Connect")
                    .font(LimiTypography.subheadline)
                    .foregroundColor(.brandAction)
                Spacer()
                Toggle(isOn: $isOn) {}
                    .frame(width: 60, height: 32)
                    .toggleStyle(SwitchToggleStyle(tint: .brandAction))
            }
            .padding()
        }
        .frame(height: LimiCard.moduleMinHeight + 50)
        .padding(14)
        .limiHomeCard(cornerRadius: LimiCard.radius)
    }
}
