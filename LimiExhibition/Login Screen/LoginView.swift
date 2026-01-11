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
    
    // Email validation
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var body: some View {
        ZStack {
            // Background color
            Color(hex: "#111214")
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
                                Color(hex: "#111214"),
                                Color(hex: "#111214")
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
                                .font(.custom("Poppins-Bold", size: 30)) // font-family: Poppins; weight: 700 (Bold)
                                .multilineTextAlignment(.center)          // text-align: center
                                .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                                .kerning(-0.3)                            // letter-spacing: -1%
                                .foregroundColor(Color.alabaster)
                            
                            // Subtitle
                            Text("Please Sign in to secure your data and for personalization")
                                .font(.custom("Poppins-Regular", size: 16)) // font-family + weight/style
                                .multilineTextAlignment(.center)             // text-align: center
                                .foregroundColor(.alabaster)
                                .lineSpacing(9.6)                            // 160% of 16px = 25.6 → 25.6 - 16 = ~9.6
                                .kerning(-0.048)                             // -0.3% of 16px = -0.048
                                .fixedSize(horizontal: false, vertical: true)
                            
                            
                        }
                    )
                    // Email Label
                    HStack {
                        Text("Email Address")
                            .font(.custom("Poppins-Bold", size: 20))
                            .foregroundColor(Color.alabaster)
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
                            .foregroundColor(Color.alabaster)
                        
                        ZStack(alignment: .leading) {
                            if email.isEmpty {
                                Text("you@example.com")
                                    .font(.custom("Poppins-Regular", size: 16))
                                    .foregroundColor(.alabaster) // ← placeholder (suggestion) text color
                                    
                            }
                            TextField("", text: $email)
                                .font(.custom("Poppins-Regular", size: 16))
                                .foregroundColor(Color.alabaster)
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
                    .frame(width: 343)
                    .background(Color(hex: "#111214"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.emerald, lineWidth: 2)
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
                                        .tint(Color.charlestonGreen)   // iOS 15+
                                        .scaleEffect(1.0)
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Sign in")
                                            .font(.custom("Poppins-SemiBold", size: 18))
                                            .foregroundColor(Color.charlestonGreen)
                                        Image("Monotone arrow right")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(Color(hex: "#0B0E0C"))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .frame(width: 343)
                            .background(Color.emerald)
                            .cornerRadius(22)
                            .animation(.default, value: isSigningIn)
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
                    .signInWithAppleButtonStyle(.white) // or .white
                    .frame(height: 56)
                    .frame(width: 343)
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
                                    
                                        .font(.custom("Poppins-SemiBold", size: 18))
                                        .foregroundColor(Color.alabaster)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .frame(width: 343)
                            .background(Color(hex: "#5F5F5F"))
                            .cornerRadius(22)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)

                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Top Bar Overlay
            VStack {
                HStack {
                    // Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image("Solid arrow right sm")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "#24262B"))
                            .cornerRadius(16)
                    }
                    
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
    @Environment(\.presentationMode) var presentationMode
    
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
                gradient: Gradient(colors: [Color.charlestonGreen.opacity(0.7), Color.alabaster]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // Animated background shapes
            ZStack {
                Circle()
                    .fill(Color.charlestonGreen.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -150, y: -250)
                    .scaleEffect(isAppearing ? 1.0 : 0.8)
                
                Circle()
                    .fill(Color.charlestonGreen.opacity(0.1))
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
                        .foregroundColor(.black)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.alabaster)
                                .shadow(color: Color.charlestonGreen.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .scaleEffect(isAppearing ? 1.0 : 0.8)
                        .opacity(isAppearing ? 1.0 : 0.5)
                    
                    Text("Verification Code")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.alabaster)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .offset(y: isAppearing ? 0 : 20)
                    
                    Text("Please enter the 6-digit code sent to\n\(email)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.alabaster.opacity(0.8))
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
                .animation(.default, value: shakeError)
                
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
                        .foregroundColor(.alabaster)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.emerald, Color.emerald.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.charlestonGreen.opacity(0.5), radius: 10, x: 0, y: 5)
                            .frame(height: 56)
                        
                        if isLoading {
                            LottieLoadingView()
                                .frame(width: 30, height: 30)
                        } else {
                            Text("Verify")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.alabaster)
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
                        .foregroundColor(.alabaster.opacity(0.8))
                    
                    Button(action: {
                        // Call the generateOTP function again
                        generateOTP()
                    }) {
                        Text("Resend")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.alabaster)
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
                    .fill(Color.black.opacity(0.95))
                    .shadow(color: Color.alabaster.opacity(0.1), radius: 20, x: 0, y: 10)
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
                                self.presentationMode.wrappedValue.dismiss()
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
                .stroke(isActive ? Color.charlestonGreen : Color.charlestonGreen.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.alabaster.opacity(0.8))
                )
                .frame(width: 45, height: 55)
                .shadow(color: isActive ? Color.charlestonGreen.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
            
            if !digit.isEmpty {
                Text(digit)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.charlestonGreen)
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
                    .fill(Color.alabaster)
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
                    .fill(Color.alabaster)
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
            Color(hex: "#111214")
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
                VStack(spacing: 0) {
                    HStack {
                        // Back Button
                        Button(action: {
                            dismiss()
                        }) {
                            Image("Solid arrow right sm")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Color(hex: "#24262B"))
                                .cornerRadius(16)
                        }
                        
                        Spacer()
                        
    //                    // Logo
    //                    Image("LoginViewLogo")
    //                        .resizable()
    //                        .aspectRatio(contentMode: .fit)
    //                        .frame(width: 200, height: 40)
                        Text("Sign In")
                            .font(.custom("Poppins-Bold", size: 30)) // font-family: Poppins; weight: 700 (Bold)
                            .multilineTextAlignment(.center)          // text-align: center
                            .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
                            .kerning(-0.3)                            // letter-spacing: -1%
                            .foregroundColor(Color.alabaster)
                        
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
//                                Color(hex: "#111214"),
//                                Color(hex: "#111214")
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
//                                .font(.custom("Poppins-Bold", size: 30)) // font-family: Poppins; weight: 700 (Bold)
//                                .multilineTextAlignment(.center)          // text-align: center
//                                .lineSpacing(8)                           // 38px line height - 30px font size = 8px spacing
//                                .kerning(-0.3)                            // letter-spacing: -1%
//                                .foregroundColor(Color.alabaster)
//                            
//                            // Subtitle
//                            Text("Please Sign in to secure your data and for personalization")
//                                .font(.custom("Poppins-Regular", size: 16)) // font-family + weight/style
//                                .multilineTextAlignment(.center)             // text-align: center
//                                .foregroundColor(.alabaster)
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
                            .font(.custom("Poppins-Bold", size: 20))
                            .foregroundColor(Color.alabaster)
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
                            .foregroundColor(Color.alabaster)
                        
                        ZStack(alignment: .leading) {
                            // Placeholder
                            if email.isEmpty {
                                Text(verbatim: "you@example.com")
                                    .font(.custom("Poppins-Regular", size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            
                            // Actual TextField
                            TextField("", text: $email)
                                .font(.custom("Poppins-Regular", size: 16))
                                .foregroundColor(.white)
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
                    .frame(width: 343)
                    .background(Color(hex: "#111214"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)        
//                    Text("Continue as a Guest")
//                        .font(.custom("Poppins-Medium", size: 16)) // font-family + style
//                        .foregroundColor(Color(hex: "#F2EBE3"))    // background color in design is likely text color
//                        .underline(true, color: Color(hex: "#F2EBE3")) // underline as specified
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
                                .font(.custom("Poppins-SemiBold", size: 18))
                                .foregroundColor(isEmailValid ? Color.charlestonGreen : Color.charlestonGreen)
                            Image("Monotone arrow right")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(isEmailValid ? Color(hex: "#0B0E0C") : Color(hex: "#00000066"))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .frame(width: 343)
                        .background(isEmailValid ? Color.emerald : Color.white)
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color(hex: "#5F5F5F"), lineWidth: 2) // ← 1-point border
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
//                            .foregroundColor(.gray)
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
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, minHeight: 56)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 22)
//                                .stroke(Color(hex: "#5F5F5F"), lineWidth: 4) // ← 1-point border
//                        )
//                    }
//                    .background(Color(hex: "#24262B"))
//                    .cornerRadius(22)
//                    .frame(width: 343)              // same width you had
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
//                                        .font(.custom("Poppins-SemiBold", size: 18))
//                                        .foregroundColor(Color.alabaster)
//                                }
//                                Spacer()
//                            }
//                            .padding(.horizontal, 20)
//                            .frame(height: 56)
//                            .frame(width: 343)
//                            .background(Color(hex: "#24262B"))
//                            .cornerRadius(22)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 22)
//                                    .stroke(Color(hex: "#5F5F5F"), lineWidth: 2) // ← 1-point border
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
//            .signInWithAppleButtonStyle(.black)
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
