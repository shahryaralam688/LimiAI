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
            completion?(false)
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(false)
                    return
                }
                
                guard let user = result?.user else {
                    completion?(false)
                    return
                }
                
                // DEBUG: Full Google user dump so we can see exactly what comes from Google

                let idTokenString = user.idToken?.tokenString ?? ""
                let serverAuthCode = result?.serverAuthCode

                if !idTokenString.isEmpty {
                } else {
                }


                self?.isSignedIn = true
                self?.userEmail = user.profile?.email ?? ""
                self?.userName = user.profile?.name ?? ""
                self?.userProfileImage = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
                guard let idToken = user.idToken?.tokenString, !idToken.isEmpty else {
                    completion?(false)
                    return
                }

                self?.sendTokenToBackend(
                    idToken,
                    serverAuthCode: serverAuthCode,
                    grantedScopes: user.grantedScopes
                ) { success in
                    if success {
                    } else {
                    }
                    completion?(success)
                }
            }
        }
    }

    /// Request additional Google permissions (scopes) for the user.
    /// This re-runs the Google Sign-In flow but asks for the extra scopes.
    func requestGooglePermissions(scopes: [String], completion: ((Bool) -> Void)? = nil) {
        guard let presentingViewController = Self.topViewController() else {
            completion?(false)
            return
        }


        // Use signIn(withPresenting:hint:additionalScopes:) which is available in the
        // GoogleSignIn SDK version you are using.
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: scopes
        ) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(false)
                    return
                }

                guard let user = result?.user else {
                    completion?(false)
                    return
                }

                // DEBUG: Full Google user dump so we can see exactly what comes from Google

                let idTokenString = user.idToken?.tokenString ?? ""
                let serverAuthCode = result?.serverAuthCode

                if !idTokenString.isEmpty {
                } else {
                }


                // Debug: log granted scopes and user information

                // Update local user info
                self?.isSignedIn = true
                self?.userEmail = user.profile?.email ?? ""
                self?.userName = user.profile?.name ?? ""
                self?.userProfileImage = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""

                // Optionally send refreshed idToken + serverAuthCode + granted scopes to backend
                if let idToken = user.idToken?.tokenString {
                    let prefix = String(idToken.prefix(50))
                    self?.sendTokenToBackend(idToken, serverAuthCode: serverAuthCode, grantedScopes: user.grantedScopes)
                } else {
                }

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

    private func sendTokenToBackend(
        _ token: String,
        serverAuthCode: String? = nil,
        grantedScopes: [String]? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {

        let payload: [String: Any] = [
            "id_token": token,
            "server_auth_code": serverAuthCode as Any
        ]

        LimiHTTPClient.postJSON(
            urlString: APIConstants.loginGoogle,
            body: payload,
            auth: .none
        ) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(false)
                    return
                }

                if let http = response {
                }

                guard let data = data else {
                    completion?(false)
                    return
                }

                if let raw = String(data: data, encoding: .utf8) {
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let dataField = json["data"] as? [String: Any],
                       let sessionToken = dataField["token"] as? String {
                        // Defer isAuthenticated until SignIn / Personalize completes.
                        AuthManager.shared.saveToken(sessionToken, updateAuthState: false)
                        AuthManager.shared.clearRole()
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                } catch {
                    completion?(false)
                }
            }
        }
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
        request.requestedScopes = []

        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
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

            #if DEBUG
            #endif
            
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
