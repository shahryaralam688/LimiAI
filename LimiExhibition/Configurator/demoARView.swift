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
    @Environment(\.presentationMode) var presentationMode
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
//                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
//                        
//                        ARCardView(title: "Living Room Light", downloadId: "68b982e1055416029b04a849", isOnline: true)
//                            .tag(1)
//                            .scaleEffect(currentPage == 1 ? 1.0 : 0.92)
//                            .opacity(currentPage == 1 ? 1.0 : 0.85)
//                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
//                        
//                        ARCardView(title: "Bedroom Lamp", downloadId: "68a2ec211a23b5bf01c7f9e5", isOnline: true)
//                            .tag(2)
//                            .scaleEffect(currentPage == 2 ? 1.0 : 0.92)
//                            .opacity(currentPage == 2 ? 1.0 : 0.85)
//                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
//                    } else {
                        ARCardView(title: "My Device", downloadId: "mount1", isOnline: false)
                            .tag(0)
                            .scaleEffect(currentPage == 0 ? 1.0 : 0.92)
                            .opacity(currentPage == 0 ? 1.0 : 0.85)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
                        
                        ARCardView(title: "Living Room Light", downloadId: "mount2", isOnline: false)
                            .tag(1)
                            .scaleEffect(currentPage == 1 ? 1.0 : 0.92)
                            .opacity(currentPage == 1 ? 1.0 : 0.85)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
                        
                        ARCardView(title: "Bedroom Lamp", downloadId: "mount3", isOnline: false)
                            .tag(2)
                            .scaleEffect(currentPage == 2 ? 1.0 : 0.92)
                            .opacity(currentPage == 2 ? 1.0 : 0.85)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentPage)
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
        .background(Color.themeBlack)
        .ignoresSafeArea()
    }
}

import SwiftUI

struct ARCardView: View {
    var imageName: String = "Frame-2" // Replace with your image asset
    var title: String = "Device Name"
    var downloadId = "downloadID"
    var isOnline: Bool = true
    @State private var showCustomView = false
    @State private var isLoading = false

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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.themeWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtitle
                Text("State of the art AR Experience")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.appTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 16)
                
                // MARK: - Experience Now Button
                Button(action: {
                    if isOnline {
                        downloadUSDZUsingAPI(downloadId: downloadId)
                    } else {
                        showCustomView = true
                    }
                }) {
                    Text("Experience Now")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.appTextInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.themeWhite)
                        .cornerRadius(26)
                }
                .disabled(isLoading)
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

        if isLoading {
            Color.themeBlack.opacity(0.5)
                .ignoresSafeArea()

            ProgressView("Loading 3D Model...")
                .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                .foregroundColor(.themeWhite)
        }
        }
    }
    private func downloadUSDZUsingAPI(downloadId: String) {
        guard let url = URL(string: APIConstants.webConfiguratorDownload(downloadId)) else {
            print("❌ Invalid download URL")
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
        }

        let fileManager = FileManager.default

        // Get custom app document directory (persistent storage)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator")

        // Ensure folder exists
        if !fileManager.fileExists(atPath: configuratorFolderURL.path) {
            do {
                try fileManager.createDirectory(at: configuratorFolderURL, withIntermediateDirectories: true)
                print("✅ Configurator folder created at: \(configuratorFolderURL.path)")
            } catch {
                print("❌ Failed to create folder: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
        }

        // File path for this model
        let fileURL = configuratorFolderURL.appendingPathComponent("\(downloadId).usdz")

        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            print("✅ Model already exists at: \(fileURL.path), skipping download")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isLoading = false
                self.showCustomView = true
            }
            return
        }

        // Proceed to download since file doesn't exist
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Download error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            guard let data = data else {
                print("❌ No data in response")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                try data.write(to: fileURL)
                print("✅ Model saved at: \(fileURL.path)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isLoading = false
                    self.showCustomView = true
                }

            } catch {
                print("❌ Save error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }

        task.resume()
    }

}





#Preview{
    DemoARView()
}
