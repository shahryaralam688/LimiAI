import SwiftUI
import RealityKit
import AuthenticationServices

struct LoginView: View {
    @State private var isSigningIn: Bool = false
    @StateObject private var authManager = GoogleAuthManager()

    @State private var email: String = ""
    @State private var isShowingOTPView: Bool = false
    @State private var generatedOTP: String = ""
    @State private var enteredOTP: String = ""
    @State private var isOTPVerified: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isEmailVerified: Bool = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @State private var showHomeView: Bool = false
    // Keyboard handling
    @FocusState private var isEmailFieldFocused: Bool
    @State private var appeared = false
    
    // Email validation
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var body: some View {
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
                                .font(.system(size: 28, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
                                .multilineTextAlignment(.center)          // text-align: center
                                .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                                .kerning(-0.3)                            // letter-spacing: -1%
                                .foregroundColor(.appTextPrimary)
                            
                            // Subtitle
                            Text("Please Sign in to secure your data and for personalization")
                                .font(.system(size: 16, weight: .regular, design: .rounded)) // font-family + weight/style
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
                            .font(.system(size: 20, weight: .bold, design: .rounded))
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
                            if email.isEmpty {
                                Text("you@example.com")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.appTextPrimary) // ← placeholder (suggestion) text color
                                    
                            }
                            TextField("", text: $email)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
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
                        guard isEmailValid && !isSigningIn else { return }
                        hideKeyboard()
                        withAnimation(.easeInOut(duration: 0.15)) { isSigningIn = true }
                        generateOTP()
                    }) {
                        ZStack {
                            // Keep button height/width consistent
                            HStack {
                                Spacer()
                                if isSigningIn {
                                    // Built-in spinner
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.appTextPrimary)   // iOS 15+
                                        .scaleEffect(1.0)
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Sign in")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                            .animation(LimiMotion.quick, value: isSigningIn)
                        }
                    }
                    .disabled(!isEmailValid || isSigningIn)   // <-- stays disabled while loading
                    .padding(.horizontal, 20)
                    .padding(.top, 0)


                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [] // <-- no email or name requested
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                switch authResults.credential {
                                case let appleIDCredential as ASAuthorizationAppleIDCredential:
                                    if let tokenData = appleIDCredential.identityToken,
                                       let tokenString = String(data: tokenData, encoding: .utf8) {
                                        print("Apple Identity Token: \(tokenString)")
                                        // Send token to your backend for verification
                                        
                                        authManager.signInWithApple { success in
                                            if success {
                                                DispatchQueue.main.async {
                                                    isOTPVerified = true
                                                }
                                            }
                                        }
                                    }
                                default:
                                    break
                                }
                            case .failure(let error):
                                print("Apple SignIn failed: \(error.localizedDescription)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white) // or .themeWhite
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(22)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)

                    
                    // Primary Button
                    Button(action: {
                        authManager.signInWithGoogle { success in
                            if success {
                                DispatchQueue.main.async {
                                    isOTPVerified = true
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
                                    
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                .opacity(appeared ? 1 : 0)
                .animation(LimiMotion.gentle, value: appeared)
                .onAppear { appeared = true }
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Top Bar Overlay
            VStack {
                HStack {
                    // Back Button
                    LimiBackButton { dismiss() }
                    
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
        
        .sheet(isPresented: $isShowingOTPView) {
            OTPVerificationView(email: email, enteredOTP: $enteredOTP, isOTPVerified: $isOTPVerified)
        }
        .fullScreenCover(isPresented: $isOTPVerified) {
            HomeView()
        }

    }
    
    // MARK: - Helper Functions
    private func hideKeyboard() {
        isEmailFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func generateOTP() {
        guard let url = URL(string: APIConstants.sendOTP) else {
            print("Invalid URL")
            return
        }
        
        let parameters: [String: Any] = ["email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            print("Error converting parameters to JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = jsonResponse["success"] as? Bool, success {
                        DispatchQueue.main.async {
                            self.generatedOTP = jsonResponse["otp"] as? String ?? ""
                            self.isShowingOTPView = true
                            print("Generated OTP: \(self.generatedOTP)")
                        }
                    } else {
                        let errorMessage = jsonResponse["error_message"] as? String ?? "Unknown error"
                        print("Error: \(errorMessage)")
                    }
                }
            } catch {
                print("JSON decoding error: \(error.localizedDescription)")
            }
        }.resume()
    }
}

import SwiftUI

struct OTPVerificationView: View {
    var email: String
    @Environment(\.dismiss) private var dismiss
    
//    @State private var showAddDevices = false
    @EnvironmentObject var authManager: AuthManager
    
    @Binding var enteredOTP: String
    @Binding var isOTPVerified: Bool

    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    // Animation states
    @State private var isAppearing: Bool = false
    @State private var isVerifying: Bool = false
    @State private var digitBoxes: [Bool] = Array(repeating: false, count: 6)
    @State private var shakeError: Bool = false
    
    // For individual OTP digit focus
    @FocusState private var focusedField: Int?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.appCanvasPrimary, Color.appSurfacePrimary]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // Animated background shapes
            ZStack {
                Circle()
                    .fill(Color.appCanvasPrimary.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -150, y: -250)
                    .scaleEffect(isAppearing ? 1.0 : 0.8)
                
                Circle()
                    .fill(Color.appCanvasPrimary.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: 150, y: 350)
                    .scaleEffect(isAppearing ? 1.0 : 0.8)
            }
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAppearing)
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.themeBlack)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.appSurfacePrimary)
                                .shadow(color: Color.appCanvasPrimary.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .scaleEffect(isAppearing ? 1.0 : 0.8)
                        .opacity(isAppearing ? 1.0 : 0.5)
                    
                    Text("Verification Code")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .offset(y: isAppearing ? 0 : 20)
                    
                    Text("Please enter the 6-digit code sent to\n\(email)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .offset(y: isAppearing ? 0 : 20)
                }
                
                // OTP Input Boxes
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPDigitBox(
                            digit: index < enteredOTP.count ? String(Array(enteredOTP)[index]) : "",
                            isActive: digitBoxes[index]
                        )
                        .scaleEffect(isAppearing ? 1.0 : 0.8)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: isAppearing)
                    }
                }
                .padding(.horizontal)
                .modifier(ShakeEffect(animatableData: shakeError ? 1 : 0))
                .animation(LimiMotion.quick, value: shakeError)
                
