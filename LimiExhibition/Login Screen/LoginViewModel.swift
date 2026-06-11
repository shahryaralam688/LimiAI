import Foundation

protocol LoginOTPRequesting {
    func requestOTP(email: String, completion: @escaping (Result<String, Error>) -> Void)
}

struct DefaultLoginOTPRequester: LoginOTPRequesting {
    enum OTPRequestError: LocalizedError {
        case invalidURL
        case invalidPayload
        case noData
        case backend(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidPayload:
                return "Invalid request payload"
            case .noData:
                return "No data received"
            case .backend(let message):
                return message
            }
        }
    }

    func requestOTP(email: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: APIConstants.sendOTP) else {
            completion(.failure(OTPRequestError.invalidURL))
            return
        }

        let parameters: [String: Any] = ["email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            completion(.failure(OTPRequestError.invalidPayload))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(OTPRequestError.noData))
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = jsonResponse["success"] as? Bool, success {
                        let otp = jsonResponse["otp"] as? String ?? ""
                        completion(.success(otp))
                    } else {
                        let errorMessage = jsonResponse["error_message"] as? String ?? "Unknown error"
                        completion(.failure(OTPRequestError.backend(errorMessage)))
                    }
                } else {
                    completion(.failure(OTPRequestError.backend("Invalid server response")))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var isSigningIn = false
    @Published var isShowingOTPView = false
    @Published var enteredOTP = ""
    @Published var isOTPVerified = false
    @Published var appeared = false

    private(set) var generatedOTP = ""
    private let otpRequester: LoginOTPRequesting

    init(otpRequester: LoginOTPRequesting = DefaultLoginOTPRequester()) {
        self.otpRequester = otpRequester
    }

    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    func requestOTP() {
        guard isEmailValid, !isSigningIn else { return }
        isSigningIn = true

        otpRequester.requestOTP(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSigningIn = false

                switch result {
                case .success(let otp):
                    self.generatedOTP = otp
                    self.isShowingOTPView = true
                case .failure(let error):
                    print("OTP request failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
