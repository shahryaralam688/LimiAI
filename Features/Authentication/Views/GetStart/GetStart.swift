//
//  GetStart 2.swift
//  Limi
//
//  Created by Mac Mini on 11/03/2025.
//


import SwiftUI

struct GetStart: View {
    var onBack: (() -> Void)? = nil

    @Environment(\.appEnvironment) private var appEnvironment

    var body: some View {
        GetStartContent(appEnvironment: appEnvironment, onBack: onBack)
    }
}

private struct GetStartContent: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GetStartViewModel
    @State private var selectedRole: GetStart.Role? = nil
    @State private var showGetStarted = false

    private let onBack: (() -> Void)?

    init(appEnvironment: AppEnvironment, onBack: (() -> Void)?) {
        _viewModel = StateObject(wrappedValue: GetStartViewModel(environment: appEnvironment))
        self.onBack = onBack
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: 0){
            // Image at the top
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
                        Color.appCanvasPrimary.opacity(1.0),
                        Color.appCanvasPrimary.opacity(0.8)
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
                        
                        Text("Select Your Type")
                            .font(.system(size: 28, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
                            .multilineTextAlignment(.center)          // text-align: center
                            .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                            .kerning(-0.3)                            // letter-spacing: -1%
                            .foregroundColor(.appTextPrimary)
                        Text("Choose your role below:")
                            .font(.system(size: 16, weight: .regular, design: .rounded)) // font-family + weight/style
                            .multilineTextAlignment(.center)             // text-align: center
                            .foregroundColor(.appTextPrimary)
                            .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
                            .kerning(-0.048)                             // -0.3% of 16px = -0.048
                            .fixedSize(horizontal: false, vertical: true)

                    }
                )
            
            VStack{
                
                
                RoleCard(
                    role: .deafOrHardOfHearing,
                    isSelected: selectedRole == .deafOrHardOfHearing,
                    action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            selectedRole = .deafOrHardOfHearing
                            showGetStarted = true
                        }
                    }
                )
                .padding(.horizontal, 20)
                
                RoleCard(
                    role: .signLanguageInterpreter,
                    isSelected: selectedRole == .signLanguageInterpreter,
                    action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedRole = .signLanguageInterpreter
                            showGetStarted = true
                        }
                    }
                    
                )
                .padding(.horizontal, 20)
                
                // Space Selection Radio Button
                SpaceSelectionView()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                
                GetStartedButton(
                    viewModel: viewModel,
                    isEnabled: selectedRole != nil,
                    isVisible: showGetStarted,
                    selectedRole: selectedRole
                )
                .padding(.top , 40)
//                GetStartedButton(
//                    isEnabled: selectedRole != nil,
//                    isVisible: showGetStarted,
//                    selectedRole: selectedRole
//                )
//                .padding(.bottom, 40)
            }
            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.appCanvasPrimary)
        .trackScreen(
            "GetStart",
            metadata: [
                "ui_guide": "Choose your user type (installer vs end user), optional space selection, then Get Started to continue to sign-in."
            ]
        )

        
    
//            ZStack(alignment: .top) {
//                Color.themeBlack
//                VStack(spacing: 0) {
//                    VStack {
//                        Image("wire")
//                            .resizable()
//                            .scaleEffect(heroScale)
//                            .frame(
//                                width: 50,
//                                height: 250
//                            )
//                            .onAppear {
//                                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
//                                    heroScale = 1.0
//                                }
//                            }
//
//                        Image("ceilingHorizaontal")
//                            .resizable()
//                            .padding(.top, -20)
//                            .aspectRatio(contentMode: .fit)
//                            .scaleEffect(heroScale)
//                            .frame(
//                                width: 200,
//                                height: 200
//                            )
//                            .onAppear {
//                                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
//                                    heroScale = 1.0
//                                }
//                            }
//                            .shadow(color: .themeWhite, radius: 4)
//                    }
//                    Spacer(minLength: 0)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//                .overlay(alignment: .bottom) {
//
//
//                        VStack(spacing: 0) {
//                            VStack(spacing: 16) {
//                                HStack {
//                                    Text("Choose your role below")
//                                        .font(.system(size: 18, weight: .semibold))
//                                        .multilineTextAlignment(.leading)
//                                        .foregroundColor(.alabaster )
//                                        .fixedSize(horizontal: false, vertical: true)
//                                    Spacer()
//                                }
//                                .padding(.top, 24)
//                                .padding(.horizontal, 20)
//
//                                VStack(spacing: 12) {
//                                    RoleCard(
//                                        role: .deafOrHardOfHearing,
//                                        isSelected: selectedRole == .deafOrHardOfHearing,
//                                        action: {
//                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
//                                                selectedRole = .deafOrHardOfHearing
//                                                showGetStarted = true
//                                            }
//                                        }
//                                    )
//                                    .shadow(color: .alabaster, radius: 2)
//                                    .padding(.horizontal, 20)
//
//                                    RoleCard(
//                                        role: .signLanguageInterpreter,
//                                        isSelected: selectedRole == .signLanguageInterpreter,
//                                        action: {
//                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
//                                                selectedRole = .signLanguageInterpreter
//                                                showGetStarted = true
//                                            }
//                                        }
//                                    )
//                                    .shadow(color: .alabaster, radius: 2)
//                                    .padding(.horizontal, 20)
//                                }
//                            }
//
//                            GetStartedButton(
//                                isEnabled: selectedRole != nil,
//                                isVisible: showGetStarted,
//                                selectedRole: selectedRole
//                            )
//                            .padding(.bottom, 40)
//                        }
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//                }
//            }
        
