//
//  DeviceProfileView.swift
//  LIMI AI Device
//
//  Native profile tab: account info + the device-control essentials
//  (control path, Bluetooth/Local Network status, permissions) that the
//  app needs to talk to LIMI hardware. Reuses the same backend as the
//  main app (UserDataManager + PATCH editProfile).
//

import SwiftUI
import PhotosUI

struct DeviceProfileView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @ObservedObject private var transportPreference = TransportMediumPreferenceStore.shared
    @ObservedObject private var bluetoothManager = BluetoothManager.shared
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared

    @State private var showEditName = false
    @State private var nameInput = ""
    @State private var showSignOutConfirm = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingProfile = false
    @State private var profileErrorMessage: String?

    private var isGuestInstaller: Bool {
        AuthManager.shared.getRole() == "Installer User created"
    }

    private var displayName: String {
        let name = userDataManager.userData?.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return isGuestInstaller ? "Guest" : "User"
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                deviceControlSection
                permissionsSection
                aboutSection
                signOutSection
            }
            .navigationTitle("Profile")
            .refreshable {
                await userDataManager.fetchUserData()
            }
        }
        .onAppear {
            if !isGuestInstaller {
                userDataManager.refreshUserData()
            }
        }
        .alert("Edit Name", isPresented: $showEditName) {
            TextField("Your name", text: $nameInput)
            Button("Save") { saveProfile(username: nameInput, image: nil) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This name is shown on your LIMI account.")
        }
        .alert(
            "Profile Update Failed",
            isPresented: Binding(
                get: { profileErrorMessage != nil },
                set: { if !$0 { profileErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profileErrorMessage ?? "")
        }
        .confirmationDialog("Sign out of LIMI AI Device?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { signOut() }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await uploadPickedPhoto(item) }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.headline)
                    Text(isGuestInstaller ? "Guest session" : "LIMI account")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSavingProfile || userDataManager.isLoading {
                    ProgressView()
                }
            }
            .padding(.vertical, 4)

            if isGuestInstaller {
                Button {
                    // Back to sign-in so the guest can use a real account.
                    AuthManager.shared.clearToken()
                    AuthManager.shared.clearRole()
                } label: {
                    Label("Sign in with an account", systemImage: "person.crop.circle.badge.plus")
                }
            } else {
                Button {
                    nameInput = displayName
                    showEditName = true
                } label: {
                    Label("Edit Name", systemImage: "pencil")
                }
                .disabled(isSavingProfile)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo")
                }
                .disabled(isSavingProfile)
            }
        } header: {
            Text("Account")
        } footer: {
            if isGuestInstaller {
                Text("Guests can browse, but a LIMI account is needed to manage your Wi-Fi devices.")
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = userDataManager.profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
    }

    // MARK: - Device control essentials

    private var deviceControlSection: some View {
        Section {
            DeviceConnectionBanner()

            Picker("Control Path", selection: $transportPreference.preference) {
                ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                    Text(medium.pickerTitle).tag(medium)
                }
            }

            LabeledContent("Devices Found") {
                Text("\(onlineDeviceCount) online")
            }
        } header: {
            Text("Device Control")
        } footer: {
            Text(transportPreference.preference == .automatic
                 ? "The app picks MQTT, LAN, or Bluetooth automatically for each command. Cloud connection is required for remote control."
                 : "Testing mode — commands always use \(transportPreference.preference.shortTitle).")
        }
    }

    private var onlineDeviceCount: Int {
        bonjourBrowser.discoveredWiFiDevices
            .filter { LimiDeviceNaming.isAllowedDeviceName($0.name) && $0.reachability == .online }
            .count
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            LabeledContent {
                statusBadge(on: bluetoothManager.isBluetoothOn,
                            onText: "On", offText: "Off")
            } label: {
                Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open App Settings", systemImage: "gear")
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Bluetooth and Local Network access are required to find and control LIMI devices. Manage them in Settings.")
        }
    }

    private func statusBadge(on: Bool, onText: String, offText: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(on ? DeviceTheme.accent : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            Text(on ? onText : offText)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersionText)
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Sign out

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                showSignOutConfirm = true
            }
        }
    }

    private func signOut() {
        AuthManager.shared.clearToken()
        AuthManager.shared.clearRole()
        BluetoothManager.shared.disconnectAllDevices()
    }

    // MARK: - Profile update (same PATCH editProfile endpoint as the main app)

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            profileErrorMessage = "Couldn't load the selected photo."
            return
        }
        saveProfile(username: displayName, image: image)
    }

    private func saveProfile(username: String, image: UIImage?) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            profileErrorMessage = "Please enter a valid name."
            return
        }

        isSavingProfile = true
        Task {
            do {
                try await patchProfile(username: trimmedUsername, image: image)
                await MainActor.run {
                    isSavingProfile = false
                    userDataManager.userData?.username = trimmedUsername
                    if let image { userDataManager.profileImage = image }
                }
                await userDataManager.fetchUserData()
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    profileErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func patchProfile(username: String, image: UIImage?) async throws {
        guard let url = URL(string: APIConstants.editProfile) else {
            throw URLError(.badURL)
        }
        guard var request = LimiHTTPClient.buildRequest(url: url, method: "PATCH", contentType: nil) else {
            throw LimiHTTPClientError.missingAuth
        }
        request.timeoutInterval = 30

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"username\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(username)\r\n".data(using: .utf8)!)

        if let image, let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"profilePicture\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await LimiHTTPClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error occurred"
            throw NSError(
                domain: "ProfileUpdateError",
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

#Preview {
    DeviceProfileView()
}
