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
        ZStack{
            Image("Sign in")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea() // covers entire screen

            
            
            VStack{

                
                Image("LoginViewLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 40)
                    .padding(.bottom, 159)
                
                Text("Invisible by design, Intelligent by nature")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundColor(.themeWhite)
                    .multilineTextAlignment(.center)
                    .lineSpacing(9.6) // 130% of 32pt

                Text("Login with the options below")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color.appTextQuiet)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)        // 120% of 15pt = 18pt → 18 - 15 = 3pt extraenvelope.front
                    .kerning(-0.15)        // Letter spacing -0.15px (Figma)
                
                
                
                Button(action: {
                    showLoginView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 20, weight: .regular))
                        
                        Text("Continue with Email")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.3)
                    }
                    .foregroundColor(.themeWhite)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: LimiRadius.large)
                            .stroke(Color.appBorderPrimary, lineWidth: 1)
                    )
                    
                }
                .background(Color.appSurfacePrimary)
                .cornerRadius(LimiRadius.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                Button(action: {
                    authManager.signInWithGoogle { success in
                        if success {
                            DispatchQueue.main.async {
                                showHomeView = true
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
                        .background(Color.appSurfacePrimary)
                        .cornerRadius(LimiRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: LimiRadius.large)
                                .stroke(Color.appBorderPrimary, lineWidth: 1)
                        )
                    }
                    
                }
                .background(Color.appSurfacePrimary)
                .cornerRadius(LimiRadius.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                
//                Button(action: {
//                    authManager.signInWithApple { success in
//                        if success {
//                            DispatchQueue.main.async {
//                                showHomeView = true
//                            }
//                        }
//                    }
//
//                }) {
//                    HStack(spacing: 8) {
//                        Image(systemName: "applelogo")
//                            .font(.system(size: 20, weight: .regular))
//                        
//                        Text("Continue with Apple")
//                            .font(.system(size: 16, weight: .semibold))
//                            .tracking(-0.3)
//                    }
//                    .foregroundColor(.themeWhite)
//                    .frame(maxWidth: .infinity, minHeight: 56)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: LimiRadius.large)
//                            .stroke(Color.appBorderPrimary, lineWidth: 1)
//                    )
//                }
//                .padding(.horizontal, 20)
//                .padding(.top, 15)
                
               

                
                

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


                HStack(spacing: 0) {
                    Text("By continuing you are agreeing to our ")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .kerning(-0.15)
                    
                    Button(action: {
                        // navigate or open Terms
                        
                        
                        print("Terms tapped")
                    }) {
                        Text("Terms")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.appTextQuiet)
                            .underline(true, color: Color.appTextQuiet)
                            .kerning(-0.15)
                    }
                    
                    Text(" and ")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color.appTextQuiet)
                        .kerning(-0.15)
                    
                    Button(action: {
                        // navigate or open Privacy Policy
                        print("Privacy Policy tapped")
                        showPrivacyPolicy = true
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.appTextQuiet)
                            .underline(true, color: Color.appTextQuiet)
                            .kerning(-0.15)
                    }
                }
                .multilineTextAlignment(.center)
//                .lineSpacing(4.8) // 140% of 12pt
//                .frame(width: 283) // matches Figma width



            }
            .padding()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
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
