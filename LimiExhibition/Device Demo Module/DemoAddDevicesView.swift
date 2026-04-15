//
//  DemoAddDevicesView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//



//
//  DemoAddDevicesView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 26/10/2025.
//

import SwiftUI
struct DemoAddDevicesView: View {
    // back to Onboarding last page
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showScanDevices: Bool = false
    @State private var isShowingLogin: Bool = false
    
    @State private var showLoginSkip: Bool = false

    var body: some View {
        VStack {
            
            Image("GetStartImage")
                .resizable()
                .scaledToFill()
                .frame(height: 256)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    // Bottom border blur in black
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.themeBlack.opacity(1.0),
                            Color.themeBlack.opacity(0.8)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 40)  // height of the blurred border
                    .blur(radius: 60),   // controls softness of blur
                    alignment: .bottom
                )
                .overlay(
                    // Content overlay on top of image
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
                            Image("LoginViewLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 201, height: 40)
                            Spacer()
                            Spacer()
                            
                        }
                        .padding(.horizontal, 16)
                        
                        Text("Add Device")
                            .font(.system(size: 30, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
                            .multilineTextAlignment(.center)          // text-align: center
                            .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                            .kerning(-0.3)                            // letter-spacing: -1%
                            .foregroundColor(Color.appTextPrimary)
                        Text("Add your device below:")
                            .font(.system(size: 16, weight: .regular, design: .rounded)) // font-family + weight/style
                            .multilineTextAlignment(.center)             // text-align: center
                            .foregroundColor(.appTextPrimary)
                            .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
                            .kerning(-0.048)                             // -0.3% of 16px = -0.048
                            .fixedSize(horizontal: false, vertical: true)

                    }
                    .limiAppear(delay: 0.1)
                )
            VStack{
                HStack{
                    Text("My Spaces")
                        .font(.system(size: 20, weight: .medium, design: .rounded))   // 500 weight = Medium
                        .foregroundColor(Color.appTextSecondary)      // matches #C9C4BD
                        .multilineTextAlignment(.center)             // aligns text centrally
                        .lineSpacing(0)                              // 100% line height = no extra spacing
                        .kerning(0)// letter-spacing: 0px
                    Spacer()
                }
                                
                VStack(spacing: 16){
                    Text("You haven’t added any devices yet")
                        .font(.system(size: 16, weight: .medium, design: .rounded))   // 500 weight = Medium
                        .foregroundColor(Color.appTextSecondary)      // matches #C9C4BD
                        .multilineTextAlignment(.center)             // text-align: center
                        .lineSpacing(16 * 0.4)                       // 140% line height
                        .kerning(0)
                    
                    Text("Tap button below to add devices")
                        .font(.system(size: 14, weight: .regular, design: .rounded)) // weight 400 = Regular
                        .foregroundColor(Color.appTextMuted)     // custom color
                        .multilineTextAlignment(.center)            // text-align: center
                        .lineSpacing(14 * 0.4)                      // line-height: 140% → +40% of font size
                        .kerning(0)                                 // letter-spacing: 0px

                    // Add devices Button
                    LimiPrimaryButton(title: "Add Your First Device") {
                        isShowingLogin = true
                    }
                }
                .frame( height: 304)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.appSurfacePrimary, Color.appSurfacePrimary]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Dashed border
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                        )
                        .foregroundColor(Color.appBorderSecondary)
                )
                .cornerRadius(8)
                .opacity(1)
            }
            .padding(.horizontal,16)
            Spacer()
            Text("Skip")
                .font(.system(size: 16, weight: .medium, design: .rounded)) // font-family + style
                .foregroundColor(Color.appTextPrimary)    // background color in design is likely text color
                .underline(true, color: Color.appTextPrimary) // underline as specified
                .kerning(0)                               // letter-spacing: 0%
                .lineSpacing(0)                            // line-height: 100%
                .padding(.bottom, 50)
                .onTapGesture {
                    showLoginSkip = true
                }


        }
        .background(Color.appCanvasPrimary)
        .ignoresSafeArea(.all)
        
        .fullScreenCover(isPresented: $showLoginSkip) {
            LoginSkipView()
        }
        .fullScreenCover(isPresented: $isShowingLogin){
//            LoginView()
            DemoScanDevicesView()

        }
        
    }
}

#Preview {
    DemoAddDevicesView()
}
