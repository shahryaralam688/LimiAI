//
//  DemoAddDevicesView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 26/10/2025.
//

import SwiftUI
struct DemoConnectedWifiView: View {
    // back to Onboarding last page
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    let deviceName: String?
    @State private var showDemoScanDevicesView = false


    var body: some View {
        VStack {
            VStack(spacing: 16){
                AnimatedSearchButton(iconName: "checkmark.circle.fill")
                    .padding(.top,100)
                
                
                Text(deviceName ?? "Device")
                    .font(.system(size: 20, weight: .medium, design: .rounded))   // 500 weight = Medium
                    .foregroundColor(Color.themeWhite)      // matches #C9C4BD
                    .multilineTextAlignment(.center)             // aligns text centrally
                    .lineSpacing(0)                              // 100% line height = no extra spacing
                    .kerning(0)// letter-spacing: 0px
                    .padding(.top, 32)
                
                Text("Device added Successfully")
                    .font(.system(size: 24, weight: .medium, design: .rounded))   // 500 weight = Medium
                    .foregroundColor(Color.themeWhite)      // matches #C9C4BD
                    .multilineTextAlignment(.center)             // aligns text centrally
                    .lineSpacing(0)                              // 100% line height = no extra spacing
                    .kerning(0)// letter-spacing: 0px
            }

            Spacer()
            // Add devices Button
            Button(action: {
                showDemoScanDevicesView = true
            }) {
                HStack {
                    Spacer()
                    
                    Text("Add Your First Device")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextInverse)
                        .lineSpacing(0) // line-height: 100% (no extra spacing)
                        .kerning(0)     // letter-spacing: 0%
                    Image("Monotone arrow right")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextInverse)
                        .lineSpacing(0) // line-height: 100% (no extra spacing)
                        .kerning(0)     // letter-spacing: 0%
                    Spacer()
                }
                .font(.system(size: 17, weight: .semibold))
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color.themeWhite)
                .foregroundColor(.themeBlack)
                .clipShape(Capsule(style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 27)
        }
        .background(Color.appCanvasPrimary)
        .fullScreenCover(isPresented: $showDemoScanDevicesView) {
            ConnectedDevicesView()
        }
    }
}

#Preview {
    DemoConnectedWifiView( deviceName: "xyz")
}
