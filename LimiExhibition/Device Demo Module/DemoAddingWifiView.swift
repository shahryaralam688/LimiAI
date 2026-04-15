//
//  DemoAddDevicesView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 26/10/2025.
//

import SwiftUI
struct DemoAddingWifiView: View {
    // back to Onboarding last page
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    let deviceName: String
    let deviceId: String
    let wifiSSID: String

    @State private var wifiPassword: String = ""
    @ObservedObject private var ble = BluetoothManager.shared
    @State private var isProvisioning: Bool = false
    @State private var resultMessage: String = ""
    @State private var resultStatus: String = ""
    @State private var showWifiConected = false


    var body: some View {
        VStack {

            VStack(alignment: .center, spacing:12){
                HStack{
                    LimiBackButton {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    Spacer()
                    Text("Add Device")
                        .font(.system(size: 30, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
                        .multilineTextAlignment(.center)          // text-align: center
                        .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                        .kerning(-0.3)                            // letter-spacing: -1%
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                    Spacer()

                    
                }
                .padding(.horizontal, 16)
                



            }.padding(.bottom, 43)
            
            VStack(spacing: 16){
                HStack{
                    Text("Wifi Password")
                        .font(.system(size: 20, weight: .medium, design: .rounded))   // 500 weight = Medium
                        .foregroundColor(.appTextPrimary)      // matches #C9C4BD
                        .multilineTextAlignment(.center)             // aligns text centrally
                        .lineSpacing(0)                              // 100% line height = no extra spacing
                        .kerning(0)// letter-spacing: 0px
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                HStack{
                    ZStack(alignment: .leading) {
                        Text(wifiSSID)
                            .font(.system(size: 25, weight: .medium, design: .rounded))
                            .foregroundColor(.appTextPrimary) // ✅ Placeholder color
                            .kerning(-0.048)

                    }
                    .padding(.horizontal, 16)
                }


                .padding(.bottom, 34)
                HStack{
                    ZStack(alignment: .leading) {
                        if wifiPassword.isEmpty {
                            Text("Enter your Wi-Fi password")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color.appTextPlaceholder) // ✅ Placeholder color
                                .kerning(-0.048)
                        }
                        
                        TextField("", text: $wifiPassword)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color.appTextSoft) // Active text color (slightly brighter)
                            .kerning(-0.048)
                            .lineSpacing(0)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    

                    Spacer()
                    Image(systemName: "eye")
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 16)

                }
                .background(
                    Rectangle()
                        .fill(Color.appSurfacePrimary) // gray background
                        .cornerRadius(20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                )
                .padding(.horizontal, 16)

                

                            
                VStack{
                    Text("Connect Your Device to Wi-Fi")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))  // 600 weight = SemiBold
                        .foregroundColor(Color.appTextSecondary)        // matches background color spec
                        .multilineTextAlignment(.center)               // text-align: center
                        .lineSpacing(20 * 0.4)                         // line-height: 140%
                        .kerning(0)                                    // letter-spacing: 0%

                    Text("Enter your Wi-Fi password to link your device securely. This allows Limi to stay connected, sync with your other devices, and respond instantly — all within your private network.")
                        .font(.system(size: 14, weight: .regular, design: .rounded)) // font-family + weight + size
                        .foregroundColor(Color.appTextMuted)     // text color
                        .multilineTextAlignment(.center)            // text-align: center
                        .lineSpacing(4)                             // for line-height: 140%
                        .padding(.horizontal)

                }
                .background(
                    Rectangle()
                    .fill(Color.appSurfacePrimary) // gray background
                    .cornerRadius(20)
                    .frame(height: 148)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                .padding(.horizontal, 16)
                .padding(.top, 27)

            }
            Spacer()
            // Add devices Button
            LimiPrimaryButton(title: isProvisioning ? "Connecting…" : (ble.isConnected ? "Connected" : "Add Your First Device")) {
                guard !wifiSSID.isEmpty else { resultStatus = "error"; resultMessage = "SSID is required"; return }
                isProvisioning = true
                resultMessage = ""
                resultStatus = ""
                BluetoothManager.shared.provisionWifi(ssid: wifiSSID, password: wifiPassword) { res in
                    DispatchQueue.main.async {
                        self.isProvisioning = false
                        self.resultStatus = res.status
                        self.resultMessage = res.message
                    }
                }

                showWifiConected = true
            }
            .disabled(isProvisioning)
            .animation(LimiMotion.quick, value: isProvisioning)
            .animation(LimiMotion.quick, value: ble.isConnected)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(resultStatus == "success" ? .green : (resultStatus == "warning" ? .yellow : .red))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 15)
            }
//            .padding(.bottom, 12)
//            .padding(.horizontal, 16)
            
        }
        .background(Color.appCanvasPrimary)
        .fullScreenCover(isPresented: $showWifiConected) {
            DemoConnectedWifiView(deviceName: deviceName ?? "")
        }

    }
}

#Preview {
    DemoAddingWifiView(deviceName: "abc", deviceId: "xyz",  wifiSSID : "abc" )
}