                // Hidden TextField for keyboard input
                TextField("", text: $enteredOTP)
                    .keyboardType(.numberPad)
                    .frame(width: 1, height: 1)
                    .opacity(0.1)
                    .focused($focusedField, equals: 0)
                    .onChange(of: enteredOTP) { oldValue, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            enteredOTP = String(newValue.prefix(6))
                        }
                        
                        // Animate the boxes as digits are entered
                        for i in 0..<6 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.05)) {
                                digitBoxes[i] = i < newValue.count
                            }
                        }
                        
                        // Clear error when typing
                        if errorMessage != nil {
                            errorMessage = nil
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusedField = 0
                        }
                    }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.appDanger)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appBrandPrimary)
                            .shadow(color: Color.appCanvasPrimary.opacity(0.5), radius: 10, x: 0, y: 5)
                            .frame(height: 56)
                        
                        if isLoading {
                            LottieLoadingView()
                                .frame(width: 30, height: 30)
                        } else {
                            Text("Verify")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)
                        }
                    }
                    .scaleEffect(isVerifying ? 0.95 : 1.0)
                }
                .disabled(enteredOTP.count < 6 || isLoading)
                .opacity(enteredOTP.count < 6 ? 0.7 : 1.0)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                
                // Resend code option
                HStack(spacing: 5) {
                    Text("Didn't receive the code?")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                    
                    Button(action: {
                        // Call the generateOTP function again
                        generateOTP()
                    }) {
                        Text("Resend")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .padding(.top, 5)
                .opacity(isAppearing ? 1.0 : 0.0)
                .offset(y: isAppearing ? 0 : 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.appCanvasPrimary.opacity(0.95))
                    .shadow(color: Color.appSurfacePrimary.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 50)
            .scaleEffect(isAppearing ? 1.0 : 0.9)
            .opacity(isAppearing ? 1.0 : 0.0)
        }
        .onAppear {
            // Trigger animations when view appears
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAppearing = true
            }
            // Start background animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                isAppearing = true
            }
        }
        .trackScreen(
            "OTPVerificationView",
            metadata: [
                "ui_guide": "Enter the six-digit code from your email, then Verify. Use Resend if needed. Never share the OTP in voice chat."
            ]
        )
    }
    
    func verifyOTP() {
        guard let url = URL(string: APIConstants.verifyOTP) else {
            errorMessage = "Invalid URL"
            return
        }
        
        let parameters: [String: Any] = [
            "email": email,
            "otp": enteredOTP.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            errorMessage = "Error creating JSON"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        withAnimation {
            isLoading = true
            isVerifying = true
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation {
                    isLoading = false
                    isVerifying = false
                }
                
                if let error = error {
                    errorMessage = "Request failed: \(error.localizedDescription)"
                    triggerErrorAnimation()
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    triggerErrorAnimation()
                    return
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let success = jsonResponse["success"] as? Bool, success {
                            if let dataDict = jsonResponse["data"] as? [String: Any],
                               let token = dataDict["token"] as? String {
                                AuthManager.shared.saveToken(token, updateAuthState: false)
                                AuthManager.shared.clearRole()
                                print(dataDict)
                                print("Received Token: \(token)")
                            } else {
                                print("Token not found in response: \(jsonResponse)")
                            }
                            
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                self.isOTPVerified = true
                            }
                            // Dismiss the OTP sheet shortly after triggering navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.dismiss()
                            }
                        } else {
                            errorMessage = jsonResponse["error_message"] as? String ?? "Invalid OTP"
                            triggerErrorAnimation()
                        }
                    }
                } catch {
                    errorMessage = "Failed to parse response"
                    triggerErrorAnimation()
                }
            }
        }.resume()
    }
    
    func generateOTP() {
        guard let url = URL(string:  APIConstants.sendOTP) else {
            errorMessage = "Invalid URL"
            return
        }
        
        let parameters: [String: Any] = ["email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            errorMessage = "Error converting parameters to JSON"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        withAnimation {
            isLoading = true
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation {
                    isLoading = false
                }
                
                if let error = error {
                    errorMessage = "Request failed: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = jsonResponse["success"] as? Bool, success {
                            errorMessage = "OTP sent successfully!"
                            // Clear the current OTP input
                            enteredOTP = ""
                            for i in 0..<6 {
                                digitBoxes[i] = false
                            }
                        } else {
                            let errorMsg = jsonResponse["error_message"] as? String ?? "Unknown error"
                            errorMessage = "Error: \(errorMsg)"
                        }
                    }
                } catch {
                    errorMessage = "JSON decoding error"
                }
            }
        }.resume()
    }
    
    func triggerErrorAnimation() {
        withAnimation(.default) {
            shakeError = true
        }
        
        // Reset the shake after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.default) {
                shakeError = false
            }
        }
    }
}