//        ZStack {
//            ElegantGradientBackgroundView()
//
//            VStack() {

//                Spacer()
//
//                ZStack {
//
//                VStack(spacing: 20) {
//                    // Animated Header
//                    HStack{
//                        Text("Choose your role below")
//                            .font(.system(size: 28, weight: .bold))
//                            .multilineTextAlignment(.leading)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .padding(.top, 20)
//                            .padding(.horizontal, 24)
//                            .opacity(isAnimating ? 1 : 0)
//                            .offset(y: isAnimating ? 0 : 30)
//                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
//                            .shadow(radius: 1)
//                            .foregroundColor(.charlestonGreen)  // Change the text color here
//                        Spacer()
//                    }
//
//                    VStack(spacing: 20) {
//                        // Installer Role Card
//                        RoleCard(
//                            role: .deafOrHardOfHearing,
//                            isSelected: selectedRole == .deafOrHardOfHearing,
//                            action: {
//                                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
//                                    selectedRole = .deafOrHardOfHearing
//                                    showGetStarted = true
//                                }
//                            }
//                        )
//                        .shadow(color: .alabaster , radius: 2)
//
////                        ZStack{
////
////                            // Animated "or" text
////                            Text("or")
////                                .font(.custom("Amenti-back", size: 26))
////                                .foregroundColor(.charlestonGreen)
////                                .padding(.vertical, 4)
////
////                            Circle()
////                                .fill(Color.alabaster)
////                                .opacity(0.2)
////                                .frame(width: 40, height: 40)
////
////                        }
//                        .opacity(isAnimating ? 1 : 0)
//                        .scaleEffect(isAnimating ? 1 : 0.5)
//                        .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
//
//
//                        // User Role Card
//                        RoleCard(
//                            role: .signLanguageInterpreter,
//                            isSelected: selectedRole == .signLanguageInterpreter,
//                            action: {
//                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
//                                    selectedRole = .signLanguageInterpreter
//                                    showGetStarted = true
//                                }
//                            }
//                        )
//                        .shadow(color: .alabaster , radius: 2)
//
//                        //                    ZStack{
//                        //
//                        //                        // Animated "or" text
//                        //                        Text("or")
//                        //                            .font(.custom("Amenti-back", size: 26))
//                        //                            .foregroundColor(.charlestonGreen)
//                        //                            .padding(.vertical, 4)
//                        //
//                        //                        Circle()
//                        //                            .fill(Color.alabaster)
//                        //                            .opacity(0.2)
//                        //                            .frame(width: 40, height: 40)
//                        //
//                        //                    }
//                        //                    .opacity(isAnimating ? 1 : 0)
//                        //                    .scaleEffect(isAnimating ? 1 : 0.5)
//                        //                    .animation(.spring(response: 0.5).delay(0.3), value: isAnimating)
//                        //
//                        //                    // User Role Card
//                        //                    RoleCard(
//                        //                        role: .productionUser,
//                        //                        isSelected: selectedRole == .productionUser,
//                        //                        action: {
//                        //                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
//                        //                                selectedRole = .productionUser
//                        //                                showGetStarted = true
//                        //                            }
//                        //                        }
//                        //                    )
//                        //                    .shadow(color: .alabaster , radius: 2)
//                        //
//
//                    }
//                    // Get Started Button
//                    GetStartedButton(isEnabled: selectedRole != nil, isVisible: showGetStarted, selectedRole: selectedRole)
//
//
//                }
//
//                }
//                .background(
//                    GeometryReader { geo in
//                        Image("bgOnboarding")
//                            .resizable()
//                            .scaledToFill()
//                            .frame(height: 300 + geo.safeAreaInsets.bottom)
//                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                                    .stroke(Color.themeWhite, lineWidth: 1)
//                            )
//                    }
//                )
//            }
//
//        }
//        .onAppear {
//            withAnimation {
//                isAnimating = true
//            }
//        }
//        .navigationBarBackButtonHidden(true) // Hides the default back button
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    // Go back to the previous screen
//                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                       let window = windowScene.windows.first {
//                        window.rootViewController?.dismiss(animated: true, completion: nil)
//                    }
//                }) {
//                    Image(systemName: "chevron.left")
//                        .foregroundColor(Color.charlestonGreen) // Change the color here
//                        .font(.system(size: 20, weight: .bold))
//                }
//            }
//        }
//        .ignoresSafeArea()
//        .fullScreenCover(isPresented: $navigateToAddDevice) {
//            AddDeviceView()
//        }
//        .fullScreenCover(isPresented: $navigateToSignIn) {
//            LoginView()
//        }
//        .fullScreenCover(isPresented: $navigateToSignInPU) {
//            PULoginView()
//        }
    }
}

