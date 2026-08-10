//
//  demoARView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 13/11/2025.
//

import SwiftUI

struct DemoARView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 1
    @StateObject private var networkMonitor = NetworkMonitor()

    
    var body: some View {
        VStack(spacing: 24) {


            
            Spacer(minLength: 12)
            
            // Carousel Section
            VStack(spacing: 16) {
                TabView(selection: $currentPage) {
//                    if networkMonitor.isConnected {
//                        ARCardView(title: "My Device", downloadId: "68b8cb4d055416029b04a78c", isOnline: true)
//                            .tag(0)
//                            .scaleEffect(currentPage == 0 ? 1.0 : 0.92)
//                            .opacity(currentPage == 0 ? 1.0 : 0.85)
//                            .animation(LimiMotion.quick, value: currentPage)
//                        
//                        ARCardView(title: "Living Room Light", downloadId: "68b982e1055416029b04a849", isOnline: true)
//                            .tag(1)
//                            .scaleEffect(currentPage == 1 ? 1.0 : 0.92)
//                            .opacity(currentPage == 1 ? 1.0 : 0.85)
//                            .animation(LimiMotion.quick, value: currentPage)
//                        
//                        ARCardView(title: "Bedroom Lamp", downloadId: "68a2ec211a23b5bf01c7f9e5", isOnline: true)
//                            .tag(2)
//                            .scaleEffect(currentPage == 2 ? 1.0 : 0.92)
//                            .opacity(currentPage == 2 ? 1.0 : 0.85)
//                            .animation(LimiMotion.quick, value: currentPage)
//                    } else {
                        ARCardView(title: "My Device", downloadId: "mount1", isOnline: false)
                            .tag(0)
                            .scaleEffect(currentPage == 0 ? 1.0 : 0.92)
                            .opacity(currentPage == 0 ? 1.0 : 0.85)
                            .animation(LimiMotion.quick, value: currentPage)
                        
                        ARCardView(title: "Living Room Light", downloadId: "mount2", isOnline: false)
                            .tag(1)
                            .scaleEffect(currentPage == 1 ? 1.0 : 0.92)
                            .opacity(currentPage == 1 ? 1.0 : 0.85)
                            .animation(LimiMotion.quick, value: currentPage)
                        
                        ARCardView(title: "Bedroom Lamp", downloadId: "mount3", isOnline: false)
                            .tag(2)
                            .scaleEffect(currentPage == 2 ? 1.0 : 0.92)
                            .opacity(currentPage == 2 ? 1.0 : 0.85)
                            .animation(LimiMotion.quick, value: currentPage)
//                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 520)
                
                // Custom Page Indicators
                HStack(alignment: .center, spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        if index == currentPage {
                            Capsule()
                                .fill(Color.themeWhite)
                                .frame(width: 28, height: 8)
                                .opacity(1.0)
                        } else {
                            Circle()
                                .fill(Color.appSurfaceField)
                                .frame(width: 8, height: 8)
                                .opacity(0.6)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.bottom, 32)
        .limiScreenBackground()
        .onAppear {
            ContextManager.shared.updateContext(
                screen: "DemoARView",
                metadata: ["surface": "ar_presets_carousel", "carousel_index": "\(currentPage)"]
            )
        }
        .onChange(of: currentPage) { _, page in
            ContextManager.shared.updateContext(
                screen: "DemoARView",
                metadata: ["surface": "ar_presets_carousel", "carousel_index": "\(page)"]
            )
        }
    }
}

struct ARCardView: View {
    var imageName: String = "Frame-2"
    var title: String = "Device Name"
    var downloadId = "downloadID"
    var isOnline: Bool = true
    @State private var showCustomView = false
    @StateObject private var configuratorViewModel = ConfiguratorViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            
            // MARK: - Top Image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 323)
                .frame(maxWidth: .infinity)
                .clipped()

            // MARK: - Content Section
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(title)
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtitle
                Text("State of the art AR Experience")
                    .font(LimiTypography.body)
                    .foregroundColor(Color.appTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 16)
                
                // MARK: - Experience Now Button
                Button(action: {
                    if isOnline {
                        configuratorViewModel.handleSnapId(downloadId) {
                            showCustomView = true
                        }
                    } else {
                        showCustomView = true
                    }
                }) {
                    Text("Experience Now")
                        .font(LimiTypography.button)
                        .foregroundColor(.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LimiGradients.cta)
                        .clipShape(Capsule(style: .continuous))
                }
                .tapScale()
                .disabled(configuratorViewModel.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.vertical, 20)
        }
        .background(Color.appSurfaceFloating)
        .cornerRadius(32)
        .shadow(color: Color.themeBlack.opacity(0.4), radius: 18, x: 0, y: 8)
        .frame(height: 449)
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $showCustomView) {
            CustomView(
                lightType: "ceiling",
                downloadId: downloadId,
                showCustomView: $showCustomView, card: Card(
                    imageName: ["chairFront", "chairSide", "chairBack"],
                    title: "Placeholder",
                    price: 49,
                    description: "ceiling",
                    objectName: "CeilingPendant",
                    size: "22 x 22 x 22",
                    color: "red"
                )
                
            )
            .ignoresSafeArea()
        }

        if configuratorViewModel.isLoading {
            Color.appOverlayScrim
                .ignoresSafeArea()

            ProgressView("Loading 3D Model...")
                .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                .foregroundColor(.appTextPrimary)
        }
        }
    }
}





#Preview{
    DemoARView()
}