// OTP Digit Box Component
struct OTPDigitBox: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.appBorderPrimary : Color.appBorderPrimary.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                )
                .frame(width: 45, height: 55)
                .shadow(color: isActive ? Color.appCanvasPrimary.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
            
            if !digit.isEmpty {
                Text(digit)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextInverse)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digit)
    }
}

// Custom Loading Animation
struct LottieLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.appSurfacePrimary)
                    .frame(width: 8, height: 8)
                    .offset(y: isAnimating ? -10 : 0)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.2 * Double(index)),
                        value: isAnimating
                    )
            }
            .offset(x: -20)
            
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.appSurfacePrimary)
                    .frame(width: 8, height: 8)
                    .offset(y: isAnimating ? -10 : 0)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.2 * Double(index) + 0.3),
                        value: isAnimating
                    )
            }
            .offset(x: 20)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Shake Effect Modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 5), y: 0))
    }
}

import SwiftUI

struct KeyboardResponsiveModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height - 20
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func keyboardResponsive() -> some View {
        self.modifier(KeyboardResponsiveModifier())
    }
}



struct LoginSkipView: View {
    @State private var email: String = ""
    @State private var isShowingOTPView: Bool = false
    @State private var generatedOTP: String = ""
    @State private var enteredOTP: String = ""
    @State private var isOTPVerified: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isEmailVerified: Bool = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @State private var showHomeView: Bool = false
    // Keyboard handling
    @FocusState private var isEmailFieldFocused: Bool
    @State private var isLoading = false
    @StateObject private var authManager = GoogleAuthManager()
    @StateObject private var authAppleManager = AppleAuthManager()
    
