//
//  TestingSignIn.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 04/11/2025.
//

import SwiftUI

struct TestingSignIn: View {
    @StateObject private var authManager = GoogleAuthManager()
    
    var body: some View {
        ZStack {
            // Background
            Color.appCanvasPrimary.ignoresSafeArea()
            
            VStack(spacing: 40) {
                if authManager.isSignedIn {
                    // Signed in state
                    VStack(spacing: 24) {
                        Text("Welcome!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.themeWhite)
                        
                        VStack(spacing: 12) {
                            Text(authManager.userName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.themeWhite)
                            
                            Text(authManager.userEmail)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.themeWhite.opacity(0.8))
                        }
                        
                        Button {
                            authManager.signOut()
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.themeWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Capsule(style: .continuous).fill(Color.appDanger))
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    // Sign in state
                    VStack(spacing: 40) {
                        VStack(spacing: 16) {
                            Text("Welcome to LIMI")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.themeWhite)
                            
                            Text("Sign in with your Google account to continue")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.themeWhite.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Google Sign-In Button
                        Button {
                            authManager.signInWithGoogle()
                        } label: {
                            HStack(spacing: 12) {
                                // Google Icon
                                Image(systemName: "globe")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.appTextPrimary)
                                
                                Text("Sign in with Google")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.appTextPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                            .clipShape(Capsule(style: .continuous))
                            .shadow(color: .themeBlack.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
        }
    }
}

// MARK: - Custom Google Icon View
struct GoogleIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.themeWhite)
                .frame(width: 24, height: 24)
            
            // Simplified Google "G" icon using SF Symbols
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orbGlow4)
        }
    }
}

// MARK: - Preview
#Preview {
    TestingSignIn()
}

