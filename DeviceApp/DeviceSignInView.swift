//
//  DeviceSignInView.swift
//  LIMI AI Device
//
//  Native sign-in: Email (OTP), Google, or Guest — same backend flows
//  as the main app (SignInViewModel / LoginViewModel / OTP verify).
//

import SwiftUI

struct DeviceSignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = SignInViewModel(managesPostLoginNavigation: true)
    @State private var showEmailLogin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Image(colorScheme == .dark ? "IconWordmark_White" : "IconWordmark_Black")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .padding(.horizontal, 40)

                Text("Control your LIMI devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showEmailLogin = true
                    } label: {
                        Label("Continue with Email", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        viewModel.signInWithGoogle()
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Continue as a Guest") {
                        viewModel.continueAsGuest()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .disabled(viewModel.isLoading)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .sheet(isPresented: $showEmailLogin) {
                DeviceEmailLoginView()
            }
            .alert(
                "Sign In Failed",
                isPresented: Binding(
                    get: { viewModel.signInErrorMessage != nil },
                    set: { if !$0 { viewModel.signInErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.signInErrorMessage ?? "")
            }
            .onChange(of: viewModel.showHomeView) { _, showHome in
                // Device app has no Personalize step — a saved token means we're in.
                if showHome, AuthManager.shared.getToken() != nil {
                    AuthManager.shared.isAuthenticated = true
                }
            }
        }
    }
}

// MARK: - Email + OTP (native)

private struct DeviceEmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email address", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("We'll send a one-time code to this address.")
                }

                Section {
                    Button {
                        viewModel.requestOTP()
                    } label: {
                        if viewModel.isSigningIn {
                            HStack {
                                ProgressView()
                                Text("Sending code…")
                            }
                        } else {
                            Text("Send Code")
                        }
                    }
                    .disabled(!viewModel.isEmailValid || viewModel.isSigningIn)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $viewModel.isShowingOTPView) {
                DeviceOTPView(email: viewModel.email) {
                    dismiss()
                    AuthManager.shared.isAuthenticated = true
                }
            }
        }
    }
}

private struct DeviceOTPView: View {
    let email: String
    let onVerified: () -> Void

    @StateObject private var viewModel = OTPVerificationViewModel()
    @State private var code = ""
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($codeFieldFocused)
                    .onChange(of: code) { _, newValue in
                        code = viewModel.handleOTPChanged(newValue)
                    }
            } header: {
                Text("Verification code")
            } footer: {
                Text("Enter the code sent to \(email).")
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(message.contains("success") ? DeviceTheme.accent : Color.red)
                }
            }

            Section {
                Button {
                    viewModel.verifyOTP(email: email, enteredOTP: code) {
                        onVerified()
                    }
                } label: {
                    if viewModel.isVerifying {
                        HStack {
                            ProgressView()
                            Text("Verifying…")
                        }
                    } else {
                        Text("Verify")
                    }
                }
                .disabled(code.count != 6 || viewModel.isLoading)

                Button("Resend Code") {
                    viewModel.resendOTP(email: email) { code = "" }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Enter Code")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { codeFieldFocused = true }
    }
}

#Preview {
    DeviceSignInView()
}
