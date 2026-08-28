//
//  DeviceProfileView.swift
//  LIMI AI Device
//
//  Native profile tab: account info + the device-control essentials
//  (control path, Bluetooth/Local Network status, permissions) that the
//  app needs to talk to LIMI hardware. Reuses the same backend as the
//  main app (UserDataManager + PATCH editProfile).
//
//  Home UI 1: neumorphic Soft UI. Other themes keep the system List.
//

import SwiftUI
import PhotosUI

struct DeviceProfileView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @ObservedObject private var transportPreference = TransportMediumPreferenceStore.shared
    @ObservedObject private var bluetoothManager = BluetoothManager.shared
    @ObservedObject private var bonjourBrowser = BonjourServiceBrowser.shared
    @ObservedObject private var homeUITheme = DeviceHomeUIThemeStore.shared

    @State private var showEditName = false
    @State private var nameInput = ""
    @State private var showSignOutConfirm = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingProfile = false
    @State private var profileErrorMessage: String?

    private var usesHomeUI1: Bool { homeUITheme.selected == .one }
    private var usesHomeUI2: Bool { homeUITheme.selected == .two }

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
            Group {
                if usesHomeUI1 {
                    homeUI1Body
                } else if usesHomeUI2 {
                    homeUI2Body
                } else {
                    systemListBody
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .homeUI1TabRootChrome(enabled: usesHomeUI1)
            .homeUI2TabRootChrome(enabled: usesHomeUI2)
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

    // MARK: - Home UI 1

    private var homeUI1Body: some View {
        ZStack {
            HomeUI1ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Profile",
                        subtitle: "Account, control path, and device permissions"
                    )
                    .padding(.top, 8)

                    homeUI1AccountCard
                    homeUI1DeviceControlCard
                    homeUI1PermissionsCard
                    homeUI1AboutCard
                    homeUI1SignOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Home UI 2

    private var homeUI2Body: some View {
        ZStack {
            HomeUI2ControlScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI2PageTitle(
                        title: "Settings",
                        subtitle: "Account, control path, and device permissions"
                    )
                    .padding(.top, 8)

                    homeUI2AccountCard
                    homeUI2DeviceControlCard
                    homeUI2PermissionsCard
                    homeUI2AboutCard
                    homeUI2SignOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private var homeUI2AccountCard: some View {
        HomeUI2ControlSectionCard(
            title: "Account",
            footer: isGuestInstaller
                ? "Guests can browse, but a LIMI account is needed to manage your Wi-Fi devices."
                : nil
        ) {
            HStack(spacing: 14) {
                homeUI2Avatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(HomeUI2Type.title(18))
                        .foregroundStyle(HomeUI2Color.textPrimary)
                    Text(isGuestInstaller ? "Guest session" : "LIMI account")
                        .font(HomeUI2Type.caption(12))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                }

                Spacer(minLength: 8)

                if isSavingProfile || userDataManager.isLoading {
                    ProgressView()
                        .tint(HomeUI2Color.accent)
                }
            }

            if isGuestInstaller {
                HomeUI2ActionRow(
                    title: "Sign in with an account",
                    systemImage: "person.crop.circle.badge.plus"
                ) {
                    AuthManager.shared.clearToken()
                    AuthManager.shared.clearRole()
                }
            } else {
                HomeUI2ActionRow(
                    title: "Edit Name",
                    systemImage: "pencil",
                    isEnabled: !isSavingProfile
                ) {
                    nameInput = displayName
                    showEditName = true
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HomeUI2ActionRowLabel(title: "Change Photo", systemImage: "photo")
                }
                .buttonStyle(.plain)
                .disabled(isSavingProfile)
                .opacity(isSavingProfile ? 0.45 : 1)
            }
        }
    }

    private var homeUI2Avatar: some View {
        Group {
            if let image = userDataManager.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HomeUI2Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HomeUI2Color.surfaceRaised)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().stroke(HomeUI2Color.border, lineWidth: 1))
    }

    private var homeUI2DeviceControlCard: some View {
        HomeUI2ControlSectionCard(
            title: "Device Control",
            footer: transportPreference.preference == .automatic
                ? "The app picks MQTT, LAN, or Bluetooth automatically for each command. Cloud connection is required for remote control."
                : "Testing mode — commands always use \(transportPreference.preference.shortTitle)."
        ) {
            HomeUI2ControlConnectionBanner()

            VStack(alignment: .leading, spacing: 10) {
                Text("Control Path")
                    .font(HomeUI2Type.body(13))
                    .foregroundStyle(HomeUI2Color.textSecondary)

                HStack(spacing: 8) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        let selected = transportPreference.preference == medium
                        Button {
                            DeviceAppGuidance.lightImpact()
                            transportPreference.preference = medium
                        } label: {
                            Text(medium.shortTitle)
                                .font(HomeUI2Type.body(12))
                                .foregroundStyle(
                                    selected
                                        ? HomeUI2Color.textOnAccent
                                        : HomeUI2Color.textSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: HomeUI2Radius.sm, style: .continuous)
                                        .fill(selected ? HomeUI2Color.accent : HomeUI2Color.surfaceRaised)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(medium.pickerTitle)
                    }
                }
            }

            HomeUI2InsetRow {
                HStack {
                    Text("Devices Found")
                        .font(HomeUI2Type.body(15))
                        .foregroundStyle(HomeUI2Color.textPrimary)
                    Spacer()
                    Text("\(onlineDeviceCount) online")
                        .font(HomeUI2Type.caption(13))
                        .foregroundStyle(HomeUI2Color.accent)
                }
            }
        }
    }

    private var homeUI2PermissionsCard: some View {
        HomeUI2ControlSectionCard(
            title: "Permissions",
            footer: "Bluetooth and Local Network access are required to find and control LIMI devices. Manage them in Settings."
        ) {
            HomeUI2InsetRow {
                HStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(HomeUI2Color.canvas)
                        )

                    Text("Bluetooth")
                        .font(HomeUI2Type.body(15))
                        .foregroundStyle(HomeUI2Color.textPrimary)

                    Spacer()

                    HomeUI2StatusBadge(
                        on: bluetoothManager.isBluetoothOn,
                        onText: "On",
                        offText: "Off"
                    )
                }
            }

            HomeUI2ActionRow(
                title: "Open App Settings",
                systemImage: "gear"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var homeUI2AboutCard: some View {
        HomeUI2ControlSectionCard(title: "About") {
            HomeUI2InsetRow {
                HStack {
                    Text("Version")
                        .font(HomeUI2Type.body(15))
                        .foregroundStyle(HomeUI2Color.textPrimary)
                    Spacer()
                    Text(appVersionText)
                        .font(HomeUI2Type.caption(13))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                }
            }
        }
    }

    private var homeUI2SignOutButton: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            Text("Sign Out")
                .font(HomeUI2Type.body(16))
                .foregroundStyle(Color.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .homeUI2Card(cornerRadius: HomeUI2Radius.sm, fill: HomeUI2Color.surface)
        }
        .buttonStyle(.plain)
    }

    private var homeUI1AccountCard: some View {
        HomeUI1ControlSectionCard(
            title: "Account",
            footer: isGuestInstaller
                ? "Guests can browse, but a LIMI account is needed to manage your Wi-Fi devices."
                : nil
        ) {
            HStack(spacing: 14) {
                homeUI1Avatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(HomeUI1Type.title(18))
                        .foregroundStyle(HomeUI1Color.textPrimary)
                    Text(isGuestInstaller ? "Guest session" : "LIMI account")
                        .font(HomeUI1Type.caption(12))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }

                Spacer(minLength: 8)

                if isSavingProfile || userDataManager.isLoading {
                    ProgressView()
                        .tint(HomeUI1Color.accentGreen)
                }
            }

            if isGuestInstaller {
                homeUI1ActionRow(
                    title: "Sign in with an account",
                    systemImage: "person.crop.circle.badge.plus"
                ) {
                    AuthManager.shared.clearToken()
                    AuthManager.shared.clearRole()
                }
            } else {
                homeUI1ActionRow(
                    title: "Edit Name",
                    systemImage: "pencil",
                    isEnabled: !isSavingProfile
                ) {
                    nameInput = displayName
                    showEditName = true
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    homeUI1ActionRowLabel(
                        title: "Change Photo",
                        systemImage: "photo"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSavingProfile)
                .opacity(isSavingProfile ? 0.45 : 1)
            }
        }
    }

    private var homeUI1Avatar: some View {
        Group {
            if let image = userDataManager.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HomeUI1Color.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HomeUI1Color.canvas)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .homeUI1CircleElevation(.recessed)
    }

    private var homeUI1DeviceControlCard: some View {
        HomeUI1ControlSectionCard(
            title: "Device Control",
            footer: transportPreference.preference == .automatic
                ? "The app picks MQTT, LAN, or Bluetooth automatically for each command. Cloud connection is required for remote control."
                : "Testing mode — commands always use \(transportPreference.preference.shortTitle)."
        ) {
            HomeUI1ControlConnectionBanner()

            VStack(alignment: .leading, spacing: 10) {
                Text("Control Path")
                    .font(HomeUI1Type.body(13))
                    .foregroundStyle(HomeUI1Color.textSecondary)

                HStack(spacing: 8) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        let selected = transportPreference.preference == medium
                        Button {
                            DeviceAppGuidance.lightImpact()
                            transportPreference.preference = medium
                        } label: {
                            Text(medium.shortTitle)
                                .font(HomeUI1Type.body(12))
                                .foregroundStyle(
                                    selected
                                        ? HomeUI1Color.accentGreen
                                        : HomeUI1Color.textSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .homeUI1Elevation(
                                    selected ? .recessed : .one,
                                    cornerRadius: HomeUI1Radius.nav,
                                    fill: HomeUI1Color.surface
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(medium.pickerTitle)
                    }
                }
            }

            HStack {
                Text("Devices Found")
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                Spacer()
                Text("\(onlineDeviceCount) online")
                    .font(HomeUI1Type.caption(13))
                    .foregroundStyle(HomeUI1Color.accentGreen)
            }
            .padding(14)
            .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
        }
    }

    private var homeUI1PermissionsCard: some View {
        HomeUI1ControlSectionCard(
            title: "Permissions",
            footer: "Bluetooth and Local Network access are required to find and control LIMI devices. Manage them in Settings."
        ) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HomeUI1Color.textSecondary)
                    .frame(width: 36, height: 36)
                    .homeUI1CircleElevation(.one)

                Text("Bluetooth")
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)

                Spacer()

                homeUI1StatusBadge(
                    on: bluetoothManager.isBluetoothOn,
                    onText: "On",
                    offText: "Off"
                )
            }
            .padding(14)
            .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)

            homeUI1ActionRow(
                title: "Open App Settings",
                systemImage: "gear"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var homeUI1AboutCard: some View {
        HomeUI1ControlSectionCard(title: "About") {
            HStack {
                Text("Version")
                    .font(HomeUI1Type.body(15))
                    .foregroundStyle(HomeUI1Color.textPrimary)
                Spacer()
                Text(appVersionText)
                    .font(HomeUI1Type.caption(13))
                    .foregroundStyle(HomeUI1Color.textSecondary)
            }
            .padding(14)
            .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
        }
    }

    private var homeUI1SignOutButton: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            Text("Sign Out")
                .font(HomeUI1Type.body(16))
                .foregroundStyle(HomeUI1Color.accentRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .homeUI1Elevation(.two, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
        }
        .buttonStyle(.plain)
    }

    private func homeUI1ActionRow(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            DeviceAppGuidance.lightImpact()
            action()
        } label: {
            homeUI1ActionRowLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func homeUI1ActionRowLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeUI1Color.textSecondary)
                .frame(width: 36, height: 36)
                .homeUI1CircleElevation(.one)

            Text(title)
                .font(HomeUI1Type.body(15))
                .foregroundStyle(HomeUI1Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HomeUI1Color.textSecondary.opacity(0.55))
        }
        .padding(14)
        .homeUI1Elevation(.one, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.surface)
    }

    private func homeUI1StatusBadge(on: Bool, onText: String, offText: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(on ? HomeUI1Color.accentGreen : HomeUI1Color.shadowDark)
                .frame(width: 8, height: 8)
            Text(on ? onText : offText)
                .font(HomeUI1Type.caption(12))
                .foregroundStyle(HomeUI1Color.textSecondary)
        }
    }

    // MARK: - System (non–Home UI 1)

    private var systemListBody: some View {
        List {
            accountSection
            deviceControlSection
            permissionsSection
            aboutSection
            signOutSection
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
        VirtualDeviceStore.shared.resetForSignOut()
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