extension GetStart {
    enum Role {
        case deafOrHardOfHearing // Installer
        case signLanguageInterpreter // User
    }
}

struct GetStartedButton: View {
    @ObservedObject var viewModel: GetStartViewModel
    let isEnabled: Bool
    let isVisible: Bool
    let selectedRole: GetStart.Role?

    var body: some View {
        Button(action: {
            viewModel.continueWithRole(selectedRole)
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                } else {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(isEnabled ? 1 : 0)
                        .scaleEffect(isEnabled ? 1 : 0.7)
                        .animation(.spring(response: 0.3), value: isEnabled)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orbGlow4, .orbGlow1],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isVisible)
        }
        .padding(.horizontal, 20)
        .disabled(!isEnabled || viewModel.isLoading)
        .fullScreenCover(item: $viewModel.activeAuthRoute) { route in
            AuthCoordinator.destination(for: route)
        }
    }
}


struct RoleCard: View {
    let role: GetStart.Role
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(getRoleTitle(role))
                        .font(.custom("WorkSans-Bold", size: 20)) // font-family: Work Sans; weight: 700; style: Bold
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .lineSpacing(0)                            // line-height: 100% → same as font size
                        .kerning(-0.1)                             // letter-spacing: -0.5% of 20px ≈ -0.1
                        .foregroundColor(.appTextPrimary)
                        .padding(.top, 12)
                    Spacer()


                    
                }

                Spacer()
                // Role illustration
                Group {
                    switch role {
                    case .deafOrHardOfHearing:
                        VStack{
                            Spacer()
                            Image("installer_image")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        
                    case .signLanguageInterpreter:
                 
                        VStack{
                            Spacer()
                            Image("User_image")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
//                .padding(.trailing, 16)
            }
            .frame(height: 132)
            .frame(width: 343)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.orbGlow4 : Color.appCanvasPrimary)
                        .scaleEffect(isSelected ? 1 : 0.95)


                    // Selection indicator
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orbGlow4, lineWidth:  2 )
                        .scaleEffect(isSelected ? 1 : 0.95)
                        .animation(.spring(response: 0.3), value: isSelected)
                }
            )
            .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
            .animation(.spring(response: 0.3), value: isSelected || isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
//        .frame(height: 70)
    }
    private func getRoleTitle(_ role: GetStart.Role) -> String {
        switch role {
        case .deafOrHardOfHearing: return "Installer"
        case .signLanguageInterpreter: return "User"
        }
    }
    
    private func getRoleDescription(_ role: GetStart.Role) -> String {
        switch role {
        case .deafOrHardOfHearing:
            return "Temporary access to configure your LIMI installation."
        case .signLanguageInterpreter:
            return "Personalize and transform your LIMI lighting experience."
        }
    }
}

struct SpaceSelectionView: View {
    @State private var selectedSpace: String = globalUserSpace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Space Type")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                // Home Option
                RadioButton(
                    title: "Home",
                    isSelected: selectedSpace == "home",
                    action: {
                        selectedSpace = "home"
                        globalUserSpace = "home"
                        print("Selected space: \(globalUserSpace)")
                    }
                )
                
                // Hotel Option
                RadioButton(
                    title: "Hotel",
                    isSelected: selectedSpace == "hospatelity",
                    action: {
                        selectedSpace = "hospatelity"
                        globalUserSpace = "hospatelity"
                        print("Selected space: \(globalUserSpace)")
                    }
                )
                
                Spacer()
            }
        }
        .onAppear {
            selectedSpace = globalUserSpace
        }
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(Color.orbGlow4, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.orbGlow4)
                            .frame(width: 12, height: 12)
                            .scaleEffect(isSelected ? 1 : 0)
                            .animation(.spring(response: 0.3), value: isSelected)
                    }
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orbGlow4.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orbGlow4 : Color.appBorderPrimary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    GetStart()
}
