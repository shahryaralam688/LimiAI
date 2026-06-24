import Foundation
import SwiftUI

protocol LoginOTPVerifying {
    func verifyOTP(email: String, otp: String, completion: @escaping (Result<String, Error>) -> Void)
}

struct DefaultLoginOTPVerifier: LoginOTPVerifying {
    enum OTPVerificationError: LocalizedError {
        case invalidURL
        case invalidPayload
        case noData
        case backend(String)
        case missingToken

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidPayload:
                return "Error creating JSON"
            case .noData:
                return "No data received"
            case .backend(let message):
                return message
            case .missingToken:
                return "Token not found in response"
            }
        }
    }

    func verifyOTP(email: String, otp: String, completion: @escaping (Result<String, Error>) -> Void) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.verifyOTP,
            body: [
                "email": email,
                "otp": otp.trimmingCharacters(in: .whitespacesAndNewlines)
            ],
            auth: .none
        ) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(OTPVerificationError.noData))
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let success = jsonResponse["success"] as? Bool, success {
                        if let dataDict = jsonResponse["data"] as? [String: Any],
                           let token = dataDict["token"] as? String {
                            completion(.success(token))
                        } else {
                            completion(.failure(OTPVerificationError.missingToken))
                        }
                    } else {
                        let errorMessage = jsonResponse["error_message"] as? String ?? "Invalid OTP"
                        completion(.failure(OTPVerificationError.backend(errorMessage)))
                    }
                } else {
                    completion(.failure(OTPVerificationError.backend("Failed to parse response")))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

final class OTPVerificationViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isVerifying = false
    @Published var digitBoxes: [Bool] = Array(repeating: false, count: 6)
    @Published var shakeError = false

    private let otpVerifier: LoginOTPVerifying
    private let otpRequester: LoginOTPRequesting

    init(
        otpVerifier: LoginOTPVerifying = DefaultLoginOTPVerifier(),
        otpRequester: LoginOTPRequesting = DefaultLoginOTPRequester()
    ) {
        self.otpVerifier = otpVerifier
        self.otpRequester = otpRequester
    }

    func handleOTPChanged(_ newValue: String) -> String {
        let sanitized = String(newValue.prefix(6))

        for index in 0..<6 {
            digitBoxes[index] = index < sanitized.count
        }

        if errorMessage != nil {
            errorMessage = nil
        }

        return sanitized
    }

    func verifyOTP(email: String, enteredOTP: String, onVerified: @escaping () -> Void) {
        withAnimation {
            isLoading = true
            isVerifying = true
        }

        otpVerifier.verifyOTP(email: email, otp: enteredOTP) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                withAnimation {
                    self.isLoading = false
                    self.isVerifying = false
                }

                switch result {
                case .success(let token):
                    AuthManager.shared.saveToken(token, updateAuthState: false)
                    AuthManager.shared.clearRole()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        onVerified()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.triggerErrorAnimation()
                }
            }
        }
    }

    func resendOTP(email: String, onReset: @escaping () -> Void) {
        withAnimation {
            isLoading = true
        }

        otpRequester.requestOTP(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                withAnimation {
                    self.isLoading = false
                }

                switch result {
                case .success:
                    self.errorMessage = "OTP sent successfully!"
                    onReset()
                    self.digitBoxes = Array(repeating: false, count: 6)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func triggerErrorAnimation() {
        withAnimation(.default) {
            shakeError = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.default) {
                self.shakeError = false
            }
        }
    }
}
