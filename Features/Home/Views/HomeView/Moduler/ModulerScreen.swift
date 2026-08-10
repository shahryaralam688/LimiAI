//
//  ModulerScreen.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 21/11/2025.
//

//
//  NotificationView 2.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 20/11/2025.
//



import SwiftUI

struct ModulerView: View {
    @Environment(\.dismiss) private var dismiss
    let onBack: () -> Void = {}
    @State private var showModuleActionMenu: Bool = false
    @State private var selectedModule: Module? = nil

    @ObservedObject var modulesManager = ModulesManager.shared
    @State private var showToast: Bool = false
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            LimiModuleSubtitle(text: "Browse and install home modules")

            HStack{
                Text("Installed Modules")
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Spacer()
            }.padding(.bottom)
            // MARK: Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Module Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(modulesManager.modules) { module in
                            ModuleCard(
                                module: module,
                                onAddTapped: {
                                    modulesManager.toggleModuleStatus(for: module.id)
                                },
                                onMoreTapped: {
                                    selectedModule = module
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        showModuleActionMenu = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .limiFloatingOrbClearance()
            }
            HStack {
                Spacer()
                LimiPillButton(title: "Install Modules") {
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showToast = false
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .limiScreenBackground()
        .overlay {

            if showModuleActionMenu, let activeModule = selectedModule {
                ZStack {
                    // Dark overlay background
                    Color.appOverlayScrimLight
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                showModuleActionMenu = false
                                selectedModule = nil
                            }
                        }

                    // Popup menu
                    VStack(spacing: 0) {
                        VStack(spacing: 8) {
                            Text(activeModule.title)
                                .font(LimiTypography.button)
                                .foregroundColor(.appTextPrimary)
                                .multilineTextAlignment(.center)
                                .tracking(-0.3)

                            Text("What would you like to do?")
                                .font(LimiTypography.footnote)
                                .foregroundColor(Color.appTextPrimary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .tracking(-0.2)
                        }
                        .padding(.top, 18)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                        Divider()
                            .background(Color.appGlassFillMedium)

                        // Install / Uninstall Button
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                modulesManager.toggleModuleStatus(for: activeModule.id)
                            }
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                showModuleActionMenu = false
                                selectedModule = nil
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(LimiTypography.button)
                                    .foregroundColor(.appTextPrimary)

                                Text(activeModule.status == .addModule ? "Install" : "Uninstall")
                                    .font(LimiTypography.callout)
                                    .foregroundColor(.appTextPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                        }

                        Divider()
                            .background(Color.appGlassFillMedium)

                        // Later Button
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                showModuleActionMenu = false
                                selectedModule = nil
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark")
                                    .font(LimiTypography.button)
                                    .foregroundColor(.appTextPrimary)

                                Text("Close")
                                    .font(LimiTypography.callout)
                                    .foregroundColor(.appTextPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                        }
                    }
                    .background(
                        Color.appSurfacePrimary
                            .opacity(0.8)
                            .shadow(color: Color.appOverlayScrim, radius: 20, x: 0, y: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.appBorderPrimary, lineWidth: 4) // ← 1-point border
                            )
                    )
                    .cornerRadius(24)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))

                }
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showModuleActionMenu)
                .zIndex(5)
            }
        }
        .overlay {

            if showToast {
                ZStack {
                    // Dark overlay background
                    Color.themeBlack.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    // Toast message
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(LimiTypography.button)
                                .foregroundColor(.appTextPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exciting Updates Coming!")
                                    .font(LimiTypography.callout)
                                    .foregroundColor(.appTextPrimary)
                                
                                Text("New modules with amazing features are on the way.")
                                    .font(LimiTypography.footnote)
                                    .foregroundColor(Color.appTextPrimary.opacity(0.75))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.appSurfaceSecondaryAlt,
                                    Color.appSurfacePrimary
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.themeWhite.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.themeWhite.opacity(0.2), radius: 12, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showToast)
            }
        }
        .limiModalNavigationBar(title: "Modules", onClose: {
            onBack()
            dismiss()
        })
        }
        .trackScreen("ModulerView", metadata: ["surface": "home_modules"])
    }
}

// MARK: Module Card
struct ModuleCard: View {
    let module: Module
    let onAddTapped: () -> Void
    let onMoreTapped: () -> Void

    @State private var isAnimating = false
    @State private var isLoadingInstalled = false
    @State private var showInstalledStatus = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(module.icon)
                    .font(LimiTypography.title2)
                    .foregroundColor(.brandHighlight)
                
                Spacer()
                Button(action: {
                    onMoreTapped()
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                }
            }
            
            Text(module.title)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
            
            Spacer()
            
            if module.status == .addModule {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isAnimating = true
                        }
                        onAddTapped()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isAnimating = false
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            
                            Image(systemName: "plus.circle")
                                .font(LimiTypography.callout)
                                .foregroundColor(Color.appBorderSoft)
                            
                            Text("Install")
                                .font(LimiTypography.footnote)
                                .foregroundColor(Color.appBorderSoft)
                            
                        }
                        .foregroundColor(Color.appCanvasMuted)
                        
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 360)
                                .stroke(Color.appBorderSoft, lineWidth: 2) // ← 1-point border
                        )
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))

                    }
                    .scaleEffect(isAnimating ? 0.95 : 1.0)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            } else {
                HStack {
                    Spacer()
                    if isLoadingInstalled {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    } else if showInstalledStatus {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(LimiTypography.callout)
                                .foregroundColor(Color.appBorderSoft)
                            Text("Installed")
                                .font(LimiTypography.footnote)
                                .foregroundColor(Color.appBorderSoft)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 128)
        .padding(16)
        .limiPanel(cornerRadius: 16)
        .onAppear {
            if module.status != .addModule {
                isLoadingInstalled = false
                showInstalledStatus = true
            }
        }
        .onChange(of: module.status) { newStatus in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
            }

            if newStatus != .addModule {
                isLoadingInstalled = true
                showInstalledStatus = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoadingInstalled = false
                    showInstalledStatus = true
                }
            } else {
                isLoadingInstalled = false
                showInstalledStatus = false
            }
        }

    }
}
#Preview {
    ModulerView()
}
