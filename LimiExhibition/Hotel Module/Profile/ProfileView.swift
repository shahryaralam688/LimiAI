import SwiftUI
import UIKit
import SDWebImageSwiftUI

struct ProfileView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var isDarkMode = true
    @State private var showProfileEditView = false
    @State private var debugMessage: String = "Initializing..."
    @State private var showCongigurator = false
    @State private var showIFrameView = false
    @State private var navigateToLIMI = false
    @State private var showGetStartScreen = false
    @State private var showWebSiteView = false
    @State private var showRoomPlanScreen = false
    @Environment(\.dismiss) private var dismiss
    @State private var showLanguageSelector = false
    @State private var isChangingLanguage = false
    @State private var appeared = false

    @State private var showAIAppStore = false
    @State private var showAIConnection = false
    @State private var showAISetting = false
    @State private var showNotifications = false
    @State private var showPrivacyPolicy = false
    @State private var showloginView = false
    @State private var showLoginToast = false

    @StateObject private var roomCaptureController = RoomCaptureController()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"

    var body: some View {
        let imageURL = URL(string: userDataManager.userData?.profilePicture?.url ?? "")

        ZStack {
            DeepSpaceBackground(showParticles: false)

            VStack(spacing: 0) {
                LimiScreenHeader(title: "settings.title".localized) {
                    dismiss()
                }
                .padding(.bottom, 8)

                // Language
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orbGlow2.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "globe")
                            .foregroundColor(.orbGlow3)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.language".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text(LanguageSettings.currentLanguage() == .zhHant ? AppLanguage.zhHant.displayName : AppLanguage.en.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }

                    Spacer()

                    Button { showLanguageSelector = true } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.appTextMuted)
                            .font(.system(size: 14))
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 14, fillOpacity: 0.05)
                .padding(.horizontal, 20)
                .confirmationDialog("settings.language".localized, isPresented: $showLanguageSelector, titleVisibility: .visible) {
                    Button(AppLanguage.en.displayName) { applyLanguage(.en) }
                    Button(AppLanguage.zhHant.displayName) { applyLanguage(.zhHant) }
                    Button("Cancel", role: .cancel) {}
                }

                let role = AuthManager.shared.getRole()
                if role != "Installer User created" {
                    // Profile avatar
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            WebImage(url: imageURL) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.orbGlow1.opacity(0.15))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.orbGlow4)
                                            .font(.system(size: 32))
                                    )
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.orbGlow4.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: Color.orbGlow1.opacity(0.2), radius: 16)
                        }

                        let displayName = userDataManager.userData?.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "User"
                        Text(displayName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.top, 20)
                }

                // Options
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        let role = AuthManager.shared.getRole()
                        if role != "Installer User created" {
                            ProfileSection {
                                ProfileRow(icon: "person.crop.circle", title: "profile.edit".localized) {
                                    showProfileEditView = true
                                }
                            }
                        } else {
                            ProfileSection {
                                ProfileRow(icon: "person.crop.circle", title: "profile.login_better".localized) {
                                    showloginView = true
                                }
                            }
                        }

                        ProfileSection {
                            ProfileRow(icon: "ic_outline-assistant", title: "profile.ai_app_store".localized) {
                                if role == "Installer User created" { showLoginToast = true }
                                else { showAIAppStore = true }
                            }
                            ProfileRow(icon: "tabler_apps", title: "profile.ai_connections".localized) {
                                if role == "Installer User created" { showLoginToast = true }
                                else { showAIConnection = true }
                            }
                            ProfileRow(icon: "humbleicons_ai", title: "profile.ai_settings".localized) {
                                if role == "Installer User created" { showLoginToast = true }
                                else { showAISetting = true }
                            }
                        }

                        ProfileSection {
                            ProfileRow(icon: "bell", title: "profile.notifications".localized) {
                                showNotifications = true
                            }
                            ProfileRow(icon: "star", title: "profile.configurator".localized) {
                                showCongigurator = true
                            }
                            ProfileRow(icon: "RoomPlan", title: "profile.room_scan".localized) {
                                showRoomPlanScreen = true
                            }
                        }

                        ProfileSection {
                            ProfileRow(icon: "shield", title: "profile.privacy_security".localized) {
                                showPrivacyPolicy = true
                            }
                            ProfileRow(icon: "globe", title: "profile.our_website".localized) {
                                showWebSiteView = true
                            }
                        }

                        if role != "Installer User created" {
                            Button(action: {
                                AuthManager.shared.clearToken()
                                BluetoothManager.shared.disconnectAllDevices()
                                hasCompletedOnboarding = false
                                hasLaunchedBefore = false
                                demoEmail = ""
                                showGetStartScreen = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.appDanger)
                                    Text("profile.logout".localized)
                                        .foregroundColor(.appDanger)
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                }
                                .padding(16)
                                .glassCard(cornerRadius: 14, fillOpacity: 0.04)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(
            Group {
                if isChangingLanguage {
                    ZStack {
                        Color.appCanvasPrimary.opacity(0.6).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orbGlow4))
                            .scaleEffect(1.25)
                    }
                }
            }
        )
        .sheet(isPresented: $showImagePicker) { TheImagePicker(selectedImage: $selectedImage) }
        .sheet(isPresented: $showProfileEditView) { ProfileEditView() }
        .sheet(isPresented: $showCongigurator) { LimiContentView() }
        .sheet(isPresented: $showWebSiteView) { WebViewScreen(showWebView: $showWebSiteView) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showNotifications) { NotificationView() }
        .sheet(isPresented: $showAIAppStore) { AIAppStoreView() }
        .sheet(isPresented: $showAIConnection) { AIConnectionsView() }
        .fullScreenCover(isPresented: $showloginView) { SignInView() }
        .fullScreenCover(isPresented: $showRoomPlanScreen) {
            RoomPlanContentView().environment(roomCaptureController)
        }
        .overlay(
            ZStack {
                if showLoginToast {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { showLoginToast = false }

                    VStack(spacing: 16) {
                        Text("Please Login First")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                        Text("Please login before using this feature")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button(action: { showLoginToast = false }) {
                                Text("Close")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .glassCard(cornerRadius: 10, fillOpacity: 0.08)
                            }
                            Button(action: {
                                showLoginToast = false
                                showloginView = true
                            }) {
                                Text("Login")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .leading, endPoint: .trailing))
                                    )
                            }
                        }
                    }
                    .padding(24)
                    .glassCard(cornerRadius: 20, fillOpacity: 0.12)
                    .padding(24)
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isChangingLanguage = false
            }
        }
        .onAppear {
            userDataManager.refreshUserData()
        }
    }

    private func applyLanguage(_ lang: AppLanguage) {
        guard lang != LanguageSettings.currentLanguage() else { return }
        isChangingLanguage = true
        LanguageSettings.set(lang)
    }
}

// MARK: - Profile Section

private struct ProfileSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 1) {
            content
        }
        .glassCard(cornerRadius: 14, fillOpacity: 0.05)
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.orbGlow3)
                } else {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.orbGlow3)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Image Picker

struct TheImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: TheImagePicker
        init(_ parent: TheImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ProfileView()
}
