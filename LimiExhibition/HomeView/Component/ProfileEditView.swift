//
//  ProfileEditView.swift
//  Limi
//
//  Created by Mac Mini on 17/06/2025.
//

import SwiftUI
import PhotosUI
import SDWebImageSwiftUI

struct ProfileEditView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var username: String = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    // Animation states
    @State private var welcomeTextOffset: CGFloat = 100
    @State private var welcomeTextOpacity: Double = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
//                Color.backgroundColor
//                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        
                        Image("logoSplash")
                            .resizable()
                            .frame(width: 120, height: 100)
                            .padding(.bottom, 40)
                            .offset(y: welcomeTextOffset)
                            .opacity(welcomeTextOpacity)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    welcomeTextOffset = 0
                                    welcomeTextOpacity = 1.0
                                }
                            }
                            .shadow(color: Color.alabaster.opacity(0.5), radius: 4, x: 0, y: 5)
                        // Header Section with Profile Image
                        profileImageSection
                            .padding(.top, 32)
                            .padding(.bottom, 40)
                        
                        // Form Section
                        VStack(spacing: 24) {
                            usernameInputSection
                            updateButtonSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await refreshUserData()
                }
            }
//            .navigationTitle("Edit Profile").bold(true).foregroundColor(.alabaster)
            .navigationBarTitleDisplayMode(.inline)
            .background(
                Color.themeBlack
//
//                LinearGradient(
//                                gradient: Gradient(colors: [
//                                    Color.charlestonGreen, // Eton
//
//                                    Color.alabaster  // Alabaster
//                                ]),
//                                startPoint: .top,
//                                endPoint: .bottom
//                )
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.alabaster)
                    .font(.system(size: 16, weight: .medium))
                }
                
                ToolbarItem(placement: .keyboard) {
                    if isTextFieldFocused {
                        HStack {
                            Spacer()
                            Button("Done") {
                                isTextFieldFocused = false
                            }
                            .foregroundColor(.primaryAccent)
                            .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .onChange(of: selectedImage) { newItem in
            Task {
                await loadSelectedImage(newItem)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
            .foregroundColor(.charlestonGreen)
        } message: {
            Text(alertMessage)
                .foregroundColor(.charlestonGreen)
        }
        .background(
            Color.clear
                .contentShape(Rectangle()) // Make the background tappable
                .onTapGesture {
                    isTextFieldFocused = false
                }
        )
    }
    
    // MARK: - View Components
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if let profileImage = profileImage {
                    // Selected image from PhotosPicker
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Use remote URL or fallback
                    WebImage(url: URL(string: userDataManager.userData?.profilePicture?.url ?? "")) { img in
                        img
                            .resizable()
                            .scaledToFill()
                        //maybe need to create image here i think.
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.alabaster.opacity(0.3), Color.alabaster.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.charlestonGreen.opacity(0.6))
                            )
                    }
                        .scaledToFill()
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.alabaster, Color.emerald]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            .shadow(color: Color.alabaster.opacity(0.2), radius: 10, x: 0, y: 5)

            PhotosPicker(selection: $selectedImage, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 14, weight: .medium))
                    Text("Change Photo")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.alabaster)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.charlestonGreen.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.alabaster.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    
    private var usernameInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Username")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.alabaster)
                
                Spacer()
                
                if !username.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.emerald)
                        .font(.system(size: 16))
                }
            }
            
            HStack {
                Image(systemName: "at")
                    .foregroundColor(.charlestonGreen)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                
                TextField("Enter your username", text: $username)
                    .focused($isTextFieldFocused)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.charlestonGreen)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .onSubmit {
                        isTextFieldFocused = false
                    }
                
                if !username.isEmpty {
                    Button(action: { username = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isTextFieldFocused ? Color.charlestonGreen : Color.gray.opacity(0.2),
                                lineWidth: isTextFieldFocused ? 2 : 1
                            )
                    )
            )
            .shadow(color: Color.themeBlack.opacity(0.05), radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
        }
    }
    
    private var updateButtonSection: some View {
        Button(action: updateProfile) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text(isLoading ? "Updating Profile..." : "Update Profile")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.alabaster)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        Color.emerald
//                        isButtonDisabled
//                            ? AnyShapeStyle(Color.gray.opacity(0.4))
//                            : AnyShapeStyle(
//                                LinearGradient(
//                                    gradient: Gradient(colors: [Color.charlestonGreen, Color.emerald]),
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                              )
                    )
            )
//            .shadow(
//                color: isButtonDisabled ? Color.alabaster : Color.emerald,
//                radius: 8,
//                x: 0,
//                y: 4
//            )
            .scaleEffect(isLoading ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .disabled(isButtonDisabled)
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var isButtonDisabled: Bool {
        isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Methods
    
    private func loadExistingData() {
        if let userData = userDataManager.userData {
            username = userData.username ?? "Guest"
        }
        
        if userDataManager.userData == nil {
            Task {
                await userDataManager.fetchUserData()
                await MainActor.run {
                    if let userData = userDataManager.userData {
                        username = userData.username ?? "Guest"
                    }
                }
            }
        }
    }
    
    private func refreshUserData() async {
        await userDataManager.refreshUserData()
        await MainActor.run {
            if let userData = userDataManager.userData {
                username = userData.username ?? "Guest"
            }
        }
    }
    
    private func loadSelectedImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    profileImage = image
                }
            }
        } catch {
            await MainActor.run {
                showError(title: "Image Error", message: "Failed to load selected image")
            }
        }
    }
    
    private func updateProfile() {
        isTextFieldFocused = false
        
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            showError(title: "Invalid Input", message: "Please enter a valid username")
            return
        }
        
        guard let token = authManager.getToken() else {
            showError(title: "Authentication Error", message: "Please log in again")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await uploadProfile(username: trimmedUsername, image: profileImage, token: token)
                await MainActor.run {
                    isLoading = false
                    showSuccess(title: "Success", message: "Profile updated successfully!")

                    // Instantly update local data
                    self.userDataManager.userData?.username = trimmedUsername
                    if let updatedImage = profileImage {
                        userDataManager.profileImage = updatedImage
                    }

                    // Force server refresh (await to complete)
                    Task {
                        await userDataManager.fetchUserData()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError(title: "Update Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func uploadProfile(username: String, image: UIImage?, token: String) async throws {
        guard let url = URL(string: APIConstants.editProfile) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add username field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"username\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(username)\r\n".data(using: .utf8)!)
        
        // Add profile picture if available
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"profilePicture\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error occurred"
            throw NSError(
                domain: "ProfileUpdateError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
    }
    
    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
    
}
// MARK: - Custom Button Style

//struct ScaleButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
//            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
//    }
//}

#Preview {
    ProfileEditView()
}
