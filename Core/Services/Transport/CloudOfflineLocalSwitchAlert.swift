//
//  CloudOfflineLocalSwitchAlert.swift
//  Limi
//
//  Optional blocking Yes/No alert for cloud-offline → local WS/BLE switch.
//  LIMI AI Device uses the home notification bell badge instead
//  (`DeviceLocalSwitchInboxSheet`) — do not attach this on DeviceRootView.
//

import SwiftUI

private struct CloudOfflineLocalSwitchAlertModifier: ViewModifier {
    @ObservedObject private var coordinator = CloudOfflineLocalSwitchCoordinator.shared

    func body(content: Content) -> some View {
        content
            .alert(
                "Cloud Disconnected",
                isPresented: Binding(
                    get: { coordinator.activeOffer != nil },
                    set: { presented in
                        if !presented, coordinator.activeOffer != nil {
                            coordinator.decline()
                        }
                    }
                ),
                presenting: coordinator.activeOffer
            ) { _ in
                Button("Yes") {
                    coordinator.accept()
                }
                Button("No", role: .cancel) {
                    coordinator.decline()
                }
            } message: { offer in
                Text(offer.alertMessage)
            }
    }
}

public extension View {
    /// Blocking alert UX. Prefer notification-badge inbox on Device app Home.
    func cloudOfflineLocalSwitchAlert() -> some View {
        modifier(CloudOfflineLocalSwitchAlertModifier())
    }
}