    // Email validation
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var body: some View {
        ZStack {
            // Background color
            Color.appCanvasPrimary
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
                VStack(spacing: 0) {
                    HStack {
                        // Back Button
                        LimiBackButton { dismiss() }
                        
                        Spacer()
                        
    //                    // Logo
    //                    Image("LoginViewLogo")
    //                        .resizable()
    //                        .aspectRatio(contentMode: .fit)
    //                        .frame(width: 200, height: 40)
                        Text("Sign In")
                            .font(.system(size: 28, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
                            .multilineTextAlignment(.center)          // text-align: center
                            .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                            .kerning(-0.3)                            // letter-spacing: -1%
                            .foregroundColor(.appTextPrimary)
                        
                        Spacer()
                        
                        // Invisible spacer to balance the logo centering
                        Color.clear
                            .frame(width: 48, height: 48)
                    }
                    .padding(.horizontal, 16)
                    
//                    // Hero Image with Gradient Overlay
//                    ZStack(alignment: .bottom) {
//                        Image("GetStartImage")
//                            .resizable()
//                            .scaledToFill()
//                            .frame(height: 300)
//                            .clipped()
//                        
//                        // Bottom gradient overlay
//                        LinearGradient(
//                            gradient: Gradient(colors: [
//                                Color.appCanvasPrimary,
//                                Color.appCanvasPrimary
//                            ]),
//                            startPoint: .bottom,
//                            endPoint: .top
//                        )
//                        .frame(height: 120)
//                        .blur(radius: 20)
//                    }
//                    
//                    .frame(height: 300)
//                    .ignoresSafeArea(edges: .top)
//                    .overlay(
//                        // Content within safe area
//                        VStack(spacing: 0) {
//                            // Title
//                            Text("Sign In")
//                                .font(.system(size: 28, weight: .bold, design: .rounded)) // font-family: Poppins; weight: 700 (Bold)
//                                .multilineTextAlignment(.center)          // text-align: center
//                                .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
//                                .kerning(-0.3)                            // letter-spacing: -1%
//                                .foregroundColor(.appTextPrimary)
//                            
//                            // Subtitle
//                            Text("Please Sign in to secure your data and for personalization")
//                                .font(.system(size: 16, weight: .regular, design: .rounded)) // font-family + weight/style
//                                .multilineTextAlignment(.center)             // text-align: center
//                                .foregroundColor(.appTextPrimary)
//                                .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
//                                .kerning(-0.048)                             // -0.3% of 16px = -0.048
//                                .fixedSize(horizontal: false, vertical: true)
//                            
//                            
//                        }
//                            .padding(.top, 35)
//                            
//                    )
                    // Email Label
                    HStack {
                        Text("Email Address")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom)
                    .padding(.top, 40)

                    // Email TextField
                    HStack(spacing: 12) {
                        Image("Monotone email")
//                        Image(systemName: "message.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.appTextPrimary)
                        
                        ZStack(alignment: .leading) {
                            // Placeholder
                            if email.isEmpty {
                                Text(verbatim: "you@example.com")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.appTextMuted)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            
                            // Actual TextField
                            TextField("", text: $email)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.themeWhite)
                                .padding(4) // same padding as placeholder
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
                            .stroke(Color.themeWhite, lineWidth: 2)
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)        
//                    Text("Continue as a Guest")
//                        .font(.system(size: 16, weight: .medium, design: .rounded)) // font-family + style
//                        .foregroundColor(Color.appTextPrimary)    // background color in design is likely text color
//                        .underline(true, color: Color.appTextPrimary) // underline as specified
//                        .kerning(0)                               // letter-spacing: 0%
//                        .lineSpacing(0)                            // line-height: 100%
//                        .padding(.top, 14)
//                        .onTapGesture {
//                            createInstallerUser()
//                        }                  
                    Spacer()
                    

                    // Primary Button
                    Button(action: {
                        hideKeyboard()
                        if email == "umer.asif@terralumen.co.uk" {
                            demoEmail = "umer.asif@terralumen.co.uk"
                            isEmailVerified = true
                        } else {
                            generateOTP()
                        }
                    }) {
                        HStack {
                            Spacer()

                            Text("Sign in")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.appTextInverse)
                            Image("Monotone arrow right")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(isEmailValid ? Color.appCanvasTertiary : Color.appOverlayTint)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(isEmailValid ? Color.appBrandPrimary : Color.themeWhite)
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.appBorderPrimary, lineWidth: 2) // ← 1-point border
                        )


                    }
                    .disabled(!isEmailValid)
                    .padding(.horizontal, 20)          
//                    HStack {
//                        // Left line
//                        Rectangle()
//                            .fill(Color.gray.opacity(0.4))
//                            .frame(height: 1)
//
//                        // Center "Or" text
//                        Text("Or")
//                            .font(.system(size: 16))
//                            .foregroundColor(.appTextMuted)
//                            .padding(.horizontal, 8)
//
//                        // Right line
//                        Rectangle()
//                            .fill(Color.gray.opacity(0.4))
//                            .frame(height: 1)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.horizontal, 16)
//                    .padding(.top, 18)
//                    
//                    
//                    Button(action: {
//                        // Your existing sign-in logic
//                        authManager.signInWithApple { success in
//                            if success {
//                                DispatchQueue.main.async {
//                                    isOTPVerified = true
//                                }
//                            }
//                        }
//                    }) {
//                        HStack(spacing: 8) {
//                            Image(systemName: "applelogo")
//                                .font(.system(size: 20, weight: .regular))
//                            
//                            Text("Continue with Apple")
//                                .font(.system(size: 16, weight: .semibold))
//                                .tracking(-0.3)
//                        }
//                        .foregroundColor(.themeWhite)
//                        .frame(maxWidth: .infinity, minHeight: 56)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 22)
//                                .stroke(Color.appBorderPrimary, lineWidth: 4) // ← 1-point border
//                        )
//                    }
//                    .background(Color.appSurfacePrimary)
//                    .cornerRadius(22)
//                    .frame(maxWidth: .infinity)              // same width you had
//                    .padding(.horizontal, 20)
//                    .padding(.top, 15)
//                    
//                    
//                    Button(action: {
//                        authManager.signInWithGoogle { success in
//                            if success {
//                                DispatchQueue.main.async {
//                                    isOTPVerified = true
//                                }
//                            }
//                        }
//                    }) {
//                        ZStack {
//                            HStack {
//                                Spacer()
//                                HStack(spacing: 8) {
//                                    Image("google")
//                                        .scaledToFit()
//                                    Text("Continue with Google")
//                                    
//                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
//                                        .foregroundColor(.appTextPrimary)
//                                }
//                                Spacer()
//                            }
//                            .padding(.horizontal, 20)
//                            .frame(height: 56)
//                            .frame(maxWidth: .infinity)
//                            .background(Color.appSurfacePrimary)
//                            .cornerRadius(22)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 22)
//                                    .stroke(Color.appBorderPrimary, lineWidth: 2) // ← 1-point border
//                            )
//                        }
//                    }
//                    .padding(.horizontal, 20)
//                    .padding(.top, 15)

                    
                }

            
            // Top Bar Overlay
//            VStack {
//
//                
//                Spacer()
//            }
        }
        
        .sheet(isPresented: $isShowingOTPView) {
            OTPVerificationView(email: email, enteredOTP: $enteredOTP, isOTPVerified: $isOTPVerified)
        }
        .fullScreenCover(isPresented: $isOTPVerified) {
            HomeView()
        }
        .fullScreenCover(isPresented: $isEmailVerified) {
            HomeView()
        }
        .fullScreenCover(isPresented: $showHomeView){
            HomeView()
        }
        .trackScreen(
            "LoginSkipView",
            metadata: [
                "ui_guide": "Email sign-in: enter your email, tap Sign in; you will get an OTP by email. Google and other options may appear depending on build. Back returns to the previous screen."
            ]
        )
    }
    
