////
////  TemporaryAddDeviceView.swift
////  Limi
////
////  Created by Shahrukh Ahmed on 24/10/2025.
////
//
//
//import SwiftUI
//import RealityKit
//
//struct LocationStorageView: View {
//    
//    
//    var body: some View {
//        ZStack {
//            // Background color
//            Color(hex: "#111214")
//                .ignoresSafeArea(.all)
//            
//            
//            VStack(spacing: 0) {
//                // Hero Image with Gradient Overlay
//                ZStack(alignment: .bottom) {
//                    Image("GetStartImage")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(height: 256)
//                        .clipped()
//                    
//                    // Bottom gradient overlay
//                    LinearGradient(
//                        gradient: Gradient(colors: [
//                            Color(hex: "#111214"),
//                            Color(hex: "#111214")
//                        ]),
//                        startPoint: .bottom,
//                        endPoint: .top
//                    )
//                    .frame(height: 120)
//                    .blur(radius: 20)
//                }
//                .frame(height: 256)
//                .ignoresSafeArea(edges: .top)
//                .overlay(
//                    // Content within safe area
//                    VStack() {
//                        // Logo Image
//                        Image("logo")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 201, height: 40)
//                        
//                        // Title
//                        Text("Location")
//                            .font(.custom("Poppins-Bold", size: 30)) // font-family: Poppins; weight: 700 (Bold)
//                            .multilineTextAlignment(.center)          // text-align: center
//                            .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
//                            .kerning(-0.3)                            // letter-spacing: -1%
//                            .foregroundColor(Color.alabaster)
//                        
//                        // Subtitle
//                        Text("Let's personalize your Lifestyle with Limi")
//                            .font(.custom("Poppins-Regular", size: 16)) // font-family + weight/style
//                            .multilineTextAlignment(.center)             // text-align: center
//                            .foregroundColor(.alabaster)
//                            .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
//                            .kerning(-0.048)                             // -0.3% of 16px = -0.048
//                            .fixedSize(horizontal: false, vertical: true)
//                        
//                        
//                    }
//                )
//                Spacer()
//                
//            }
//        }
//        .scrollDismissesKeyboard(.interactively)
//        
//    }
//}
//struct LocationStorageView_Previews: PreviewProvider {
//    static var previews: some View {
//        LocationStorageView()
//    }
//}
//
