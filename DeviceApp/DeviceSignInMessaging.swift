//
//  DeviceSignInMessaging.swift
//  LIMI AI Device — presentation-only Sign In copy / error fallbacks.
//  Does not change auth business logic.
//

import Foundation

enum DeviceSignInMessageKind {
    case info
    case success
    case error
}

enum DeviceSignInMessaging {
    /// Maps raw backend / system errors into short, calm user-facing copy.
    static func friendly(_ raw: String?, context: Context = .general) -> String {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return fallback(for: context)
        }

        let lower = text.lowercased()

        if looksLikeUserCancel(lower) {
            return "Sign-in was cancelled. You can try again anytime."
        }
        if looksLikeNetwork(lower) {
            return "No internet connection. Check Wi‑Fi or mobile data, then try again."
        }
        if looksLikeTimeout(lower) {
            return "That took too long. Please try again."
        }
        if looksLikeServer(lower) {
            return "Our servers are busy right now. Please try again in a moment."
        }
        if looksLikeInvalidOTP(lower) {
            return "That code isn’t correct. Check the email and try again."
        }
        if looksLikeExpiredOTP(lower) {
            return "This code has expired. Tap Resend Code for a new one."
        }
        if looksLikeRateLimit(lower) {
            return "Too many attempts. Wait a minute, then try again."
        }
        if looksLikeInvalidEmail(lower) {
            return "Please enter a valid email address."
        }
        if looksLikeGoogle(lower) {
            return "Google sign-in didn’t finish. Please try again, or use Email."
        }
        if looksLikeToken(lower) {
            return "We couldn’t start your session. Please try signing in again."
        }
        if looksLikeTechnicalNoise(lower) {
            return fallback(for: context)
        }

        // Keep readable backend messages; trim long dumps.
        if text.count > 140 {
            return String(text.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return text
    }

    static func isSuccessCopy(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("sent")
            || lower.contains("success")
            || lower.contains("check your")
            || lower.contains("spam")
            || lower.contains("inbox")
            || lower.contains("code to your email")
    }

    static func kind(for message: String) -> DeviceSignInMessageKind {
        isSuccessCopy(message) ? .success : .error
    }

    static func emailHint(isEmpty: Bool, isValid: Bool) -> String? {
        if isEmpty { return "Use the email linked to your LIMI account." }
        if !isValid { return "Enter a full email like name@example.com" }
        return nil
    }

    static func loadingTitle(for action: LoadingAction) -> String {
        switch action {
        case .google: return "Signing in with Google…"
        case .guest: return "Starting guest session…"
        case .sendCode: return "Sending verification code…"
        case .verify: return "Verifying code…"
        case .resend: return "Sending a new code…"
        }
    }

    static func loadingSubtitle(for action: LoadingAction) -> String {
        switch action {
        case .google: return "Finish in the Google sheet if it appears."
        case .guest: return "Guest can browse; sign in later to manage devices."
        case .sendCode: return "This usually takes a few seconds."
        case .verify: return "Hang tight — almost there."
        case .resend: return "Check inbox and spam for the new code."
        }
    }

    enum Context {
        case general
        case google
        case guest
        case sendCode
        case verify
        case resend
    }

    enum LoadingAction {
        case google
        case guest
        case sendCode
        case verify
        case resend
    }

    private static func fallback(for context: Context) -> String {
        switch context {
        case .general:
            return "Something went wrong. Please try again."
        case .google:
            return "Google sign-in didn’t finish. Please try again."
        case .guest:
            return "Couldn’t start guest mode. Check your connection and try again."
        case .sendCode:
            return "Couldn’t send the code. Check your email and connection, then try again."
        case .verify:
            return "Couldn’t verify that code. Please try again."
        case .resend:
            return "Couldn’t resend the code. Please try again in a moment."
        }
    }

    private static func looksLikeUserCancel(_ lower: String) -> Bool {
        lower.contains("cancel") || lower.contains("user canceled") || lower.contains("user cancelled")
    }

    private static func looksLikeNetwork(_ lower: String) -> Bool {
        lower.contains("network")
            || lower.contains("internet")
            || lower.contains("offline")
            || lower.contains("not connected")
            || lower.contains("nsurlerror")
            || lower.contains("the internet connection appears to be offline")
            || lower.contains("could not connect to the server")
            || lower.contains("connection was lost")
            || lower.contains("connection failed")
    }

    private static func looksLikeTimeout(_ lower: String) -> Bool {
        lower.contains("timed out") || lower.contains("timeout") || lower.contains("time out")
    }

    private static func looksLikeServer(_ lower: String) -> Bool {
        lower.contains("http 5")
            || lower.contains("500")
            || lower.contains("502")
            || lower.contains("503")
            || lower.contains("504")
            || lower.contains("server error")
            || lower.contains("bad gateway")
            || lower.contains("service unavailable")
    }

    private static func looksLikeInvalidOTP(_ lower: String) -> Bool {
        lower.contains("invalid otp")
            || lower.contains("incorrect otp")
            || lower.contains("wrong otp")
            || lower.contains("invalid code")
            || lower.contains("incorrect code")
            || (lower.contains("otp") && lower.contains("invalid"))
    }

    private static func looksLikeExpiredOTP(_ lower: String) -> Bool {
        lower.contains("expired") || lower.contains("expire")
    }

    private static func looksLikeRateLimit(_ lower: String) -> Bool {
        lower.contains("too many")
            || lower.contains("rate limit")
            || lower.contains("try again later")
            || lower.contains("429")
    }

    private static func looksLikeInvalidEmail(_ lower: String) -> Bool {
        lower.contains("valid email") || lower.contains("invalid email")
    }

    private static func looksLikeGoogle(_ lower: String) -> Bool {
        lower.contains("google sign-in failed") || lower.contains("google sign in failed")
    }

    private static func looksLikeToken(_ lower: String) -> Bool {
        lower.contains("token not found")
            || lower.contains("could not start your session")
            || lower.contains("missing token")
    }

    private static func looksLikeTechnicalNoise(_ lower: String) -> Bool {
        lower.contains("invalid url")
            || lower.contains("no data")
            || lower.contains("invalid response")
            || lower.contains("invalid payload")
            || lower.contains("error creating json")
            || lower.contains("failed to parse")
            || lower.contains("nsurlerror")
            || lower.hasPrefix("error ")
            || lower.contains("http ")
    }
}