    // MARK: - Helper Functions
    private func hideKeyboard() {
        isEmailFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func generateOTP() {
        guard let url = URL(string:  APIConstants.sendOTP) else {
            print("Invalid URL")
            return
        }
        
        let parameters: [String: Any] = ["email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            print("Error converting parameters to JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = jsonResponse["success"] as? Bool, success {
                        DispatchQueue.main.async {
                            self.generatedOTP = jsonResponse["otp"] as? String ?? ""
                            self.isShowingOTPView = true
                            print("Generated OTP: \(self.generatedOTP)")
                        }
                    } else {
                        let errorMessage = jsonResponse["error_message"] as? String ?? "Unknown error"
                        print("Error: \(errorMessage)")
                    }
                }
            } catch {
                print("JSON decoding error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func createInstallerUser() {
        isLoading = true
        guard let url = URL(string: APIConstants.LoginInstallerUser) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [:]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { isLoading = false }

            if let error = error {
                print("API error:", error.localizedDescription)
                return
            }

            if let http = response as? HTTPURLResponse {
                print("HTTP Status:", http.statusCode)
                print("Content-Type:", http.value(forHTTPHeaderField: "Content-Type") ?? "-")
            }

            guard let data = data, !data.isEmpty else {
                print("No data received")
                return
            }

            // Try Codable first
            do {
                let decoded = try JSONDecoder().decode(InstallerUserResponse.self, from: data)
                print("Decoded success:", decoded.success)
                if decoded.success, let token = decoded.data?.token, !token.isEmpty {
                    if let username = decoded.data?.data, !username.isEmpty {
                        print("Guest username:", username)
                    }
                    AuthManager.shared.saveToken(token)
                    // Save role string from API message specifically for installer user
                    let roleMessage = decoded.message ?? "Installer User created"
                    AuthManager.shared.saveRole(roleMessage)
                    print("Token saved:", token , roleMessage)
                    DispatchQueue.main.async { showHomeView = true }
                    return
                }
            } catch {
                print("Codable decode error:", error.localizedDescription)
            }

            // Fallback diagnostics
            if let raw = String(data: data, encoding: .utf8) { print("Raw response string:\n", raw) }
            do {
                let any = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                print("Loose JSON object:", any)
            } catch {
                print("JSONSerialization fallback error:", error.localizedDescription)
            }
        }.resume()
    }
}

private struct InstallerUserResponse: Decodable {
    let success: Bool
    let message: String?
    let data: DataContainer?

