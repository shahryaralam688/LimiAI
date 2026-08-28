import Foundation

protocol LoginOTPRequesting {
    func requestOTP(email: String, completion: @escaping (Result<String, Error>) -> Void)
}

enum LoginOTPResponseParser {
    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func parseSendOTP(
        data: Data,
        http: HTTPURLResponse?,
        requestError: Error? = nil
    ) -> Result<String, Error> {
        if let requestError {
            return .failure(requestError)
        }

        if let http, !(200...299).contains(http.statusCode) {
            let message = parseErrorMessage(from: data)
                ?? "Could not send code (HTTP \(http.statusCode))"
            return .failure(DefaultLoginOTPRequester.OTPRequestError.backend(message))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(DefaultLoginOTPRequester.OTPRequestError.backend("Invalid server response"))
        }

        if let success = json["success"] as? Bool, success {
            return .success(parseSuccessMessage(from: json))
        }

        let errorMessage = parseErrorMessage(from: data) ?? "Could not send verification code"
        return .failure(DefaultLoginOTPRequester.OTPRequestError.backend(errorMessage))
    }

    private static func parseSuccessMessage(from json: [String: Any]) -> String {
        if let otpObject = json["otp"] as? [String: Any],
           let serverMessage = otpObject["message"] as? String,
           !serverMessage.isEmpty {
            return "\(serverMessage) Check your spam folder if you do not see it."
        }

        if let otpString = json["otp"] as? String, !otpString.isEmpty {
            return "Verification code sent. Check your spam folder if you do not see it."
        }

        return "We sent a code to your email. Check your inbox and spam folder."
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["error_message"] as? String, !message.isEmpty {
            return message
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }

    static func backendErrorMessage(from data: Data, fallback: String) -> String {
        parseErrorMessage(from: data) ?? fallback
    }
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
        let normalizedEmail = LoginOTPResponseParser.normalizedEmail(email)
        guard !normalizedEmail.isEmpty else {
            completion(.failure(OTPRequestError.backend("Please enter a valid email address")))
            return
        }

        LimiHTTPClient.postJSON(
            urlString: APIConstants.sendOTP,
            body: ["email": normalizedEmail],
            auth: .none
        ) { data, response, error in
            guard let data else {
                completion(.failure(error ?? OTPRequestError.noData))
                return
            }

            completion(LoginOTPResponseParser.parseSendOTP(data: data, http: response, requestError: error))
        }
    }
}

final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var isSigningIn = false
    @Published var isShowingOTPView = false
    @Published var enteredOTP = ""
    @Published var isOTPVerified = false
    @Published var appeared = false
    @Published var otpRequestErrorMessage: String?
    @Published var otpSentConfirmationMessage: String?

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
        email = LoginOTPResponseParser.normalizedEmail(email)
        guard isEmailValid, !isSigningIn else { return }
        otpRequestErrorMessage = nil
        otpSentConfirmationMessage = nil
        isSigningIn = true

        otpRequester.requestOTP(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSigningIn = false

                switch result {
                case .success(let confirmationMessage):
                    self.otpSentConfirmationMessage = confirmationMessage
                    self.isShowingOTPView = true
                case .failure(let error):
                    self.otpRequestErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
