import SwiftUI

struct DevicesButton: View {
    let deviceName: String?
    let searchDeviceUUID: String?
    let onConnect: (String, String) -> Void
    let isConnected: Bool
    let deviceType: BLEDevice.DeviceType
    let ipAddress: String?
    var reachability: BLEDevice.Reachability = .offline

    private var isReachable: Bool { reachability == .online }

    var body: some View {
        HStack(spacing: LimiSpacing.itemGap) {
            VStack(spacing: 6) {
                Circle()
                    .fill(isReachable ? Color.brandAction : Color.appBorderPrimary)
                    .frame(width: 12, height: 12)
                VStack(spacing: 4) {
                    Image(systemName: deviceType == .bluetooth ? "lamp.table.fill" : "wifi")
                        .font(.system(size: deviceType == .bluetooth ? LimiIconSize.deviceRow : LimiIconSize.inline, weight: .medium))
                        .foregroundColor(isReachable ? Color.appTextPrimary : Color.appDanger)
                    Text(deviceType == .bluetooth ? "BLE" : (isReachable ? "Online" : "Offline"))
                        .font(LimiTypography.caption2)
                        .foregroundColor(isReachable ? Color.appTextSecondary : Color.appDanger)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(deviceName ?? "Unknown Device")
                        .font(LimiTypography.caption)
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appSurfaceDark)
                        .cornerRadius(LimiRadius.small / 3)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(searchDeviceUUID ?? "XTP-1245")
                        .font(LimiTypography.title3)
                        .foregroundColor(.appTextPrimary)
                    if deviceType == .wifi, let ip = ipAddress {
                        Text("IP: \(ip)")
                            .font(LimiTypography.caption)
                            .foregroundColor(Color.brandHighlight.opacity(0.8))
                    }
                }
                Button(action: {
                    if let name = deviceName, let id = searchDeviceUUID { onConnect(name, id) }
                }) {
                    Text(isConnected ? "Connected" : (isReachable ? "Connect" : "Disconnected"))
                        .font(LimiTypography.headline)
                        .foregroundColor(isReachable ? Color.appTextInverse : Color.appTextDisabled)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isConnected
                                ? (isReachable ? Color.clear : Color.appBorderPrimary)
                                : (isReachable ? Color.brandAction : Color.appBorderPrimary)
                        )
                        .cornerRadius(LimiRadius.small)
                }
                .disabled(!isReachable)
            }
            Spacer()
        }
        .padding(LimiSpacing.innerPadding)
        .background(RoundedRectangle(cornerRadius: LimiRadius.small).fill(Color.appSurfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: LimiRadius.small).stroke(Color.appBorderQuaternary, lineWidth: 1))
    }
}
