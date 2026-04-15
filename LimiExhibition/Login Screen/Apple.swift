import AuthenticationServices
//
//  Apple.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 30/12/2025.
//

import SwiftUI
import AuthenticationServices
import Foundation

struct AppleLoginView: View {
    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                // Ask for the data you need
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                switch result {
                case .success(let authResults):
                    handleAuthResult(authResults)
                case .failure(let error):
                    print("❌ Sign in with Apple failed: \(error)")
                }
            }
        )
        .frame(height: 50)
        .cornerRadius(8)
        .padding()
    }

    private func handleAuthResult(_ authResults: ASAuthorization) {
        if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = credential.user
            let fullName = credential.fullName
            let email = credential.email
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }

            // ⚠️ fullName & email are only non-nil on FIRST login
            print("Apple user id: \(userIdentifier)")
            print("Email: \(email ?? "nil")")
            print("Name: \(fullName?.givenName ?? "") \(fullName?.familyName ?? "")")

            guard let jwt = identityToken else {
                print("[AppleAuth] Missing identity token")
                return
            }
            AppleLoginAPI.exchange(identityToken: jwt, appleUserId: userIdentifier) { result in
                if case .failure(let err) = result {
                    print("[AppleAuth] Exchange failed: \(err.localizedDescription)")
                }
            }
        }
        
    }
    
}
#Preview {
    AppleLoginView()
}

class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppleButton()
    }

    private func setupAppleButton() {
        let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        appleButton.addTarget(self, action: #selector(handleAppleIdRequest), for: .touchUpInside)
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appleButton)

        NSLayoutConstraint.activate([
            appleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appleButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            appleButton.heightAnchor.constraint(equalToConstant: 50),
            appleButton.widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    @objc func handleAppleIdRequest() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {

        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = credential.user
            let email = credential.email
            let fullName = credential.fullName
            let identityToken = credential.identityToken // JWT for backend verification

            print("✅ Apple user id: \(userIdentifier)")
            print("Email: \(email ?? "nil")")

            // Convert identityToken to String if you need to send to backend
            if let tokenData = identityToken,
               let tokenString = String(data: tokenData, encoding: .utf8) {
                print("identityToken: \(tokenString)")
                AppleLoginAPI.exchange(identityToken: tokenString, appleUserId: userIdentifier) { result in
                    if case .failure(let err) = result {
                        print("[AppleAuth] Exchange failed: \(err.localizedDescription)")
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        print("❌ Sign in with Apple error: \(error.localizedDescription)")
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
