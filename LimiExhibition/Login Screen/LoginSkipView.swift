import SwiftUI

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
    @FocusState private var isEmailFieldFocused: Bool
    @State private var isLoading = false
    @StateObject private var authManager = GoogleAuthManager()

    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color.appCanvasPrimary
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Text("Sign In")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .kerning(-0.3)
                        .foregroundColor(.appTextPrimary)

                    Spacer()

                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Email Address")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom)
                .padding(.top, 40)

                HStack(spacing: 12) {
                    Image("Monotone email")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.appTextPrimary)

                    ZStack(alignment: .leading) {
                        if email.isEmpty {
                            Text(verbatim: "you@example.com")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.appTextMuted)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }

                        TextField("", text: $email)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.themeWhite)
                            .padding(4)
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

                Spacer()

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
                            .stroke(Color.appBorderPrimary, lineWidth: 2)
                    )
                }
                .disabled(!isEmailValid)
                .padding(.horizontal, 20)
            }
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
        .fullScreenCover(isPresented: $showHomeView) {
            HomeView()
        }
        .limiModalNavigationBar(title: "Sign In", onClose: { dismiss() })
        }
        .trackScreen(
            "LoginSkipView",
            metadata: [
                "ui_guide": "Email sign-in: enter your email, tap Sign in; you will get an OTP by email. Google and other options may appear depending on build. Back returns to the previous screen."
            ]
        )
    }

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

        URLSession.shared.dataTask(with: request) { data, _, error in
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

            do {
                let decoded = try JSONDecoder().decode(InstallerUserResponse.self, from: data)
                print("Decoded success:", decoded.success)
                if decoded.success, let token = decoded.data?.token, !token.isEmpty {
                    if let username = decoded.data?.data, !username.isEmpty {
                        print("Guest username:", username)
                    }
                    AuthManager.shared.saveToken(token)
                    let roleMessage = decoded.message ?? "Installer User created"
                    AuthManager.shared.saveRole(roleMessage)
                    print("Token saved:", token, roleMessage)
                    DispatchQueue.main.async { showHomeView = true }
                    return
                }
            } catch {
                print("Codable decode error:", error.localizedDescription)
            }

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
        let data: String?
        let token: String?
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        LoginSkipView()
    }
}
