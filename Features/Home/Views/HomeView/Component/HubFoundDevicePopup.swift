//
//  HubFoundDevicePopup.swift
//  Limi
//

import SwiftUI
import UIKit

// MARK: - Global popup presenter

final class GlobalDevicePopup {
    static let shared = GlobalDevicePopup()

    private var window: UIWindow?
    private var isShowing = false
    private var autoDismissWorkItem: DispatchWorkItem?

    private init() {}

    func showDeviceFound(
        deviceName: String,
        deviceId: String,
        modelName: String? = nil,
        onConnect: @escaping () -> Void
    ) {
        let resolvedModel = modelName ?? LimiPairingAssets.bundledName(forDeviceId: deviceId)
        present(
            deviceName: deviceName,
            deviceId: deviceId,
            modelName: resolvedModel,
            mode: .discover,
            autoDismissAfter: 30,
            onPrimary: onConnect
        )
    }

    func showConnecting(deviceName: String, deviceId: String, modelName: String = LimiPairingAssets.defaultModelName) {
        present(
            deviceName: deviceName,
            deviceId: deviceId,
            modelName: modelName,
            mode: .connecting,
            autoDismissAfter: nil,
            onPrimary: nil
        )
    }

    func showConnected(deviceName: String, deviceId: String, detail: String? = nil, onDone: (() -> Void)? = nil) {
        present(
            deviceName: deviceName,
            deviceId: deviceId,
            modelName: LimiPairingAssets.bundledName(forDeviceId: deviceId),
            mode: .connected(detail),
            autoDismissAfter: 8,
            onPrimary: onDone
        )
    }

    func dismiss() {
        guard isShowing else { return }
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        isShowing = false
        UIView.animate(withDuration: 0.25, animations: {
            self.window?.alpha = 0
        }, completion: { _ in
            self.window?.isHidden = true
            self.window = nil
        })
    }

    private func present(
        deviceName: String,
        deviceId: String,
        modelName: String,
        mode: LimiPairingCardMode,
        autoDismissAfter: TimeInterval?,
        onPrimary: (() -> Void)?
    ) {
        autoDismissWorkItem?.cancel()

        let root = HubFoundPopupView(
            deviceName: deviceName,
            deviceId: deviceId,
            modelName: modelName,
            mode: mode,
            onPrimary: { [weak self] in
                onPrimary?()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        {
            let popupWindow = UIWindow(windowScene: scene)
            popupWindow.rootViewController = hosting
            popupWindow.windowLevel = .alert + 1
            popupWindow.backgroundColor = .clear
            popupWindow.isHidden = false
            popupWindow.makeKeyAndVisible()
            self.window = popupWindow
        } else {
            let popupWindow = UIWindow(frame: UIScreen.main.bounds)
            popupWindow.rootViewController = hosting
            popupWindow.windowLevel = .alert + 1
            popupWindow.backgroundColor = .clear
            popupWindow.isHidden = false
            popupWindow.makeKeyAndVisible()
            self.window = popupWindow
        }

        isShowing = true
        window?.alpha = 0
        UIView.animate(withDuration: 0.28) {
            self.window?.alpha = 1
        }

        if let autoDismissAfter {
            let work = DispatchWorkItem { [weak self] in
                self?.dismiss()
            }
            autoDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter, execute: work)
        }
    }
}

// MARK: - SwiftUI popup content

struct HubFoundPopupView: View {
    let deviceName: String
    let deviceId: String
    let modelName: String
    let mode: LimiPairingCardMode
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        LimiPairingOverlay(
            deviceName: deviceName,
            deviceId: deviceId,
            mode: mode,
            modelName: modelName,
            placement: .bottomSheet,
            onPrimary: onPrimary,
            onDismiss: onDismiss
        )
    }
}
