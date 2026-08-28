import SwiftUI

struct LoginSkipView: View {
    @State private var email: String = ""
    @State private var isShowingOTPView: Bool = false
    @State private var enteredOTP: String = ""
    @State private var isOTPVerified: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var isEmailVerified: Bool = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @State private var showHomeView: Bool = false
    @FocusState private var isEmailFieldFocused: Bool
    @State private var isLoading = false
    @State private var isSendingOTP = false
    @State private var otpErrorMessage: String?
    @State private var otpSentConfirmationMessage: String?
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
                        .font(LimiTypography.largeTitle)
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
                        .font(LimiTypography.title3)
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
                                .font(LimiTypography.body)
                                .foregroundColor(.appTextMuted)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }

                        TextField("", text: $email)
                            .font(LimiTypography.body)
                            .foregroundColor(.appTextPrimary)
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

                        if isSendingOTP {
                            ProgressView()
                                .tint(.appTextInverse)
                        } else {
                            Text("Sign in")
                                .font(LimiTypography.button)
                                .foregroundColor(.appTextInverse)
                            Image("Monotone arrow right")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(isEmailValid ? Color.appCanvasTertiary : Color.appOverlayTint)
                        }

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
                .disabled(!isEmailValid || isSendingOTP)
                .padding(.horizontal, 20)

                if let otpErrorMessage {
                    Text(otpErrorMessage)
                        .font(LimiTypography.footnote)
                        .foregroundColor(.appDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $isShowingOTPView) {
            OTPVerificationView(
                email: LoginOTPResponseParser.normalizedEmail(email),
                confirmationMessage: otpSentConfirmationMessage,
                enteredOTP: $enteredOTP,
                isOTPVerified: $isOTPVerified
            )
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
        email = LoginOTPResponseParser.normalizedEmail(email)
        otpErrorMessage = nil
        otpSentConfirmationMessage = nil
        isSendingOTP = true

        DefaultLoginOTPRequester().requestOTP(email: email) { result in
            DispatchQueue.main.async {
                self.isSendingOTP = false

                switch result {
                case .success(let confirmationMessage):
                    self.otpSentConfirmationMessage = confirmationMessage
                    self.isShowingOTPView = true
                case .failure(let error):
                    self.otpErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createInstallerUser() {
        isLoading = true
        LimiHTTPClient.postJSON(
            urlString: APIConstants.LoginInstallerUser,
            body: [:],
            auth: .none
        ) { data, response, error in
            DispatchQueue.main.async { isLoading = false }

            if let error = error {
                return
            }

            if let http = response {
            }

            guard let data = data, !data.isEmpty else {
                return
            }

            do {
                let decoded = try JSONDecoder().decode(InstallerUserResponse.self, from: data)
                if decoded.success, let token = decoded.data?.token, !token.isEmpty {
                    if let username = decoded.data?.data, !username.isEmpty {
                    }
                    AuthManager.shared.saveToken(token)
                    let roleMessage = decoded.message ?? "Installer User created"
                    AuthManager.shared.saveRole(roleMessage)
                    DispatchQueue.main.async { showHomeView = true }
                    return
                }
            } catch { /* ignored */ }

            if let raw = String(data: data, encoding: .utf8) { }
            do {
                let any = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            } catch { /* ignored */ }
        }
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
