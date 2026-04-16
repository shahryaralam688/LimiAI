//
//  SignIn.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 30/12/2025.
//

import SwiftUI
import RealityKit
import AuthenticationServices
struct SignInView: View {
    @StateObject private var authManager = GoogleAuthManager()
    @State private var isLoading = false
    @State private var showHomeView = false
    @State private var showLoginView = false
    @State private var showPrivacyPolicy = false
    @State private var appeared = false
    var body: some View {
        GeometryReader { geo in
            let horizontalInset: CGFloat = 24
            let maxColumn = min(geo.size.width - horizontalInset * 2, 400)
            let bottomInset = max(geo.safeAreaInsets.bottom, 12) + 8

            ZStack {
                Image("signInBg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    signInColumn(maxWidth: maxColumn)
                        .frame(maxWidth: maxColumn)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, bottomInset)
                .padding(.top, max(geo.safeAreaInsets.top, 8))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear { withAnimation(LimiMotion.gentle) { appeared = true } }
        .fullScreenCover(isPresented: $showHomeView) {
            //HomeView()
            OnboardingFlowView()
        }
        .fullScreenCover(isPresented: $showLoginView) {
            LoginSkipView()
        }
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .trackScreen(
            "SignInView",
            metadata: [
                "ui_guide": "Welcome to Limi AI. Use Continue with Email (opens full login), Continue with Google, or Guest. You can open Privacy Policy from here."
            ]
        )
    }

    @ViewBuilder
    private func signInColumn(maxWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image("LoginViewLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: min(160, maxWidth * 0.85), height: 32)
                .padding(.bottom, 20)

            Text("Invisible by design,\nIntelligent by nature")
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .foregroundColor(.themeWhite)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)

            Text("Login with the options below")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, 16)

            Button(action: { showLoginView = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16, weight: .regular))
                    Text("Continue with Email")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.themeWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .background(Color.appSurfacePrimary)
            .cornerRadius(16)

            Button(action: {
                authManager.signInWithGoogle { success in
                    if success {
                        DispatchQueue.main.async { showHomeView = true }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image("google")
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text("Continue with Google")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.appTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appSurfacePrimary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderPrimary, lineWidth: 1)
                )
            }
            .padding(.top, 10)

            Button {
                createInstallerUser()
            } label: {
                Text("Continue as a Guest")
                    .font(LimiTypography.body)
                    .foregroundColor(.appTextPrimary)
                    .kerning(0)
                    .multilineTextAlignment(.center)
                    .underline()
                    .padding()
            }
            .buttonStyle(.plain)
            .tapScale()

            legalAgreementFooter
                .padding(.top, 8)
        }
        .frame(maxWidth: maxWidth)
    }

    private var legalAgreementFooter: some View {
        VStack(spacing: 10) {
            Text("By continuing you are agreeing to our")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color.appTextQuiet)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button(action: { print("Terms tapped") }) {
                    Text("Terms")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .underline(true, color: Color.appTextQuiet)
                }
                Text("·")
                    .foregroundColor(Color.appTextQuiet.opacity(0.6))
                Button(action: { showPrivacyPolicy = true }) {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .underline(true, color: Color.appTextQuiet)
                }
            }
            .frame(maxWidth: .infinity)
        }
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
#Preview {
    SignInView()
}

// Same response model used in LoginView for installer user API
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
