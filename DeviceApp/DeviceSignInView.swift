//
//  DeviceSignInView.swift
//  LIMI AI Device
//
//  Soft UI sign-in: Email (OTP), Google, or Guest — same backend flows
//  as the main app (SignInViewModel / LoginViewModel / OTP verify).
//  Extra UX / friendly fallbacks are presentation-only.
//

import SwiftUI

struct DeviceSignInView: View {
    @StateObject private var viewModel = SignInViewModel(
        managesPostLoginNavigation: true,
        requiresPersonalizeGate: false
    )
    @State private var showEmailLogin = false
    @State private var loadingAction: DeviceSignInMessaging.LoadingAction?
    @State private var bannerMessage: String?
    @State private var bannerKind: DeviceSignInMessageKind = .error

    var body: some View {
        NavigationStack {
            DeviceNeumorphicScreen {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 14) {
                        Image("IconWordmark_White")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 18)
                            .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.lg, fill: HomeUI1Color.surface)

                        Text("Control your LIMI devices")
                            .font(HomeUI1Type.regular(15))
                            .foregroundStyle(HomeUI1Color.textSecondary)

                        Text("Sign in to manage your Limi devices")
                            .font(HomeUI1Type.caption(12))
                            .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.85))
                    }

                    Spacer(minLength: 24)

                    if let bannerMessage {
                        DeviceNeumorphicStatusBanner(
                            message: bannerMessage,
                            kind: bannerKind,
                            retryTitle: bannerKind == .error ? "Try again" : nil,
                            onRetry: bannerKind == .error ? { clearBanner() } : nil,
                            onDismiss: { clearBanner() }
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    VStack(spacing: 14) {
                        DeviceNeumorphicButton(
                            title: "Continue with Email",
                            systemImage: "envelope.fill",
                            kind: .accent,
                            isEnabled: !viewModel.isLoading
                        ) {
                            clearBanner()
                            showEmailLogin = true
                        }

                        DeviceNeumorphicButton(
                            title: "Continue with Google",
                            systemImage: "g.circle.fill",
                            kind: .primary,
                            isLoading: loadingAction == .google,
                            isEnabled: !viewModel.isLoading
                        ) {
                            clearBanner()
                            loadingAction = .google
                            viewModel.signInWithGoogle()
                        }

                        DeviceNeumorphicButton(
                            title: "Continue as a Guest",
                            systemImage: "person.fill",
                            kind: .ghost,
                            isLoading: loadingAction == .guest,
                            isEnabled: !viewModel.isLoading
                        ) {
                            clearBanner()
                            loadingAction = .guest
                            viewModel.continueAsGuest()
                        }

                        Text("Guest can browse. Sign in later to save and control your devices.")
                            .font(HomeUI1Type.caption(11))
                            .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }

                if viewModel.isLoading, let loadingAction {
                    DeviceNeumorphicLoadingOverlay(
                        title: DeviceSignInMessaging.loadingTitle(for: loadingAction),
                        subtitle: DeviceSignInMessaging.loadingSubtitle(for: loadingAction)
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(HomeUI1Motion.soft, value: bannerMessage)
            .animation(HomeUI1Motion.soft, value: viewModel.isLoading)
            .sheet(isPresented: $showEmailLogin) {
                DeviceEmailLoginView()
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if !loading {
                    self.loadingAction = nil
                }
            }
            .onChange(of: viewModel.signInErrorMessage) { _, raw in
                guard let raw else { return }
                let context: DeviceSignInMessaging.Context =
                    loadingAction == .guest ? .guest : .google
                presentBanner(
                    DeviceSignInMessaging.friendly(raw, context: context),
                    kind: .error
                )
                DeviceAppGuidance.warningNotification()
                viewModel.signInErrorMessage = nil
            }
            .onChange(of: viewModel.showHomeView) { _, showHome in
                // Device app has no Personalize step — a saved token means we're in.
                if showHome, AuthManager.shared.getToken() != nil {
                    DeviceAppGuidance.successNotification()
                    AuthManager.shared.isAuthenticated = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func clearBanner() {
        withAnimation(HomeUI1Motion.soft) {
            bannerMessage = nil
        }
    }

    private func presentBanner(_ message: String, kind: DeviceSignInMessageKind) {
        withAnimation(HomeUI1Motion.soft) {
            bannerKind = kind
            bannerMessage = message
        }
    }
}

// MARK: - Email + OTP (Soft UI)

private struct DeviceEmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var emailFocused: Bool
    @State private var attemptedSend = false
    @State private var bannerMessage: String?
    @State private var bannerKind: DeviceSignInMessageKind = .error

    private var trimmedEmail: String {
        viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailHint: String? {
        DeviceSignInMessaging.emailHint(
            isEmpty: trimmedEmail.isEmpty,
            isValid: viewModel.isEmailValid
        )
    }

    var body: some View {
        NavigationStack {
            DeviceNeumorphicScreen {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HomeUI1PageTitle(
                            title: "Sign In",
                            subtitle: "We’ll email a one-time code — no password needed"
                        )
                        .padding(.top, 8)

                        if let bannerMessage {
                            DeviceNeumorphicStatusBanner(
                                message: bannerMessage,
                                kind: bannerKind,
                                retryTitle: bannerKind == .error ? "Try again" : nil,
                                onRetry: bannerKind == .error ? {
                                    clearBanner()
                                    emailFocused = true
                                } : nil,
                                onDismiss: { clearBanner() }
                            )
                            .transition(.opacity)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Email")
                                .font(HomeUI1Type.caption(12))
                                .foregroundStyle(HomeUI1Color.textSecondary)

                            DeviceNeumorphicTextField(
                                placeholder: "you@example.com",
                                text: $viewModel.email,
                                systemImage: "envelope.fill",
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress,
                                submitLabel: .send
                            ) {
                                attemptSendCode()
                            }
                            .focused($emailFocused)
                            .onChange(of: viewModel.email) { _, _ in
                                if bannerKind == .error {
                                    clearBanner()
                                }
                            }

                            if let emailHint, attemptedSend || !trimmedEmail.isEmpty {
                                Text(emailHint)
                                    .font(HomeUI1Type.caption(12))
                                    .foregroundStyle(
                                        attemptedSend && !viewModel.isEmailValid
                                            ? HomeUI1Color.accentRed
                                            : HomeUI1Color.textSecondary
                                    )
                            }
                        }
                        .padding(18)
                        .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)

                        DeviceNeumorphicButton(
                            title: viewModel.isSigningIn ? "Sending code…" : "Send Code",
                            systemImage: "paperplane.fill",
                            kind: .accent,
                            isLoading: viewModel.isSigningIn,
                            isEnabled: !viewModel.isSigningIn
                        ) {
                            attemptSendCode()
                        }

                        Text("Check inbox and spam. The code usually arrives within a minute.")
                            .font(HomeUI1Type.caption(12))
                            .foregroundStyle(HomeUI1Color.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }

                if viewModel.isSigningIn {
                    DeviceNeumorphicLoadingOverlay(
                        title: DeviceSignInMessaging.loadingTitle(for: .sendCode),
                        subtitle: DeviceSignInMessaging.loadingSubtitle(for: .sendCode)
                    )
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .deviceNeumorphicNavigationChrome()
            .animation(HomeUI1Motion.soft, value: bannerMessage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(HomeUI1Color.accentGreen)
                        .disabled(viewModel.isSigningIn)
                }
            }
            .sheet(isPresented: $viewModel.isShowingOTPView) {
                NavigationStack {
                    DeviceOTPView(
                        email: viewModel.email,
                        confirmationMessage: viewModel.otpSentConfirmationMessage
                    ) {
                        viewModel.isShowingOTPView = false
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.otpRequestErrorMessage) { _, raw in
                guard let raw else { return }
                presentBanner(
                    DeviceSignInMessaging.friendly(raw, context: .sendCode),
                    kind: .error
                )
                DeviceAppGuidance.warningNotification()
                viewModel.otpRequestErrorMessage = nil
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    emailFocused = true
                }
            }
        }
    }

    private func attemptSendCode() {
        attemptedSend = true
        clearBanner()
        guard viewModel.isEmailValid else {
            presentBanner("Please enter a valid email address.", kind: .error)
            DeviceAppGuidance.warningNotification()
            emailFocused = true
            return
        }
        viewModel.requestOTP()
    }

    private func clearBanner() {
        withAnimation(HomeUI1Motion.soft) {
            bannerMessage = nil
        }
    }

    private func presentBanner(_ message: String, kind: DeviceSignInMessageKind) {
        withAnimation(HomeUI1Motion.soft) {
            bannerKind = kind
            bannerMessage = message
        }
    }
}

private struct DeviceOTPView: View {
    let email: String
    var confirmationMessage: String?
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OTPVerificationViewModel()
    @State private var code = ""
    @FocusState private var codeFieldFocused: Bool
    @State private var bannerMessage: String?
    @State private var bannerKind: DeviceSignInMessageKind = .info
    @State private var resendSecondsRemaining = 0
    @State private var resendTickTask: Task<Void, Never>?
    @State private var loadingAction: DeviceSignInMessaging.LoadingAction?

    private var canResend: Bool {
        !viewModel.isLoading && resendSecondsRemaining == 0
    }

    var body: some View {
        DeviceNeumorphicScreen {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Enter Code",
                        subtitle: "Sent to \(email)"
                    )
                    .padding(.top, 8)

                    if let bannerMessage {
                        DeviceNeumorphicStatusBanner(
                            message: bannerMessage,
                            kind: bannerKind,
                            retryTitle: bannerKind == .error ? "Edit code" : nil,
                            onRetry: bannerKind == .error ? {
                                clearBanner()
                                codeFieldFocused = true
                            } : nil,
                            onDismiss: { clearBanner() }
                        )
                        .transition(.opacity)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("6-digit code")
                                .font(HomeUI1Type.caption(12))
                                .foregroundStyle(HomeUI1Color.textSecondary)
                            Spacer()
                            Text("\(code.count)/6")
                                .font(HomeUI1Type.caption(11))
                                .foregroundStyle(HomeUI1Color.textSecondary)
                        }

                        DeviceNeumorphicTextField(
                            placeholder: "••••••",
                            text: $code,
                            systemImage: "lock.fill",
                            keyboardType: .numberPad,
                            textContentType: .oneTimeCode
                        )
                        .focused($codeFieldFocused)
                        .offset(x: viewModel.shakeError ? -8 : 0)
                        .animation(
                            viewModel.shakeError
                                ? .default.repeatCount(2, autoreverses: true)
                                : .default,
                            value: viewModel.shakeError
                        )
                        .onChange(of: code) { _, newValue in
                            code = viewModel.handleOTPChanged(newValue)
                            if bannerKind == .error {
                                clearBanner()
                            }
                            // Auto-verify when user finishes typing — same verifyOTP path.
                            if code.count == 6, !viewModel.isLoading {
                                submitCode()
                            }
                        }
                    }
                    .padding(18)
                    .homeUI1Elevation(.three, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)

                    DeviceNeumorphicButton(
                        title: viewModel.isVerifying ? "Verifying…" : "Verify",
                        systemImage: "checkmark.circle.fill",
                        kind: .accent,
                        isLoading: viewModel.isVerifying,
                        isEnabled: code.count == 6 && !viewModel.isLoading
                    ) {
                        submitCode()
                    }

                    DeviceNeumorphicButton(
                        title: resendButtonTitle,
                        systemImage: "arrow.clockwise",
                        kind: .secondary,
                        isLoading: loadingAction == .resend && viewModel.isLoading,
                        isEnabled: canResend
                    ) {
                        resendCode()
                    }

                    Text("Didn’t get it? Check spam, or wait for the timer and resend.")
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            if viewModel.isLoading, let loadingAction {
                DeviceNeumorphicLoadingOverlay(
                    title: DeviceSignInMessaging.loadingTitle(for: loadingAction),
                    subtitle: DeviceSignInMessaging.loadingSubtitle(for: loadingAction)
                )
            }
        }
        .navigationTitle("Enter Code")
        .navigationBarTitleDisplayMode(.inline)
        .deviceNeumorphicNavigationChrome()
        .animation(HomeUI1Motion.soft, value: bannerMessage)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
                    .foregroundStyle(HomeUI1Color.accentGreen)
                    .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            codeFieldFocused = true
            startResendCooldown(seconds: 30)
            if let confirmationMessage {
                presentBanner(
                    DeviceSignInMessaging.friendly(confirmationMessage, context: .sendCode),
                    kind: .success
                )
            }
        }
        .onDisappear {
            resendTickTask?.cancel()
            resendTickTask = nil
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading {
                loadingAction = nil
            }
        }
        .onChange(of: viewModel.errorMessage) { _, raw in
            guard let raw else { return }
            let kind = DeviceSignInMessaging.kind(for: raw)
            let context: DeviceSignInMessaging.Context =
                kind == .success ? .resend : .verify
            presentBanner(
                DeviceSignInMessaging.friendly(raw, context: context),
                kind: kind
            )
            if kind == .error {
                DeviceAppGuidance.warningNotification()
            } else {
                DeviceAppGuidance.successNotification()
                startResendCooldown(seconds: 30)
            }
            viewModel.errorMessage = nil
        }
    }

    private var resendButtonTitle: String {
        if resendSecondsRemaining > 0 {
            return "Resend in \(resendSecondsRemaining)s"
        }
        return "Resend Code"
    }

    private func submitCode() {
        guard code.count == 6, !viewModel.isLoading else { return }
        clearBanner()
        loadingAction = .verify
        viewModel.verifyOTP(email: email, enteredOTP: code) {
            onVerified()
        }
    }

    private func resendCode() {
        guard canResend else { return }
        clearBanner()
        loadingAction = .resend
        viewModel.resendOTP(email: email) {
            code = ""
            codeFieldFocused = true
        }
    }

    private func startResendCooldown(seconds: Int) {
        resendTickTask?.cancel()
        resendSecondsRemaining = seconds
        resendTickTask = Task { @MainActor in
            while resendSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendSecondsRemaining -= 1
            }
        }
    }

    private func clearBanner() {
        withAnimation(HomeUI1Motion.soft) {
            bannerMessage = nil
        }
    }

    private func presentBanner(_ message: String, kind: DeviceSignInMessageKind) {
        withAnimation(HomeUI1Motion.soft) {
            bannerKind = kind
            bannerMessage = message
        }
    }
}

#Preview {
    DeviceSignInView()
}
