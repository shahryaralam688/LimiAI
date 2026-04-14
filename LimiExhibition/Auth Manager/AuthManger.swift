//
//  AuthManger.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 04/11/2025.
//

import Foundation
import GoogleSignIn
import UIKit
import AuthenticationServices

class GoogleAuthManager: NSObject, ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String = ""
    @Published var userName: String = ""
    @Published var userProfileImage: String = ""
    private static var appleSignInCompletionKeyAssociation: UInt8 = 0
    
    // iOS client ID (from Google Cloud OAuth "iOS" client)
    private let clientID = "687943495551-65rviehc8jcup19uobu40abpbi46leo6.apps.googleusercontent.com"
    // Web client ID (from Google Cloud OAuth "Web application" client) for server-side use
    private let webClientID = "687943495551-9pf3d6frfimu69e16827rpu9j3ic23lr.apps.googleusercontent.com"
    
    override init() {
        super.init()  // ✅ Call NSObject initializer first
        
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            // Fallback to hardcoded client ID if plist is not available
            let config = GIDConfiguration(
                clientID: clientID,
                serverClientID: webClientID
            )
            GIDSignIn.sharedInstance.configuration = config
            return
        }

        let config = GIDConfiguration(
            clientID: clientId,
            serverClientID: webClientID
        )
        GIDSignIn.sharedInstance.configuration = config
        
        checkSignInStatus()
    }
    
    func checkSignInStatus() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            self.isSignedIn = true
            self.userEmail = user.profile?.email ?? ""
            self.userName = user.profile?.name ?? ""
            self.userProfileImage = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
        } else {
            self.isSignedIn = false
        }
    }
    
    func signInWithGoogle(completion: ((Bool) -> Void)? = nil) {
        guard let presentingViewController = Self.topViewController() else {
            print("No presenting view controller found")
            completion?(false)
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Google Sign-In Error: \(error.localizedDescription)")
                    completion?(false)
                    return
                }
                
                guard let user = result?.user else {
                    print("No user data received")
                    completion?(false)
                    return
                }
                
                // DEBUG: Full Google user dump so we can see exactly what comes from Google
                print("[GoogleAuth] ===== GOOGLE RAW RESPONSE (signInWithGoogle) START =====")
                print("[GoogleAuth] user: \(user)")
                print("[GoogleAuth] user.profile?.email: \(user.profile?.email ?? "-")")
                print("[GoogleAuth] user.profile?.name: \(user.profile?.name ?? "-")")
                print("[GoogleAuth] user.grantedScopes: \(user.grantedScopes ?? [])")
                print("[GoogleAuth] ===== GOOGLE RAW RESPONSE (signInWithGoogle) END =====")

                let idTokenString = user.idToken?.tokenString ?? ""
                let serverAuthCode = result?.serverAuthCode

                if !idTokenString.isEmpty {
                    print("[GoogleAuth] 🪪 Google ID token (FULL): \(idTokenString)")
                } else {
                    print("[GoogleAuth] No Google ID token available in signInWithGoogle")
                }

                print("[GoogleAuth] serverAuthCode (signInWithGoogle): \(serverAuthCode ?? "nil")")

                self?.isSignedIn = true
                self?.userEmail = user.profile?.email ?? ""
                self?.userName = user.profile?.name ?? ""
                self?.userProfileImage = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
                if let idToken = user.idToken?.tokenString {
                    print("[GoogleAuth] Sending idToken + serverAuthCode to backend from signInWithGoogle()")
                    self?.sendTokenToBackend(idToken, serverAuthCode: serverAuthCode, grantedScopes: user.grantedScopes)
                } else {
                    print("No idToken available")
                }
                
                print("Successfully signed in: \(self?.userEmail ?? "")")
                completion?(true)
            }
        }
    }

    /// Request additional Google permissions (scopes) for the user.
    /// This re-runs the Google Sign-In flow but asks for the extra scopes.
    func requestGooglePermissions(scopes: [String], completion: ((Bool) -> Void)? = nil) {
        print("[GoogleAuth] 🔵 requestGooglePermissions() called with scopes: \(scopes)")
        guard let presentingViewController = Self.topViewController() else {
            print("No presenting view controller found for scope request")
            completion?(false)
            return
        }

        print("[GoogleAuth] Presenting Google Sign-In UI for additional scopes...")

        // Use signIn(withPresenting:hint:additionalScopes:) which is available in the
        // GoogleSignIn SDK version you are using.
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: scopes
        ) { [weak self] result, error in
            DispatchQueue.main.async {
                print("[GoogleAuth] ⏹ Google signIn callback for additional scopes reached")
                if let error = error {
                    print("[GoogleAuth] Failed to request additional Google scopes: \(error.localizedDescription)")
                    completion?(false)
                    return
                }

                guard let user = result?.user else {
                    print("[GoogleAuth] No user returned when requesting additional scopes")
                    completion?(false)
                    return
                }

                // DEBUG: Full Google user dump so we can see exactly what comes from Google
                print("[GoogleAuth] ===== GOOGLE RAW RESPONSE (requestGooglePermissions) START =====")
                print("[GoogleAuth] user: \(user)")
                print("[GoogleAuth] user.profile?.email: \(user.profile?.email ?? "-")")
                print("[GoogleAuth] user.profile?.name: \(user.profile?.name ?? "-")")
                print("[GoogleAuth] user.grantedScopes: \(user.grantedScopes ?? [])")
                print("[GoogleAuth] ===== GOOGLE RAW RESPONSE (requestGooglePermissions) END =====")

                let idTokenString = user.idToken?.tokenString ?? ""
                let serverAuthCode = result?.serverAuthCode

                if !idTokenString.isEmpty {
                    print("[GoogleAuth] 🪪 (scopes) Google ID token (FULL): \(idTokenString)")
                } else {
                    print("[GoogleAuth] (scopes) No Google ID token available")
                }

                print("[GoogleAuth] serverAuthCode (requestGooglePermissions): \(result?.serverAuthCode ?? "nil")")

                // Debug: log granted scopes and user information
                print("[GoogleAuth] ✅ Additional scopes requested:")
                print("[GoogleAuth]   Requested scopes: \(scopes)")
                print("[GoogleAuth]   Granted scopes: \(user.grantedScopes ?? [])")
                print("[GoogleAuth]   User email: \(user.profile?.email ?? "-")")

                // Update local user info
                self?.isSignedIn = true
                self?.userEmail = user.profile?.email ?? ""
                self?.userName = user.profile?.name ?? ""
                self?.userProfileImage = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""

                // Optionally send refreshed idToken + serverAuthCode + granted scopes to backend
                if let idToken = user.idToken?.tokenString {
                    let prefix = String(idToken.prefix(50))
                    print("[GoogleAuth] idToken prefix (50 chars): \(prefix)...")
                    print("[GoogleAuth] Sending idToken + serverAuthCode + scopes to backend from requestGooglePermissions()")
                    self?.sendTokenToBackend(idToken, serverAuthCode: serverAuthCode, grantedScopes: user.grantedScopes)
                } else {
                    print("[GoogleAuth] No idToken found after requesting additional scopes")
                }

                print("[GoogleAuth] 🔵 requestGooglePermissions() completed successfully")
                completion?(true)
            }
        }
    }

    private static func topViewController(base: UIViewController? = {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window.rootViewController
        }
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window.rootViewController
        }
        return nil
    }()) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    private func sendTokenToBackend(_ token: String, serverAuthCode: String? = nil, grantedScopes: [String]? = nil) {
        guard let url = URL(string: APIConstants.loginGoogle) else { return }
        print("[Backend] 🔵 sendTokenToBackend() called")
        print("[Backend] URL: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Request body – send the REAL Google ID token, optional serverAuthCode, and granted scopes we received
        let payload: [String: Any] = [
            "id_token": token,
            "server_auth_code": serverAuthCode as Any
//            "granted_scopes": grantedScopes ?? []
        ]
        print("[Backend] Sending id_token to backend (truncated): \(String(token.prefix(50)))...")
        print("[Backend] server_auth_code: \(serverAuthCode ?? "nil")")
        print("[Backend] Granted scopes: \(grantedScopes ?? [])")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("[Backend] ⏹ Backend response received")
            if let error = error {
                print("[Backend] Error: \(error)")
                return
            }
            
            if let http = response as? HTTPURLResponse {
                print("[Backend] Status code: \(http.statusCode)")
            }
            
            guard let data = data else {
                print("[Backend] No data returned")
                return
            }
            
            if let raw = String(data: data, encoding: .utf8) {
                print("[Backend] Raw response: \(raw)")
            }
            
            // Parse JSON to extract token
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let dataField = json["data"] as? [String: Any],
                   let token = dataField["token"] as? String {
                    print("[Backend] Full JSON: \(json)")
                    print("[Backend] Extracted Token: \(token)")
                    // Option A: defer setting global isAuthenticated until onboarding completes
                    AuthManager.shared.saveToken(token, updateAuthState: false)
                    AuthManager.shared.clearRole()
                } else {
                    print("[Backend] Token not found in response JSON.")
                }
            } catch {
                print("[Backend] JSON parsing error: \(error)")
            }
            print("[Backend] 🔵 sendTokenToBackend() finished")
        }.resume()
    }

    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userEmail = ""
            self.userName = ""
            self.userProfileImage = ""
        }
    }
}


