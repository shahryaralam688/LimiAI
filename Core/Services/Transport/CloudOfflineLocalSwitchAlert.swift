//
//  CloudOfflineLocalSwitchAlert.swift
//  Limi
//
//  Shared Yes/No alert for cloud-offline → local WS/BLE switch.
//  Attach once at each app root so both LIMI AI and LIMI AI Device share UX.
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
    /// Shows the cloud-offline → local network / BLE switch confirmation.
    func cloudOfflineLocalSwitchAlert() -> some View {
        modifier(CloudOfflineLocalSwitchAlertModifier())
    }
}
