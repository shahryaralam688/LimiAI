//
//  UserDataResponse.swift
//  Limi
//
//  Created by Mac Mini on 17/06/2025.
//


//
//  UserDataManager.swift
//  Limi
//
//  Created by Mac Mini on 17/06/2025.
//

import Foundation
import SwiftUI

// MARK: - User Data Models
struct UserDataResponse: Codable {
    let success: Bool
    let data: UserData
}

struct UserData: Codable, Equatable {
    var username: String?
    let profilePicture: ProfilePicture?
}

struct ProfilePicture: Codable, Equatable {
    let url: String?
    let publicId: String?
    
    enum CodingKeys: String, CodingKey {
        case url
        case publicId = "public_id"
    }
}

// MARK: - User Data Manager
class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published var userData: UserData?
    @Published var profileImage: UIImage?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private init() {}
    
    func fetchUserData() async {
        guard AuthManager.shared.getToken() != nil else {
            await MainActor.run {
                self.errorMessage = "Your session has expired. Please sign in again."
                self.isLoading = false
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let userData = try await performFetchUserData()
            await MainActor.run {
                self.userData = userData
                self.isLoading = false
                self.errorMessage = nil
                ContextManager.shared.updateHomeUserDisplayName(userData.username)
            }

            if let imageUrl = URL(string: userData.profilePicture?.url ?? "") {
                await loadProfileImage(from: imageUrl)
            }

        } catch {
            await MainActor.run {
                self.errorMessage = Self.friendlyFetchError(error)
                self.isLoading = false
            }
        }
    }

    private static func friendlyFetchError(_ error: Error) -> String {
        if let api = error as? LimiAPIError {
            switch api {
            case .missingAuth:
                return "Your session has expired. Please sign in again."
            case .httpStatus(let code, let message):
                if code == 401 || code == 403 {
                    return "Your session has expired. Please sign in again."
                }
                let lower = (message ?? "").lowercased()
                if lower.contains("token expired")
                    || lower.contains("jwt expired")
                    || lower.contains("invalid token")
                    || lower.contains("unauthorized") {
                    return "Your session has expired. Please sign in again."
                }
                if let message, !message.isEmpty {
                    return message
                }
                return "Couldn't load your profile. Please try again."
            case .transport:
                return "No internet connection. Check Wi‑Fi or mobile data, then try again."
            default:
                return api.errorDescription ?? "Couldn't load your profile. Please try again."
            }
        }
        let lower = error.localizedDescription.lowercased()
        if lower.contains("token expired")
            || lower.contains("unauthorized")
            || lower.contains("401") {
            return "Your session has expired. Please sign in again."
        }
        return error.localizedDescription
    }
    
    private func performFetchUserData() async throws -> UserData {
        let data = try await LimiHTTPClient.get(urlString: APIConstants.userData)
        let userDataResponse = try LimiHTTPClient.decode(UserDataResponse.self, from: data)
        return userDataResponse.data
    }
    
//    private func loadProfileImage(from url: URL) async {
//        do {
//            let (data, _) = try await URLSession.shared.data(from: url)
//            if let image = UIImage(data: data) {
//                await MainActor.run {
//                    self.profileImage = image
//                }
//            }
//        } catch {
//            print("Failed to load profile image: \(error.localizedDescription)")
//        }
//    }
    
    @MainActor
    func loadProfileImage(from url: URL) async {
        let urlString = url.absoluteString

        if let cached = ImageCache.shared.image(for: urlString) {
            self.profileImage = cached
            return // ✅ already cached, no need to fetch again
        }

        // 🚀 Download fresh image if not cached
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.set(image, for: urlString)
                self.profileImage = image
            }
        } catch { /* ignored */ }
    }
    
    func refreshUserData() {
        Task {
            await fetchUserData()
        }
    }

    func resetForSignOut() {
        userData = nil
        profileImage = nil
        isLoading = false
        errorMessage = nil
        ImageCache.shared.clearAll()
    }
}


final class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private var cache: [String: UIImage] = [:]

    func image(for url: String) -> UIImage? {
        return cache[url]
    }

    func set(_ image: UIImage, for url: String) {
        cache[url] = image
    }

    func clear(for url: String) {
        cache.removeValue(forKey: url)
    }

    func clearAll() {
        cache.removeAll()
    }
}
