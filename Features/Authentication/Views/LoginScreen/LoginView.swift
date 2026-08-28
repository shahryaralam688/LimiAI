import SwiftUI
import RealityKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @StateObject private var authManager = GoogleAuthManager()
    @Environment(\.dismiss) private var dismiss
    // Keyboard handling
    @FocusState private var isEmailFieldFocused: Bool

    var body: some View {
        NavigationStack {
        ZStack {
            // Background color
            Color.appCanvasPrimary
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image with Gradient Overlay
                    ZStack(alignment: .bottom) {
                        Image("GetStartImage")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 256)
                            .clipped()
                        
                        // Bottom gradient overlay
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appCanvasPrimary,
                                Color.appCanvasPrimary
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 120)
                        .blur(radius: 20)
                    }
                    .frame(height: 256)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        // Content within safe area
                        VStack(spacing: 0) {
                            // Title
                            Text("Sign In")
                                .font(LimiTypography.largeTitle) // font-family: Poppins; weight: 700 (Bold)
                                .multilineTextAlignment(.center)          // text-align: center
                                .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                                .kerning(-0.3)                            // letter-spacing: -1%
                                .foregroundColor(.appTextPrimary)
                            
                            // Subtitle
                            Text("Sign in to keep your space personal and secure.")
                                .font(LimiTypography.body) // font-family + weight/style
                                .multilineTextAlignment(.center)             // text-align: center
                                .foregroundColor(.appTextPrimary)
                                .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
                                .kerning(-0.048)                             // -0.3% of 16px = -0.048
                                .fixedSize(horizontal: false, vertical: true)
                            
                            
                        }
                    )
                    // Email Label
                    HStack {
                        Text("Email Address")
                            .font(LimiTypography.title3)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    
                    // Email TextField
                    HStack(spacing: 12) {
                        Image("Monotone email")
//                        Image(systemName: "message.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.appTextPrimary)
                        
                        ZStack(alignment: .leading) {
                            if viewModel.email.isEmpty {
                                Text("you@example.com")
                                    .font(LimiTypography.body)
                                    .foregroundColor(.appTextPrimary) // ← placeholder (suggestion) text color
                                    
                            }
                            TextField("", text: $viewModel.email)
                                .font(LimiTypography.body)
                                .foregroundColor(.appTextPrimary)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.emailAddress)
                                .focused($isEmailFieldFocused)
                                .onSubmit {
                                    hideKeyboard()
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.appCanvasPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.appBrandPrimary, lineWidth: 2)
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    
                    // Primary Button
                    Button(action: {
                        guard viewModel.isEmailValid && !viewModel.isSigningIn else { return }
                        hideKeyboard()
                        viewModel.requestOTP()
                    }) {
                        ZStack {
                            // Keep button height/width consistent
                            HStack {
                                Spacer()
                                if viewModel.isSigningIn {
                                    // Built-in spinner
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.appTextPrimary)   // iOS 15+
                                        .scaleEffect(1.0)
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Sign in")
                                            .font(LimiTypography.button)
                                            .foregroundColor(.appTextInverse)
                                        Image("Monotone arrow right")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(Color.appCanvasTertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(Color.appBrandPrimary)
                            .cornerRadius(22)
                            .animation(LimiMotion.quick, value: viewModel.isSigningIn)
                        }
                    }
                    .disabled(!viewModel.isEmailValid || viewModel.isSigningIn)   // <-- stays disabled while loading
                    .padding(.horizontal, 20)
                    .padding(.top, 0)

                    if let otpError = viewModel.otpRequestErrorMessage {
                        Text(otpError)
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    Button(action: {
                        authManager.signInWithApple { success in
                            if success, AuthManager.shared.getToken() != nil {
                                DispatchQueue.main.async {
                                    AuthManager.shared.isAuthenticated = true
                                    viewModel.isOTPVerified = true
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(LimiTypography.title3)
                            Text("Sign in with Apple")
                                .font(LimiTypography.button)
                        }
                        .foregroundColor(.appTextInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .limiPanel(cornerRadius: 22)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)

                    
                    // Primary Button
                    Button(action: {
                        authManager.signInWithGoogle { success in
                            if success, AuthManager.shared.getToken() != nil {
                                DispatchQueue.main.async {
                                    AuthManager.shared.isAuthenticated = true
                                    viewModel.isOTPVerified = true
                                }
                            }
                        }
                    }) {
                        ZStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image("google")
                                        .scaledToFit()
                                    Text("Continue with Google")
                                    
                                        .font(LimiTypography.button)
                                        .foregroundColor(.appTextPrimary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(Color.appBorderPrimary)
                            .cornerRadius(22)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)

                    Spacer(minLength: 100)
                }
                .opacity(viewModel.appeared ? 1 : 0)
                .animation(LimiMotion.gentle, value: viewModel.appeared)
                .onAppear { viewModel.appeared = true }
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Top Bar Overlay
            VStack {
                HStack {
                    Spacer()
                    
                    // Logo
                    Image("LoginViewLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 40)
                    
                    Spacer()
                    
                    // Invisible spacer to balance the logo centering
                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
            }
        }
        
        .sheet(isPresented: $viewModel.isShowingOTPView) {
            OTPVerificationView(
                email: viewModel.email,
                confirmationMessage: viewModel.otpSentConfirmationMessage,
                enteredOTP: $viewModel.enteredOTP,
                isOTPVerified: $viewModel.isOTPVerified
            )
        }
        .fullScreenCover(isPresented: $viewModel.isOTPVerified) {
            HomeView()
        }
        .limiModalNavigationBar(onClose: { dismiss() })
        }

    }
    
    // MARK: - Helper Functions
    private func hideKeyboard() {
        isEmailFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
