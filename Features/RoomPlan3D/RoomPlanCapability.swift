//
//  RoomPlanCapability.swift
//  Limi
//
//  Apple’s supported gate for RoomPlan camera capture.
//  RoomCaptureSession.isSupported is true only on LiDAR Pro devices
//  (iPhone Pro / iPad Pro with a LiDAR scanner).
//

import Foundation
import RoomPlan
import SwiftUI

enum RoomPlanCapability {
    /// Official RoomPlan API — prefer this over generic ARKit LiDAR heuristics.
    static var isCaptureSupported: Bool {
        RoomCaptureSession.isSupported
    }

    static let unsupportedTitle = "Room Scan Needs a Pro Device"

    static let unsupportedMessage = """
    New room scans use LiDAR to map walls, furniture, and dimensions.

    Compatible devices include iPhone Pro and iPad Pro models with a LiDAR scanner (for example iPhone 12 Pro and newer Pro models).

    You can still open any scans already saved on this phone.
    """

    static let prepTips: [String] = [
        "Walk slowly and keep the phone upright",
        "Point the camera at walls, floors, and furniture",
        "Good lighting helps the Pro LiDAR build a clean map"
    ]
}

/// Shared unsupported UI used before the RoomPlan camera starts.
struct RoomPlanUnsupportedView: View {
    var showsCompatibleListHint: Bool = true
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.brandHighlight)
                .accessibilityHidden(true)

            Text(RoomPlanCapability.unsupportedTitle)
                .font(LimiTypography.title2)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text(RoomPlanCapability.unsupportedMessage)
                .font(LimiTypography.callout)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            if showsCompatibleListHint {
                Label("Saved scans stay available here", systemImage: "checkmark.circle.fill")
                    .font(LimiTypography.footnote)
                    .foregroundStyle(Color.appSuccess)
                    .padding(.top, 4)
            }

            if let onDismiss {
                Button("OK", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandAction)
                    .padding(.top, 8)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
