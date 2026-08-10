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

    private init() {}

    func showDeviceFound(title: String, deviceName: String, deviceId: String, onConnect: @escaping () -> Void) {
        guard !isShowing else { return }
        isShowing = true

        let root = HubFoundPopupView(
            title: title,
            deviceName: deviceName,
            deviceId: deviceId,
            onConnect: { [weak self] in
                onConnect()
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
            let window = UIWindow(windowScene: scene)
            window.rootViewController = hosting
            window.windowLevel = .alert + 1
            window.backgroundColor = .clear
            window.isHidden = false
            window.makeKeyAndVisible()
            self.window = window
        } else {
            // Fallback: present on a new window even if no active scene found
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hosting
            window.windowLevel = .alert + 1
            window.backgroundColor = .clear
            window.isHidden = false
            window.makeKeyAndVisible()
            self.window = window
        }

        // Auto-dismiss after a short delay if user does nothing
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard isShowing else { return }
        isShowing = false
        UIView.animate(withDuration: 0.25, animations: {
            self.window?.alpha = 0
        }, completion: { _ in
            self.window?.isHidden = true
            self.window = nil
        })
    }
}

// MARK: - SwiftUI popup content

struct HubFoundPopupView: View {
    let title: String
    let deviceName: String
    let deviceId: String
    let onConnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.appOverlayScrimLight
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text(title)
                    .font(LimiTypography.title3)
                    .foregroundColor(.appTextPrimary)

                VStack(spacing: 6) {
                    Text(deviceName)
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                    Text(deviceId)
                        .font(LimiTypography.footnote)
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 12) {
                    LimiSecondaryButton(title: "Dismiss", height: 46, action: onDismiss)
                    LimiPrimaryButton(title: "Connect", height: 46, action: onConnect)
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.appGlassStrokeLight, lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
