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
        guard let token = AuthManager.shared.getToken() else {
            await MainActor.run {
                self.errorMessage = "No authentication token found"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let userData = try await performFetchUserData(token: token)
            await MainActor.run {
                self.userData = userData
                self.isLoading = false
                ContextManager.shared.updateHomeUserDisplayName(userData.username)
            }
            
            // Load profile image
            if let imageUrl = URL(string: userData.profilePicture?.url ?? "") {
                await loadProfileImage(from: imageUrl)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func performFetchUserData(token: String) async throws -> UserData {
        guard let url = URL(string: APIConstants.userData) else {
            let error = URLError(.badURL)
            print("❌ Invalid URL: \(APIConstants.userData)")
            throw error
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")
        print("🔑 Making request to: \(url.absoluteString)")
        print("🔑 Using token: \(token.prefix(10))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = URLError(.badServerResponse)
                print("❌ Invalid server response")
                throw error
            }
            
            print("📡 Response Status Code: \(httpResponse.statusCode)")
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Raw Response: \(responseString)")
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                let error = NSError(
                    domain: "UserDataError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                print("❌ API Error (\(httpResponse.statusCode)): \(errorMessage)")
                throw error
            }
            
            let userDataResponse = try JSONDecoder().decode(UserDataResponse.self, from: data)
            print("✅ Successfully decoded user data")
            return userDataResponse.data
            
        } catch {
            print("❌ Failed to fetch user data: \(error.localizedDescription)")
            throw error
        }
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
        } catch {
            print("❌ Failed to load profile image:", error)
        }
    }
    
    func refreshUserData() {
        Task {
            await fetchUserData()
        }
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
}