    struct DataContainer: Decodable {
        // Backend sends { data: "guest", token: "..." }
        let data: String?
        let token: String?
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        LoginSkipView()
    }
}

import SwiftUI
import AuthenticationServices

struct AppleSignInButtonView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        @objc func didTapButton() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            return UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? UIWindow()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                if let tokenData = credential.identityToken,
                   let tokenString = String(data: tokenData, encoding: .utf8) {
                    print("✅ Apple Token:", tokenString)
                }
                print("✅ Apple Login Success:", credential.email ?? "No Email")
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("❌ Apple Sign-In Error:", error.localizedDescription)
        }
    }
}



import SwiftUI
import AuthenticationServices

//struct LoginSkipView: View {
//    @StateObject private var authManager = AppleAuthManager()
//
//    var body: some View {
//        VStack {
//            Spacer()
//
//            SignInWithAppleButton(.signIn, onRequest: { request in
//                // Request name and email if needed
//                request.requestedScopes = [.fullName, .email]
//            }, onCompletion: { result in
//                authManager.handleAppleSignIn(result: result)
//            })
//            .signInWithAppleButtonStyle(.themeBlack)
//            .frame(width: 280, height: 50)
//            .cornerRadius(10)
//            .padding()
//
//            Spacer()
//        }
//    }
//}

// MARK: - Auth Manager
final class AppleAuthManager: NSObject, ObservableObject {
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                
                if let tokenData = credential.identityToken,
                   let tokenString = String(data: tokenData, encoding: .utf8) {
                    print("✅ Apple Sign-In Success")
                    print("Token: \(tokenString)")
                } else {
                    print("⚠️ No identity token found.")
                }
                
                if let email = credential.email {
                    print("Email: \(email)")
                }
                
                if let name = credential.fullName?.givenName {
                    print("Name: \(name)")
                }
            }
            
        case .failure(let error):
            print("❌ Apple Sign-In failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Presentation Context Provider
extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? UIWindow()
    }
}
