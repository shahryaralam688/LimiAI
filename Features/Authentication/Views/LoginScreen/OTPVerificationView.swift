import SwiftUI

struct OTPVerificationView: View {
    var email: String
    var confirmationMessage: String?
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = OTPVerificationViewModel()

    @Binding var enteredOTP: String
    @Binding var isOTPVerified: Bool

    @State private var isAppearing: Bool = false
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationStack {
        ZStack {
            DeepSpaceBackground(showParticles: false)

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
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield.fill")
                        .font(LimiTypography.title2)
                        .foregroundColor(.appTextPrimary)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.appSurfacePrimary)
                                .shadow(color: Color.appCanvasPrimary.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .scaleEffect(isAppearing ? 1.0 : 0.8)
                        .opacity(isAppearing ? 1.0 : 0.5)

                    Text("Verification Code")
                        .font(LimiTypography.largeTitle)
                        .foregroundColor(.appTextPrimary)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .offset(y: isAppearing ? 0 : 20)

                    Text("We sent a 6-digit code to\n\(email)")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .offset(y: isAppearing ? 0 : 20)

                    if let confirmationMessage {
                        Text(confirmationMessage)
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPDigitBox(
                            digit: index < enteredOTP.count ? String(Array(enteredOTP)[index]) : "",
                            isActive: viewModel.digitBoxes[index]
                        )
                        .scaleEffect(isAppearing ? 1.0 : 0.8)
                        .opacity(isAppearing ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: isAppearing)
                    }
                }
                .padding(.horizontal)
                .modifier(ShakeEffect(animatableData: viewModel.shakeError ? 1 : 0))
                .animation(LimiMotion.quick, value: viewModel.shakeError)

                TextField("", text: $enteredOTP)
                    .keyboardType(.numberPad)
                    .frame(width: 1, height: 1)
                    .opacity(0.1)
                    .focused($focusedField, equals: 0)
                    .onChange(of: enteredOTP) { _, newValue in
                        let sanitized = viewModel.handleOTPChanged(newValue)
                        if sanitized != newValue {
                            enteredOTP = sanitized
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusedField = 0
                        }
                    }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(LimiTypography.callout)
                        .foregroundColor(.appDanger)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button(action: verifyOTP) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appBrandPrimary)
                            .shadow(color: Color.appCanvasPrimary.opacity(0.5), radius: 10, x: 0, y: 5)
                            .frame(height: 56)

                        if viewModel.isLoading {
                            LottieLoadingView()
                                .frame(width: 30, height: 30)
                        } else {
                            Text("Verify")
                                .font(LimiTypography.button)
                                .foregroundColor(.appTextPrimary)
                        }
                    }
                    .scaleEffect(viewModel.isVerifying ? 0.95 : 1.0)
                }
                .disabled(enteredOTP.count < 6 || viewModel.isLoading)
                .opacity(enteredOTP.count < 6 ? 0.7 : 1.0)
                .padding(.horizontal, 30)
                .padding(.top, 10)

                HStack(spacing: 5) {
                    Text("Didn't receive the code?")
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextSecondary)

                    Button(action: generateOTP) {
                        Text("Resend")
                            .font(LimiTypography.callout)
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
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAppearing = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                isAppearing = true
            }
        }
        .limiModalNavigationBar(title: "Verification", onClose: { dismiss() })
        }
        .limiModalSheetStyle()
        .trackScreen(
            "OTPVerificationView",
            metadata: [
                "ui_guide": "Enter the six-digit code from your email, then Verify. Use Resend if needed. Never share the OTP in voice chat."
            ]
        )
    }

    func verifyOTP() {
        viewModel.verifyOTP(email: email, enteredOTP: enteredOTP) {
            self.isOTPVerified = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismiss()
            }
        }
    }

    func generateOTP() {
        viewModel.resendOTP(email: email) {
            enteredOTP = ""
        }
    }
}
