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

            // Send Apple credentials to backend and save app token
            sendAppleLoginToBackend(userIdentifier: userIdentifier, identityToken: identityToken)
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

// MARK: - Backend Integration for Apple Sign-In

fileprivate func sendAppleLoginToBackend(userIdentifier: String, identityToken: String?) {
    guard let url = URL(string: APIConstants.loginGoogle) else {
        print("[AppleAuth] Invalid loginGoogle URL")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    var body: [String: Any] = [
        "id_token": userIdentifier
    ]
    if let identityToken = identityToken {
        body["apple_identity_token"] = identityToken
    }

    do {
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = data
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[AppleAuth] 📤 Request payload: \(jsonString)")
        }
    } catch {
        print("[AppleAuth] Failed to encode Apple login body: \(error)")
        return
    }

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("[AppleAuth] Request error: \(error.localizedDescription)")
            return
        }

        if let http = response as? HTTPURLResponse {
            print("[AppleAuth] HTTP status: \(http.statusCode)")
        }

        guard let data = data else {
            print("[AppleAuth] No data returned from backend")
            return
        }

        if let raw = String(data: data, encoding: .utf8) {
            print("[AppleAuth] 📩 Raw response: \(raw)")
        }

        // Parse JSON to extract app token, following same pattern as AuthManager usage
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let dataField = json["data"] as? [String: Any],
               let token = dataField["token"] as? String {
                print("[AppleAuth] Extracted app token: \(token)")
                AuthManager.shared.saveToken(token)
            } else {
                print("[AppleAuth] Token not found in response JSON")
            }
        } catch {
            print("[AppleAuth] JSON parsing error: \(error)")
        }
    }.resume()
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
                // Send Apple credentials to backend and save app token
                sendAppleLoginToBackend(userIdentifier: userIdentifier, identityToken: tokenString)
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
