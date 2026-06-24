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
            Color.themeBlack.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.themeWhite)

                VStack(spacing: 6) {
                    Text(deviceName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.themeWhite)
                    Text(deviceId)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.themeWhite.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.themeWhite.opacity(0.12))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(10)
                    }

                    Button(action: onConnect) {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .foregroundColor(.themeWhite)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.themeBlack.opacity(0.35))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.themeWhite.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
