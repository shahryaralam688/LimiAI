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
    @State private var bannerMessage: String?
    @State private var bannerKind: DeviceProfileMessageKind = .error
    @State private var showSessionExpiredConfirm = false

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

    private var activeBannerMessage: String? {
        if let bannerMessage { return bannerMessage }
        if let raw = userDataManager.errorMessage {
            return DeviceProfileMessaging.friendly(raw, context: .load)
        }
        return nil
    }

    private var activeBannerKind: DeviceProfileMessageKind {
        if bannerMessage != nil { return bannerKind }
        if userDataManager.errorMessage != nil { return .error }
        return .error
    }

    private var bannerNeedsSignIn: Bool {
        guard let message = activeBannerMessage else { return false }
        return DeviceProfileMessaging.isSessionExpiredMessage(message)
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
                await reloadProfile(showSuccess: false)
            }
        }
        .onAppear {
            if !isGuestInstaller {
                userDataManager.refreshUserData()
            }
        }
        .onChange(of: userDataManager.errorMessage) { _, raw in
            guard let raw, !raw.isEmpty else { return }
            presentBanner(
                DeviceProfileMessaging.friendly(raw, context: .load),
                kind: .error
            )
        }
        .alert("Edit Name", isPresented: $showEditName) {
            TextField("Your name", text: $nameInput)
            Button("Save") { saveProfile(username: nameInput, image: nil) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This name is shown on your LIMI account.")
        }
        .confirmationDialog("Sign out of LIMI AI Device?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Session expired",
            isPresented: $showSessionExpiredConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign In Again", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DeviceProfileMessaging.sessionExpired)
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

            DeviceProfileVerticalScroll {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI1PageTitle(
                        title: "Profile",
                        subtitle: "Account, control path, and device permissions"
                    )
                    .padding(.top, 8)

                    profileStatusBanner

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

            DeviceProfileVerticalScroll {
                VStack(alignment: .leading, spacing: 18) {
                    HomeUI2PageTitle(
                        title: "Settings",
                        subtitle: "Account, control path, and device permissions"
                    )
                    .padding(.top, 8)

                    profileStatusBanner

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

                HStack(spacing: 6) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        let selected = transportPreference.preference == medium
                        Button {
                            DeviceAppGuidance.lightImpact()
                            transportPreference.preference = medium
                        } label: {
                            Text(medium.chipTitle)
                                .font(HomeUI2Type.body(12))
                                .foregroundStyle(
                                    selected
                                        ? HomeUI2Color.textOnAccent
                                        : HomeUI2Color.textSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 4)
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
                .frame(maxWidth: .infinity)
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

                HStack(spacing: 6) {
                    ForEach(TransportMediumPreference.allCases, id: \.self) { medium in
                        let selected = transportPreference.preference == medium
                        Button {
                            DeviceAppGuidance.lightImpact()
                            transportPreference.preference = medium
                        } label: {
                            Text(medium.chipTitle)
                                .font(HomeUI1Type.body(12))
                                .foregroundStyle(
                                    selected
                                        ? HomeUI1Color.accentGreen
                                        : HomeUI1Color.textSecondary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 4)
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
                .frame(maxWidth: .infinity)
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

            NavigationLink {
                BLEMacProbeTestView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "ladybug")
                        .foregroundStyle(HomeUI1Color.accentGreen)
                    Text("BLE MAC Probe (Test)")
                        .font(HomeUI1Type.body(15))
                        .foregroundStyle(HomeUI1Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeUI1Color.textSecondary)
                }
                .padding(14)
                .homeUI1Elevation(.recessed, cornerRadius: HomeUI1Radius.md, fill: HomeUI1Color.canvas)
            }
            .buttonStyle(.plain)
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
            if let message = activeBannerMessage {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(activeBannerKind == .success ? .green : .primary)

                        HStack(spacing: 12) {
                            if bannerNeedsSignIn {
                                Button("Sign In Again") { showSessionExpiredConfirm = true }
                                    .buttonStyle(.borderedProminent)
                            } else if activeBannerKind == .error {
                                Button("Try Again") {
                                    Task { await reloadProfile(showSuccess: true) }
                                }
                            }
                            Button("Dismiss") { clearBanner() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

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

            NavigationLink {
                BLEMacProbeTestView()
            } label: {
                Label("BLE MAC Probe (Test)", systemImage: "ladybug")
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
        clearBanner()
        userDataManager.errorMessage = nil
        VirtualDeviceStore.shared.resetForSignOut()
        AuthManager.shared.clearToken()
        AuthManager.shared.clearRole()
        BluetoothManager.shared.disconnectAllDevices()
    }

    // MARK: - Status banner

    @ViewBuilder
    private var profileStatusBanner: some View {
        if let message = activeBannerMessage {
            DeviceNeumorphicStatusBanner(
                message: message,
                kind: signInKind(from: activeBannerKind),
                retryTitle: bannerNeedsSignIn
                    ? "Sign In Again"
                    : (activeBannerKind == .error ? "Try Again" : nil),
                onRetry: {
                    if bannerNeedsSignIn {
                        showSessionExpiredConfirm = true
                    } else {
                        Task { await reloadProfile(showSuccess: true) }
                    }
                },
                onDismiss: { clearBanner() }
            )
        }
    }

    private func signInKind(from kind: DeviceProfileMessageKind) -> DeviceSignInMessageKind {
        switch kind {
        case .info: return .info
        case .success: return .success
        case .error: return .error
        }
    }

    private func presentBanner(_ message: String, kind: DeviceProfileMessageKind) {
        bannerMessage = message
        bannerKind = kind
        if kind == .error {
            DeviceAppGuidance.warningNotification()
        } else if kind == .success {
            DeviceAppGuidance.successNotification()
        }
    }

    private func clearBanner() {
        bannerMessage = nil
        userDataManager.errorMessage = nil
    }

    private func reloadProfile(showSuccess: Bool) async {
        clearBanner()
        guard !isGuestInstaller else { return }
        guard AuthManager.shared.getToken() != nil else {
            presentBanner(DeviceProfileMessaging.sessionExpired, kind: .error)
            return
        }
        await userDataManager.fetchUserData()
        if let raw = userDataManager.errorMessage {
            presentBanner(DeviceProfileMessaging.friendly(raw, context: .load), kind: .error)
        } else if showSuccess {
            presentBanner("Profile loaded.", kind: .success)
        }
    }

    // MARK: - Profile update (same PATCH editProfile endpoint as the main app)

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    photoItem = nil
                    presentBanner(DeviceProfileMessaging.photoLoadFailed, kind: .error)
                }
                return
            }
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    photoItem = nil
                    presentBanner(DeviceProfileMessaging.photoLoadFailed, kind: .error)
                }
                return
            }
            guard data.count < 8_000_000 else {
                await MainActor.run {
                    photoItem = nil
                    presentBanner("That photo is too large. Choose a smaller image.", kind: .error)
                }
                return
            }
            await MainActor.run {
                photoItem = nil
                saveProfile(username: displayName, image: image)
            }
        } catch {
            await MainActor.run {
                photoItem = nil
                presentBanner(
                    DeviceProfileMessaging.friendly(error: error, context: .photo),
                    kind: .error
                )
            }
        }
    }

    private func saveProfile(username: String, image: UIImage?) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            presentBanner(DeviceProfileMessaging.nameRequired, kind: .error)
            return
        }
        guard !isGuestInstaller else {
            presentBanner("Sign in with a LIMI account to update your profile.", kind: .error)
            return
        }
        guard AuthManager.shared.getToken() != nil else {
            presentBanner(DeviceProfileMessaging.sessionExpired, kind: .error)
            return
        }
        guard !isSavingProfile else { return }

        isSavingProfile = true
        clearBanner()
        Task {
            do {
                try await patchProfile(username: trimmedUsername, image: image)
                await MainActor.run {
                    isSavingProfile = false
                    userDataManager.userData?.username = trimmedUsername
                    if let image { userDataManager.profileImage = image }
                    presentBanner(DeviceProfileMessaging.successSaved, kind: .success)
                }
                await userDataManager.fetchUserData()
                if let raw = userDataManager.errorMessage {
                    await MainActor.run {
                        // Save succeeded; keep a soft load warning if refresh fails.
                        presentBanner(
                            DeviceProfileMessaging.friendly(raw, context: .load),
                            kind: .error
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    let friendly = DeviceProfileMessaging.friendly(error: error, context: .save)
                    presentBanner(friendly, kind: .error)
                    if DeviceProfileMessaging.isSessionExpiredMessage(friendly) {
                        showSessionExpiredConfirm = true
                    }
                }
            }
        }
    }

    private func patchProfile(username: String, image: UIImage?) async throws {
        guard let url = URL(string: APIConstants.editProfile) else {
            throw LimiAPIError.invalidURL
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

        if let image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw LimiAPIError.invalidBody
            }
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
            throw LimiAPIError.from(httpStatus: response.statusCode, data: data)
        }
    }
}

/// Vertical-only page scroll. Pins content to the container width so
/// Control Path chips and neumorphic shadows cannot rubber-band sideways
/// (reproduced on iPhone 17 Pro Max; Home already stays vertical).
private struct DeviceProfileVerticalScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .frame(width: geo.size.width, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .clipped()
        }
    }
}

#Preview {
    DeviceProfileView()
}