extension GoogleAuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func signInWithApple(completion: ((Bool) -> Void)? = nil) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        // Request same scopes as the SwiftUI SignInWithAppleButton
        request.requestedScopes = [.fullName, .email]
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        // github
        self.appleSignInCompletion = completion
    }
    
    // Store completion temporarily
    
    private var appleSignInCompletion: ((Bool) -> Void)? {
        get { objc_getAssociatedObject(self, &Self.appleSignInCompletionKeyAssociation) as? ((Bool) -> Void) }
        set { objc_setAssociatedObject(self, &Self.appleSignInCompletionKeyAssociation, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            let identityToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            print("[AppleAuth] Apple user id: \(userId)")
            print("[AppleAuth] identityToken prefix (50): \(String(identityToken.prefix(50)))...")
            
            DispatchQueue.main.async {
                self.isSignedIn = true
                self.userProfileImage = "" // Still empty for Apple Sign-In
                guard !identityToken.isEmpty else {
                    self.appleSignInCompletion?(false)
                    self.appleSignInCompletion = nil
                    return
                }
                AppleLoginAPI.exchange(identityToken: identityToken, appleUserId: userId) { [weak self] result in
                    switch result {
                    case .success:
                        self?.appleSignInCompletion?(true)
                    case .failure(let err):
                        print("[AppleAuth] Exchange failed: \(err.localizedDescription)")
                        self?.appleSignInCompletion?(false)
                    }
                    self?.appleSignInCompletion = nil
                }
            }
        } else {
            DispatchQueue.main.async {
                self.appleSignInCompletion?(false)
                self.appleSignInCompletion = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign-In Error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.appleSignInCompletion?(false)
            self.appleSignInCompletion = nil
        }
    }
    
    // MARK: ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}
