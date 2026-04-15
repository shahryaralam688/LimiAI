//
//  WebView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//



import SwiftUI
import WebKit

// MARK: - WebView Component
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - WebView Screen Component
struct WebViewScreen: View {
    @Binding var showWebView: Bool
    let websiteURL = URL(string: AppURLs.Web.mainWebsite)!
    @State private var isLoading = true
    @State private var loadingProgress = 0.0
    @State private var animateShimmer = false

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(url: websiteURL)
                
                // Enhanced loading indicator with animation
                if isLoading {
                    ZStack {
                        // Background blur
                        Color.themeBlack.opacity(0.05)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            // Animated logo placeholder
                            ZStack {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.eton.opacity(0.3), Color.eton.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(loadingProgress))
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.eton, Color.eton.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut, value: loadingProgress)
                                
                                Image(systemName: "globe")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.eton)
                            }
                            
                            Text("Loading Shop...")
                                .font(.headline)
                                .foregroundColor(.appTextInverse)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.themeWhite.opacity(0.9))
                                        .shadow(color: Color.themeBlack.opacity(0.05), radius: 5, x: 0, y: 3)
                                )
                                // Shimmer effect
                                .overlay(
                                    GeometryReader { geometry in
                                        Color.themeWhite.opacity(0.3)
                                            .frame(width: 30)
                                            .blur(radius: 10)
                                            .rotationEffect(.degrees(30))
                                            .offset(x: animateShimmer ? geometry.size.width : -geometry.size.width)
                                            .animation(
                                                Animation.linear(duration: 1.5)
                                                    .repeatForever(autoreverses: false),
                                                value: animateShimmer
                                            )
                                    }
                                    .mask(
                                        Text("Loading Shop...")
                                            .font(.headline)
                                            .foregroundColor(.themeWhite)
                                    )
                                    .onAppear {
                                        animateShimmer = true
                                    }
                                )
                        }
                    }
                    .onAppear {
                        // Simulate loading progress
                        withAnimation(.easeInOut(duration: 2.5)) {
                            loadingProgress = 1.0
                        }
                        
                        // Simulate loading time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                isLoading = false
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Shop", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LimiBackButton { showWebView = false }
                }
            }
        }
    }
}
