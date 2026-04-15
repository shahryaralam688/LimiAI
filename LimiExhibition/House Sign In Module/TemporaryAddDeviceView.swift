import SwiftUI
import RealityKit

struct TemporaryAddDeviceView: View {
    @State private var email: String = ""
    @State private var isShowingOTPView: Bool = false
    @State private var generatedOTP: String = ""
    @State private var enteredOTP: String = ""
    @State private var isOTPVerified: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isEmailVerified: Bool = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    
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
            Color.appCanvasPrimary
                .ignoresSafeArea(.all)
            
            
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
                            Text("Let's personalize your Lifestyle with Limi")
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
                                    .foregroundColor(.appTextPlaceholder) // ← placeholder (suggestion) text color
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
                    .frame(width: 343)
                    .background(Color.appCanvasPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orbGlow4, lineWidth: 2)
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
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
                            Text("Sign in")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.appTextInverse)
                            
                            Spacer()
                            
                            Image("Monotone arrow right")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(isEmailValid ? Color.appCanvasTertiary : Color.appOverlayTint)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .frame(width: 343)
                        .background(isEmailValid ? Color.orbGlow4 : Color.orbGlow4)
                        .cornerRadius(22)
                    }
                    .disabled(!isEmailValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 28)
                    
                    Spacer(minLength: 100)
                }
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
    
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $isShowingOTPView) {
            OTPVerificationView(email: email, enteredOTP: $enteredOTP, isOTPVerified: $isOTPVerified)
        }
        .fullScreenCover(isPresented: $isOTPVerified) {
            HotelHomeView()
        }
        .fullScreenCover(isPresented: $isEmailVerified) {
            HotelHomeView()
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

//struct OTPVerificationView: View {
//    var email: String
//    @Environment(\.presentationMode) var presentationMode
//    
//    @State private var showAddDevices = false
//    @EnvironmentObject var authManager: AuthManager
//    
//    @Binding var enteredOTP: String
//    @Binding var isOTPVerified: Bool
//
//    @State private var errorMessage: String?
//    @State private var isLoading: Bool = false
//    
//    // Animation states
//    @State private var isAppearing: Bool = false
//    @State private var isVerifying: Bool = false
//    @State private var digitBoxes: [Bool] = Array(repeating: false, count: 6)
//    @State private var shakeError: Bool = false
//    
//    // For individual OTP digit focus
//    @FocusState private var focusedField: Int?
//    
//    var body: some View {
//        ZStack {
//            // Background gradient
//            LinearGradient(
//                gradient: Gradient(colors: [Color.charlestonGreen.opacity(0.7), Color.alabaster]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .edgesIgnoringSafeArea(.all)
//            
//            // Animated background shapes
//            ZStack {
//                Circle()
//                    .fill(Color.charlestonGreen.opacity(0.1))
//                    .frame(width: 200, height: 200)
//                    .offset(x: -150, y: -250)
//                    .scaleEffect(isAppearing ? 1.0 : 0.8)
//                
//                Circle()
//                    .fill(Color.charlestonGreen.opacity(0.1))
//                    .frame(width: 300, height: 300)
//                    .offset(x: 150, y: 350)
//                    .scaleEffect(isAppearing ? 1.0 : 0.8)
//            }
//            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAppearing)
//            
//            VStack(spacing: 30) {
//                // Header
//                VStack(spacing: 15) {
//                    Image(systemName: "lock.shield.fill")
//                        .font(.system(size: 60))
//                        .foregroundColor(.themeBlack)
//                        .padding()
//                        .background(
//                            Circle()
//                                .fill(Color.alabaster)
//                                .shadow(color: Color.charlestonGreen.opacity(0.1), radius: 10, x: 0, y: 5)
//                        )
//                        .scaleEffect(isAppearing ? 1.0 : 0.8)
//                        .opacity(isAppearing ? 1.0 : 0.5)
//                    
//                    Text("Verification Code")
//                        .font(.system(size: 28, weight: .bold, design: .rounded))
//                        .foregroundColor(.appTextPrimary)
//                        .opacity(isAppearing ? 1.0 : 0.0)
//                        .offset(y: isAppearing ? 0 : 20)
//                    
//                    Text("Please enter the 6-digit code sent to\n\(email)")
//                        .font(.system(size: 16, weight: .medium, design: .rounded))
//                        .foregroundColor(.alabaster.opacity(0.8))
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal)
//                        .opacity(isAppearing ? 1.0 : 0.0)
//                        .offset(y: isAppearing ? 0 : 20)
//                }
//                
//                // OTP Input Boxes
//                HStack(spacing: 12) {
//                    ForEach(0..<6, id: \.self) { index in
//                        OTPDigitBox(
//                            digit: index < enteredOTP.count ? String(Array(enteredOTP)[index]) : "",
//                            isActive: digitBoxes[index]
//                        )
//                        .scaleEffect(isAppearing ? 1.0 : 0.8)
//                        .opacity(isAppearing ? 1.0 : 0.0)
//                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: isAppearing)
//                    }
//                }
//                .padding(.horizontal)
//                .modifier(ShakeEffect(animatableData: shakeError ? 1 : 0))
//                .animation(.default, value: shakeError)
//                
//                // Hidden TextField for keyboard input
//                TextField("", text: $enteredOTP)
//                    .keyboardType(.numberPad)
//                    .frame(width: 1, height: 1)
//                    .opacity(0.1)
//                    .focused($focusedField, equals: 0)
//                    .onChange(of: enteredOTP) { oldValue, newValue in
//                        // Limit to 6 digits
//                        if newValue.count > 6 {
//                            enteredOTP = String(newValue.prefix(6))
//                        }
//                        
//                        // Animate the boxes as digits are entered
//                        for i in 0..<6 {
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.05)) {
//                                digitBoxes[i] = i < newValue.count
//                            }
//                        }
//                        
//                        // Clear error when typing
//                        if errorMessage != nil {
//                            errorMessage = nil
//                        }
//                    }
//                    .onAppear {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            focusedField = 0
//                        }
//                    }
//                
//                // Error message
//                if let errorMessage = errorMessage {
//                    Text(errorMessage)
//                        .font(.system(size: 14, weight: .medium, design: .rounded))
//                        .foregroundColor(.appTextPrimary)
//                        .padding(.horizontal)
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                }
//                
//                // Verify Button
//                Button(action: verifyOTP) {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 16)
//                            .fill(
//                                LinearGradient(
//                                    gradient: Gradient(colors: [Color.emerald, Color.emerald.opacity(0.8)]),
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                            .shadow(color: Color.charlestonGreen.opacity(0.5), radius: 10, x: 0, y: 5)
//                            .frame(height: 56)
//                        
//                        if isLoading {
//                            LottieLoadingView()
//                                .frame(width: 30, height: 30)
//                        } else {
//                            Text("Verify")
//                                .font(.system(size: 18, weight: .bold, design: .rounded))
//                                .foregroundColor(.appTextPrimary)
//                        }
//                    }
//                    .scaleEffect(isVerifying ? 0.95 : 1.0)
//                }
//                .disabled(enteredOTP.count < 6 || isLoading)
//                .opacity(enteredOTP.count < 6 ? 0.7 : 1.0)
//                .padding(.horizontal, 30)
//                .padding(.top, 10)
//                
//                // Resend code option
//                HStack(spacing: 5) {
//                    Text("Didn't receive the code?")
//                        .font(.system(size: 14, design: .rounded))
//                        .foregroundColor(.alabaster.opacity(0.8))
//                    
//                    Button(action: {
//                        // Call the generateOTP function again
//                        generateOTP()
//                    }) {
//                        Text("Resend")
//                            .font(.system(size: 14, weight: .bold, design: .rounded))
//                            .foregroundColor(.appTextPrimary)
//                    }
//                }
//                .padding(.top, 5)
//                .opacity(isAppearing ? 1.0 : 0.0)
//                .offset(y: isAppearing ? 0 : 20)
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 40)
//            .background(
//                RoundedRectangle(cornerRadius: 30)
//                    .fill(Color.themeBlack.opacity(0.95))
//                    .shadow(color: Color.alabaster.opacity(0.1), radius: 20, x: 0, y: 10)
//            )
//            .padding(.horizontal, 50)
//            .scaleEffect(isAppearing ? 1.0 : 0.9)
//            .opacity(isAppearing ? 1.0 : 0.0)
//            
//            // Navigation based on showAddDevices state
//            if isOTPVerified {
//                NavigationLink(value: showAddDevices ? "AddDeviceView" : "HomeView") {
//                    EmptyView()
//                }
//            }
//        }
//        .onAppear {
//            // Trigger animations when view appears
//            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
//                isAppearing = true
//            }
//            // Start background animation
//            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
//                isAppearing = true
//            }
//        }
//    }
//    
//    func verifyOTP() {
//        guard let url = URL(string: "https://dev.api.limitless-lighting.co.uk/client/verify_otp") else {
//            errorMessage = "Invalid URL"
//            return
//        }
//        
//        let parameters: [String: Any] = [
//            "email": email,
//            "otp": enteredOTP.trimmingCharacters(in: .whitespacesAndNewlines)
//        ]
//        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
//            errorMessage = "Error creating JSON"
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = jsonData
//        
//        withAnimation {
//            isLoading = true
//            isVerifying = true
//        }
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            DispatchQueue.main.async {
//                withAnimation {
//                    isLoading = false
//                    isVerifying = false
//                }
//                
//                if let error = error {
//                    errorMessage = "Request failed: \(error.localizedDescription)"
//                    triggerErrorAnimation()
//                    return
//                }
//                
//                guard let data = data else {
//                    errorMessage = "No data received"
//                    triggerErrorAnimation()
//                    return
//                }
//                
//                do {
//                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                        if let success = jsonResponse["success"] as? Bool, success {
//                            if let dataDict = jsonResponse["data"] as? [String: Any],
//                               let token = dataDict["token"] as? String {
//                                AuthManager.shared.saveToken(token)
//                                print(dataDict)
//                                print("Received Token: \(token)")
//                                
//                                // Checking devices
//                                if let userData = dataDict["data"] as? [String: Any],
//                                   let devices = userData["devices"] as? [[String: Any]] {
//                                    print("devices: \(devices)")
//                                    showAddDevices = !devices.isEmpty
//                                }
//                            } else {
//                                print("Token not found in response: \(jsonResponse)")
//                            }
//                            
//                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
//                                self.isOTPVerified = true
//                            }
//                            
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                self.presentationMode.wrappedValue.dismiss()
//                            }
//                        } else {
//                            errorMessage = jsonResponse["error_message"] as? String ?? "Invalid OTP"
//                            triggerErrorAnimation()
//                        }
//                    }
//                } catch {
//                    errorMessage = "Failed to parse response"
//                    triggerErrorAnimation()
//                }
//            }
//        }.resume()
//    }
//    
//    func generateOTP() {
//        guard let url = URL(string: "https://dev.api.limitless-lighting.co.uk/client/send_otp") else {
//            errorMessage = "Invalid URL"
//            return
//        }
//        
//        let parameters: [String: Any] = ["email": email]
//        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
//            errorMessage = "Error converting parameters to JSON"
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = jsonData
//
//        withAnimation {
//            isLoading = true
//        }
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            DispatchQueue.main.async {
//                withAnimation {
//                    isLoading = false
//                }
//                
//                if let error = error {
//                    errorMessage = "Request failed: \(error.localizedDescription)"
//                    return
//                }
//                
//                guard let data = data else {
//                    errorMessage = "No data received"
//                    return
//                }
//                
//                do {
//                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
//                        if let success = jsonResponse["success"] as? Bool, success {
//                            errorMessage = "OTP sent successfully!"
//                            // Clear the current OTP input
//                            enteredOTP = ""
//                            for i in 0..<6 {
//                                digitBoxes[i] = false
//                            }
//                        } else {
//                            let errorMsg = jsonResponse["error_message"] as? String ?? "Unknown error"
//                            errorMessage = "Error: \(errorMsg)"
//                        }
//                    }
//                } catch {
//                    errorMessage = "JSON decoding error"
//                }
//            }
//        }.resume()
//    }
//    
//    func triggerErrorAnimation() {
//        withAnimation(.default) {
//            shakeError = true
//        }
//        
//        // Reset the shake after animation completes
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            withAnimation(.default) {
//                shakeError = false
//            }
//        }
//    }
//}

//// OTP Digit Box Component
//struct OTPDigitBox: View {
//    let digit: String
//    let isActive: Bool
//    
//    var body: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(isActive ? Color.charlestonGreen : Color.charlestonGreen.opacity(0.3), lineWidth: 2)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(Color.alabaster.opacity(0.8))
//                )
//                .frame(width: 45, height: 55)
//                .shadow(color: isActive ? Color.charlestonGreen.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 2)
//            
//            if !digit.isEmpty {
//                Text(digit)
//                    .font(.system(size: 24, weight: .bold, design: .rounded))
//                    .foregroundColor(.charlestonGreen)
//                    .transition(.scale.combined(with: .opacity))
//            }
//        }
//        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
//        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digit)
//    }
//}

//// Custom Loading Animation
//struct LottieLoadingView: View {
//    @State private var isAnimating = false
//    
//    var body: some View {
//        ZStack {
//            ForEach(0..<3) { index in
//                Circle()
//                    .fill(Color.alabaster)
//                    .frame(width: 8, height: 8)
//                    .offset(y: isAnimating ? -10 : 0)
//                    .opacity(isAnimating ? 1.0 : 0.5)
//                    .animation(
//                        Animation.easeInOut(duration: 0.5)
//                            .repeatForever(autoreverses: true)
//                            .delay(0.2 * Double(index)),
//                        value: isAnimating
//                    )
//            }
//            .offset(x: -20)
//            
//            ForEach(0..<3) { index in
//                Circle()
//                    .fill(Color.alabaster)
//                    .frame(width: 8, height: 8)
//                    .offset(y: isAnimating ? -10 : 0)
//                    .opacity(isAnimating ? 1.0 : 0.5)
//                    .animation(
//                        Animation.easeInOut(duration: 0.5)
//                            .repeatForever(autoreverses: true)
//                            .delay(0.2 * Double(index) + 0.3),
//                        value: isAnimating
//                    )
//            }
//            .offset(x: 20)
//        }
//        .onAppear {
//            isAnimating = true
//        }
//    }
//}

// Shake Effect Modifier
//struct ShakeEffect: GeometryEffect {
//    var animatableData: CGFloat
//    
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 5), y: 0))
//    }
//}

import SwiftUI

//struct KeyboardResponsiveModifier: ViewModifier {
//    @State private var keyboardHeight: CGFloat = 0
//
//    func body(content: Content) -> some View {
//        content
//            .padding(.bottom, keyboardHeight)
//            .onAppear {
//                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
//                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
//                        keyboardHeight = keyboardFrame.height - 20
//                    }
//                }
//                
//                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
//                    keyboardHeight = 0
//                }
//            }
//            .onTapGesture {
//                hideKeyboard()
//            }
//    }
//    
//    private func hideKeyboard() {
//        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//    }
//}

//extension View {
//    func keyboardResponsive() -> some View {
//        self.modifier(KeyboardResponsiveModifier())
//    }
//}

struct TemporaryAddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        TemporaryAddDeviceView()
    }
}

