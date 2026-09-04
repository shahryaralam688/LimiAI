//
//  DeviceProfileMessaging.swift
//  LIMI AI Device — calm, user-facing copy for Profile load / save / photo errors.
//

import Foundation

enum DeviceProfileMessageKind {
    case info
    case success
    case error
}

enum DeviceProfileMessaging {
    static let sessionExpired =
        "Your session has expired. Please sign in again."

    static let loadFailed =
        "Couldn't load your profile. Pull to refresh or try again."

    static let saveFailed =
        "Couldn't update your profile. Check your connection and try again."

    static let photoLoadFailed =
        "Couldn't load the selected photo. Try another image."

    static let nameRequired =
        "Please enter a valid name."

    static let successSaved =
        "Profile updated."

    /// Maps raw backend / system errors into short Profile copy.
    static func friendly(_ raw: String?, context: Context = .general) -> String {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return fallback(for: context) }

        let lower = text.lowercased()

        if isSessionExpired(lower) {
            return sessionExpired
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
        if looksLikePhoto(lower) {
            return photoLoadFailed
        }
        if looksLikeName(lower) {
            return nameRequired
        }
        if looksLikeTechnicalNoise(lower) {
            return fallback(for: context)
        }

        if text.count > 140 {
            return String(text.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return text
    }

    static func friendly(error: Error, context: Context = .general) -> String {
        if let api = error as? LimiAPIError {
            switch api {
            case .missingAuth:
                return sessionExpired
            case .httpStatus(let code, let message):
                if code == 401 || code == 403 {
                    return sessionExpired
                }
                return friendly(message ?? api.errorDescription, context: context)
            case .transport:
                return friendly(api.errorDescription, context: .network)
            default:
                return friendly(api.errorDescription, context: context)
            }
        }
        if let client = error as? LimiHTTPClientError {
            switch client {
            case .missingAuth:
                return sessionExpired
            case .invalidBody:
                return friendly(client.errorDescription, context: context)
            }
        }
        return friendly(error.localizedDescription, context: context)
    }

    static func kind(for message: String) -> DeviceProfileMessageKind {
        let lower = message.lowercased()
        if lower.contains("updated") || lower.contains("success") {
            return .success
        }
        if message == sessionExpired {
            return .error
        }
        return .error
    }

    static func isSessionExpiredMessage(_ message: String) -> Bool {
        message == sessionExpired || isSessionExpired(message.lowercased())
    }

    enum Context {
        case general
        case load
        case save
        case photo
        case network
    }

    private static func fallback(for context: Context) -> String {
        switch context {
        case .general: return "Something went wrong. Please try again."
        case .load: return loadFailed
        case .save: return saveFailed
        case .photo: return photoLoadFailed
        case .network: return "No internet connection. Check Wi‑Fi or mobile data, then try again."
        }
    }

    private static func isSessionExpired(_ lower: String) -> Bool {
        lower.contains("token expired")
            || lower.contains("jwt expired")
            || lower.contains("session expired")
            || lower.contains("session has expired")
            || lower.contains("no authentication token")
            || lower.contains("authentication required")
            || lower.contains("unauthorized")
            || lower.contains("not authenticated")
            || lower.contains("invalid token")
            || lower.contains("token not found")
            || lower.contains("missing token")
            || lower.contains("http 401")
            || (lower.contains("401") && lower.contains("token"))
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
            || lower.contains("502")
            || lower.contains("503")
            || lower.contains("504")
            || lower.contains("server error")
            || lower.contains("bad gateway")
            || lower.contains("service unavailable")
    }

    private static func looksLikePhoto(_ lower: String) -> Bool {
        lower.contains("photo") || lower.contains("image") || lower.contains("jpeg") || lower.contains("heic")
    }

    private static func looksLikeName(_ lower: String) -> Bool {
        lower.contains("valid name")
            || (lower.contains("username") && lower.contains("required"))
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
            || lower.contains("request failed (http")
            || lower.contains("{")
            || lower.contains("error_message")
    }
}
