import SwiftUI

struct DevicesButton: View {
    let deviceName: String?
    let searchDeviceUUID: String?
    let onConnect: (String, String) -> Void
    let isConnected: Bool
    let deviceType: BLEDevice.DeviceType
    let ipAddress: String?
    var reachability: BLEDevice.Reachability = .offline

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator + icon
            VStack(spacing: 6) {
                Circle()
                    .fill(reachability == .online ? Color.appBrandPrimary : Color.gray)
                    .frame(width: 12, height: 12)
                VStack(spacing: 4) {
                    Image(systemName: deviceType == .bluetooth ? "lamp.table.fill" : "wifi")
                        .font(.system(size: deviceType == .bluetooth ? 24 : 20, weight: .medium))
                        .foregroundColor(deviceType == .bluetooth ? Color.themeWhite : (reachability == .online ? .themeWhite : .red))
                    Text(deviceType == .bluetooth ? "BLE" : (reachability == .online ? "Online" : "Offline"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(reachability == .online ? .themeWhite : .red)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(deviceName ?? "Unknown Device")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.themeWhite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.themeBlack)
                        .cornerRadius(4)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(searchDeviceUUID ?? "XTP-1245")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.themeWhite)
                    if deviceType == .wifi, let ip = ipAddress {
                        Text("IP: \(ip)")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(Color.orbGlow4.opacity(0.8))
                    }
                }
                Button(action: {
                    if let name = deviceName, let id = searchDeviceUUID { onConnect(name, id) }
                }) {
                    Text(isConnected ?  "Connected" : (reachability == .online ?"Connect" : "Disconnected"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(reachability == .online ? Color.alabaster : Color.charlestonGreen )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isConnected ? (reachability == .online ? Color.clear : Color.gray) : (reachability == .online ? Color.appBrandPrimary : Color.gray))
                        .cornerRadius(8)
                }
                .disabled(reachability == .offline)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSurfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorderQuaternary, lineWidth: 1))
    }
}
