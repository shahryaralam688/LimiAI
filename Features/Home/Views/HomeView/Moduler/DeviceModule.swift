//
//  DeviceModule.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 21/11/2025.
//

//VStack(spacing: 0) {
//
////                    WeatherWidgetView()
//    voiceOrb
//    VStack{
//        HStack{
//            Text("Connected Space")
//                .font(.custom("Poppins-Medium", size: 18))
//                .foregroundColor(.themeWhite)
//                .multilineTextAlignment(.center)
//                .lineSpacing(18 * 0.2)
//                .tracking(-0.15 / 18)
//            Spacer()
//        }
//
//        let role = AuthManager.shared.getRole()
//        if role == "Installer User created" {
//            Text("Please log in to view your Wi-Fi devices.")
//                .foregroundColor(.gray)
//                .padding()
//        } else {
//            if wifiDevices.isEmpty {
//                VStack {
//                    VStack(spacing: 16) {
//                        Text("You haven’t added any devices yet")
//                            .font(.custom("Poppins-Medium", size: 16))
//                            .foregroundColor(Color.appTextSecondary)
//                            .multilineTextAlignment(.center)
//                            .lineSpacing(16 * 0.4)
//                            .kerning(0)
//
//                        Text("Tap the button below to add devices")
//                            .font(.custom("Poppins-Regular", size: 14))
//                            .foregroundColor(Color.appTextMuted)
//                            .multilineTextAlignment(.center)
//                            .lineSpacing(14 * 0.4)
//                            .kerning(0)
//
//                        Button(action: {
//                            isShowingLogin = true
//                        }) {
//                            HStack {
//                                Image(systemName: "plus")
//                                    .font(.custom("Poppins-Medium", size: 14))
//                                    .foregroundColor(Color.charlestonGreen)
//                                Text("Add Your First Device")
//                                    .font(.custom("Poppins-Medium", size: 14))
//                                    .foregroundColor(Color.charlestonGreen)
//                            }
//                            .font(.system(size: 17, weight: .semibold))
//                            .padding(.vertical, 14)
//                            .padding(.horizontal, 20)
//                            .background(Color.emerald)
//                            .foregroundColor(.themeBlack)
//                            .cornerRadius(12)
//                        }
//                    }
//                    .frame(height: 304)
//                    .frame(maxWidth: .infinity)
//                    .background(
//                        LinearGradient(
//                            gradient: Gradient(colors: [Color.appSurfacePrimary, Color.appSurfacePrimary]),
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 8)
//                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
//                            .foregroundColor(Color.appBorderSecondary)
//                    )
//                    .cornerRadius(8)
//                    .opacity(1)
//                }
//            } else {
//                ScrollView {
//                    LazyVGrid(columns: columns, spacing: 16) {
//                        ForEach(wifiDevices) { device in
//                            WifiDeviceSpace(
//                                chennalMac: device.chennalMac,
//                                chennalCount: device.chennalCount,
//                                deviceName: device.deviceName,
//                                isOnline: device.isOnline
//                            )
//                            .contentShape(Rectangle())
//                            .onTapGesture {
//                                selectedWifiDevice = device
//                            }
//                        }
//                    }
//                    .padding()
//                }
//            }
//        }
//    }.zIndex(1)
//        .padding(.horizontal, 16)
//
//    Spacer()
//}
