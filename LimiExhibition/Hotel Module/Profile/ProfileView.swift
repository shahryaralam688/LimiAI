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

    
    // AI Integration
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
        // Step 1: Compute URL outside ViewBuilder
        let imageURL = URL(string: userDataManager.userData?.profilePicture?.url ?? "")

        VStack(spacing: 20) {

            // MARK: Title
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image("Solid arrow right sm")
                        .foregroundColor(.alabaster)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.appInputFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .padding(.top)
                Text("settings.title".localized)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.themeWhite)
                    .padding(.top)
                Spacer()
            }
            
            .background(
                Rectangle()
                    .fill(Color.appSurfaceTertiary)
                    .frame(height: 114)
                    .cornerRadius(40)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.themeWhite)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.language".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.themeWhite)

                        Text(LanguageSettings.currentLanguage() == .zhHant ? AppLanguage.zhHant.displayName : AppLanguage.en.displayName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.themeWhite.opacity(0.7))
                    }

                    Spacer()

                    Button {
                        showLanguageSelector = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .padding(14)
                .background(Color.appSurfaceTertiary)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .confirmationDialog("settings.language".localized, isPresented: $showLanguageSelector, titleVisibility: .visible) {
                Button(AppLanguage.en.displayName) {
                    applyLanguage(.en)
                }
                Button(AppLanguage.zhHant.displayName) {
                    applyLanguage(.zhHant)
                }
                Button("Cancel", role: .cancel) {}
            }
            let role = AuthManager.shared.getRole()
            if role != "Installer User created" {
                // MARK: Profile Section
                VStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        
                        WebImage(url: imageURL) { img in
                            img
                                .resizable()
                                .scaledToFill()
                            //maybe need to create image here i think.
                        } placeholder: {
                            Circle() .fill(Color.gray.opacity(0.3)) .overlay( Image(systemName: "person.fill") .foregroundColor(.themeWhite) .font(.system(size: 40)) )
                        }
                        .resizable() // make it resizable
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    }
                    
                    // Display username with fallback
                    let displayName = userDataManager.userData?.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "User"
                    
                    Text(displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.themeWhite)
                        .onChange(of: userDataManager.userData) { oldValue, newValue in
                            print("📱 ProfileView - User data updated. Username: \(newValue?.username ?? "nil")")
                            debugMessage = "Last updated: \(Date())\nUsername: \(newValue?.username ?? "none")"
                        }
                }
                .padding(.top, 16)
            }
            // MARK: Options ScrollView
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    let role = AuthManager.shared.getRole()
                    if role != "Installer User created"{
                        // Section 1: Profile
                        VStack(spacing: 1) {
                            ProfileRow(icon: "person.crop.circle", title: "profile.edit".localized) {
                                showProfileEditView = true
                            }
                        }
                        .background(Color.appCanvasMuted)
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 1) {
                            ProfileRow(icon: "person.crop.circle", title: "profile.login_better".localized) {
                                showloginView = true
                            }
                        }
                        .background(Color.appCanvasMuted)
                        .cornerRadius(12)
                    }
                    // Section 2: AI
                    VStack(spacing: 1) {

                        ProfileRow(icon: "ic_outline-assistant", title: "profile.ai_app_store".localized) {
                            if role == "Installer User created" {
                                showLoginToast = true
                            } else {
                                showAIAppStore = true
                            }
                        }
                        ProfileRow(icon: "tabler_apps", title: "profile.ai_connections".localized) {
                            if role == "Installer User created" {
                                showLoginToast = true
                            } else {
                                showAIConnection = true
                            }
                        }
                        ProfileRow(icon: "humbleicons_ai", title: "profile.ai_settings".localized) {
                            if role == "Installer User created" {
                                showLoginToast = true
                            } else {
                                showAISetting = true
                            }
                        }
                    }
                    .background(Color.appSurfaceTertiary)
                    .cornerRadius(12)

                    // Section 3: Apps & Notifications
                    VStack(spacing: 1) {
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
                    .background(Color.appSurfaceTertiary)
                    .cornerRadius(12)

                    // Section 4: Privacy & Website
                    VStack(spacing: 1) {
                        ProfileRow(icon: "shield", title: "profile.privacy_security".localized) {
                            showPrivacyPolicy = true

                        }
                        ProfileRow(icon: "globe", title: "profile.our_website".localized) {
                            showWebSiteView = true
                        }
                    }
                    .background(Color.appSurfaceTertiary)
                    .cornerRadius(12)
                    
                    if role != "Installer User created"{
                        // Log Out Button
                        Button(action: {
                            AuthManager.shared.clearToken()
                            BluetoothManager.shared.disconnectAllDevices()
                            hasCompletedOnboarding = false
                            hasLaunchedBefore = false
                            demoEmail = ""
                            showGetStartScreen = true
                        }) {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .foregroundColor(Color.appDanger)
                                Text("profile.logout".localized)
                                    .foregroundColor(Color.appDanger)
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                            }
                            .padding()
                            .background(Color.appSurfaceTertiary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

        }
        .background(Color.themeBlack.ignoresSafeArea())
        .overlay(
            Group {
                if isChangingLanguage {
                    ZStack {
                        Color.themeBlack.opacity(0.45).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                            .scaleEffect(1.25)
                    }
                }
            }
        )
        .sheet(isPresented: $showImagePicker) {
            TheImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showProfileEditView) {
            ProfileEditView()
        }
        .sheet(isPresented: $showCongigurator) {
            LimiContentView()
        }
        .sheet(isPresented: $showWebSiteView) {
            WebViewScreen(showWebView: $showWebSiteView)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationView()
        }
        .sheet(isPresented: $showAIAppStore) { AIAppStoreView() }
        .sheet(isPresented: $showAIConnection) { AIConnectionsView() }
        .fullScreenCover(isPresented: $showloginView) { LoginSkipView() }
        .fullScreenCover(isPresented: $showRoomPlanScreen) { RoomPlanContentView().environment(roomCaptureController)
}
        .overlay(
            ZStack {
                if showLoginToast {
                    Color.themeBlack.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showLoginToast = false
                        }
                    
                    VStack(spacing: 16) {
                        Text("Please Login First")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.themeWhite)
                        
                        Text("Please login before using this feature")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                showLoginToast = false
                            }) {
                                Text("Close")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.themeWhite)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.appSurfaceTertiary)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                showLoginToast = false
                                showloginView = true
                            }) {
                                Text("Login")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.charlestonGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.emerald)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.appSurfaceTertiary)
                    .cornerRadius(16)
                    .padding(20)
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageDidChange)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isChangingLanguage = false
            }
        }
        .onAppear {
    print("🔄 ProfileView appeared, refreshing user data...")
    userDataManager.refreshUserData()
    
    // Debug view (can be removed later)
    let _ = print("🔍 Debug Info:")
    let _ = print("- User data exists:", userDataManager.userData != nil)
    let _ = print("- Username:", userDataManager.userData?.username ?? "Not set")
    let _ = print("- Profile image URL:", userDataManager.userData?.profilePicture?.url ?? "No image")
}
        
    }

    private func applyLanguage(_ lang: AppLanguage) {
        guard lang != LanguageSettings.currentLanguage() else { return }
        isChangingLanguage = true
        LanguageSettings.set(lang)
    }
}

// MARK: - Profile Row
private struct ProfileRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                        .resizable()
                        .foregroundColor(.alabaster)
                        .frame(width: 24, height: 24)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template) // allows foregroundColor to work
                        .foregroundColor(.alabaster)
                        .frame(width: 24, height: 24)
                        .aspectRatio(contentMode: .fit)
                }
                Text(title)
                    .foregroundColor(.alabaster)
                    .font(.system(size: 16))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .background(Color.appSurfaceTertiary)
    }
}

// MARK: - Image Picker
struct TheImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
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
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
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

// MARK: - Color Extension
//extension Color {
//    init(hex: String) {
//        let scanner = Scanner(string: hex)
//        _ = scanner.scanString("#")
//        var rgb: UInt64 = 0
//        scanner.scanHexInt64(&rgb)
//        let r = Double((rgb >> 16) & 0xFF) / 255.0
//        let g = Double((rgb >> 8) & 0xFF) / 255.0
//        let b = Double(rgb & 0xFF) / 255.0
//        self.init(red: r, green: g, blue: b)
//    }
//}

// MARK: - Preview
#Preview {
    ProfileView()
}
