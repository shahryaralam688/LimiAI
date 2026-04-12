//
//  PortalWebView.swift
//  Limi
//
//  Created by Mac Mini on 04/07/2025.
//

import SwiftUI
import WebKit
import UIKit

class LightConfigManager {
    static let shared = LightConfigManager()
    var lightType: String = ""
    var downloadId: String = ""
    private init() {}
}

struct PortalWebView: View {
    enum TabType {
        case presets, custom
    }
    
    @State private var selectedTab: TabType = .presets
    @State private var showCustomView = false
    @State private var lightType: String = "Placeholder"
    @State private var downloadId: String = "686d23da93bc73cdc3a280ca"
    @State private var isLoading = false
    @State private var showWebViewContainer = false
    @State private var didCheckLightConfigs = false
    @State private var isOffline = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showDemoARView = false

    var body: some View {
        ZStack {
            VStack {
            // Header Section
            ZStack {
                Rectangle()
                    .fill(Color.appSurfaceSecondary)
                    .cornerRadius(32)
                    .frame(height: 124)
                
                HStack(alignment: .bottom, spacing: 16) {
                    // Back Button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("Solid arrow right sm")
                            .foregroundColor(.alabaster)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color.appInputFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Title and Subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AR Experience")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.themeWhite)
                        
                        Text("Login to experience more features")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
            }
                // Tab View
                HStack(spacing: 0) {
                    // Presets Tab
                    Button(action: {
                        selectedTab = .presets
                    }) {
                        Text("Presets")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == .presets ? .themeWhite : Color(white: 0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Group {
                                    if selectedTab == .presets {
                                        Color(white: 0.16)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Custom Tab
                    Button(action: {
                        selectedTab = .custom
                    }) {
                        Text("Custom")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == .custom ? .themeWhite : Color(white: 0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Group {
                                    if selectedTab == .custom {
                                        Color(white: 0.16)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(4)
                .background(Color(white: 0.09))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(white: 0.18), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                VStack {
                    if selectedTab == .presets {
                        DemoARView()
                            .ignoresSafeArea()
                    } else {
                        NavigationView {
                            ZStack(alignment: .topLeading) {
                                VStack {
                                    if isOffline {
                                        ZStack {
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    Color.themeBlack.opacity(0.95),
                                                    Color.themeBlack.opacity(0.6),
                                                    Color.themeBlack.opacity(0.0)
                                                ]),
                                                center: .center,
                                                startRadius: 10,
                                                endRadius: 260
                                            )
                                            .blur(radius: 12)

                                            VStack(spacing: 24) {
                                                HStack(spacing: 8) {
                                                    Text("No Designs Yet")
                                                        .font(.system(size: 22, weight: .semibold))
                                                        .foregroundColor(.themeWhite)

                                                    Image(systemName: "info.circle")
                                                        .font(.system(size: 18, weight: .regular))
                                                        .foregroundColor(Color.themeWhite.opacity(0.8))
                                                }

                                                Button(action: {
                                                    // Open offline AR demo
                                                    isOffline = false
                                                    showWebViewContainer = true
                                                }) {
                                                    Text("Open Configurator")
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.themeWhite)
                                                        .padding(.horizontal, 40)
                                                        .padding(.vertical, 14)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                                .fill(Color.themeBlack.opacity(0.9))
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                                .stroke(Color.themeWhite.opacity(0.12), lineWidth: 1)
                                                        )
                                                }
                                            }
                                            .padding(40)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else if showWebViewContainer {
                                        DemoARView()
                                            .ignoresSafeArea()
                                    
                                    } else {
                                        WebViewContainer(
                                            showCustomView: $showCustomView,
                                            lightType: $lightType,
                                            downloadId: $downloadId,
                                            isLoading: $isLoading,
                                            isOffline: $isOffline
                                        )
                                        .navigationBarTitleDisplayMode(.inline)
                                        .ignoresSafeArea()
                                    }
                                }

                            }
                        }
                    }
                }
            }

            // Blurred loading overlay
            if isLoading {
                ZStack {
                    VisualEffectBlur(blurStyle: .systemMaterial)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .charlestonGreen))
                        Text("Loading...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .zIndex(1)
            }
        }
        .background(Color.themeBlack)
        .ignoresSafeArea(edges: [.top, .bottom])
        .onAppear {
            checkLightConfigs()
        }
        .fullScreenCover(isPresented: $showCustomView) {
            CustomView(
                lightType: LightConfigManager.shared.lightType,
                downloadId: LightConfigManager.shared.downloadId,
                showCustomView: $showCustomView, card: Card(
                                    imageName: ["chairFront", "chairSide", "chairBack"],
                                    title: "Placeholder",
                                    price: 49,
                                    description: lightType,
                                    objectName: downloadId,
                                    size: "22 x 22 x 22",
                                    color: "red"
                                )
                

            )
            .ignoresSafeArea()
        }

    }
}

extension PortalWebView {
    private func checkLightConfigs() {
        guard let url = URL(string: APIConstants.lightConfigsCheck) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthManager.shared.getToken() {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            var shouldShow = false
            defer {
                DispatchQueue.main.async {
                    self.showWebViewContainer = shouldShow
                    self.didCheckLightConfigs = true
                }
            }

            guard error == nil, let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let arr = json as? [Any] {
                shouldShow = arr.isEmpty
            }
        }.resume()
    }
}

struct WebViewContainer: UIViewRepresentable {
    @Binding var showCustomView: Bool
    @Binding var lightType: String
    @Binding var downloadId: String
    @Binding var isLoading: Bool
    @Binding var isOffline: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        let hideHeaderFooterScript = """
        function hideHeaderFooter() {
            const headers = document.querySelectorAll('header, .header, #header, nav, .nav, #nav');
            headers.forEach(element => element.style.display = 'none');
            const footers = document.querySelectorAll('footer, .footer, #footer');
            footers.forEach(element => element.style.display = 'none');
            const specificElements = document.querySelectorAll('.site-header, .site-footer, .main-nav');
            specificElements.forEach(element => element.style.display = 'none');
        }
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', hideHeaderFooter);
        } else {
            hideHeaderFooter();
        }
        setTimeout(hideHeaderFooter, 1000);
        setTimeout(hideHeaderFooter, 3000);
        """
        userContentController.addUserScript(WKUserScript(source: hideHeaderFooterScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        let buttonHandlerScript = """
        function handleButtonClick() {
            const button = document.getElementById('openCustomView');
            if (button) {
                button.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    window.webkit.messageHandlers.buttonClicked.postMessage('openCustomView');
                });
            }
            const buttons = document.querySelectorAll('.portal-button, [data-action=\"openCustomView\"]');
            buttons.forEach(btn => {
                btn.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    window.webkit.messageHandlers.buttonClicked.postMessage('openCustomView');
                });
            });
        }
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', handleButtonClick);
        } else {
            handleButtonClick();
        }
        setTimeout(handleButtonClick, 1000);
        setTimeout(handleButtonClick, 3000);
        """
        userContentController.addUserScript(WKUserScript(source: buttonHandlerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        userContentController.add(context.coordinator, name: "buttonClicked")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let token = AuthManager.shared.getToken(),
           let url = URL(string: AppURLs.Web.arPortal(token: token)) {
            
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebViewContainer
        var showCustomView: Binding<Bool>
        var lightType: Binding<String>
        var downloadId: Binding<String>
        var isLoading: Binding<Bool>
        var isOffline: Binding<Bool>

        init(_ parent: WebViewContainer) {
            self.parent = parent
            self.showCustomView = parent.$showCustomView
            self.lightType = parent.$lightType
            self.downloadId = parent.$downloadId
            self.isLoading = parent.$isLoading
            self.isOffline = parent.$isOffline
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "buttonClicked" {
                if let spanID = message.body as? String {
                    print("🟢 Span ID: \(spanID)")
                    fetchLightConfig(for: spanID)
                }
            }
        }

        private func fetchLightConfig(for spanID: String) {
            let urlString = APIConstants.lightConfig(spanID)
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let extractedLightType = json["light_type"] as? String ?? "Unknown"
                    let extractedDownloadId = json["download_Id"] as? String ?? ""

                    LightConfigManager.shared.lightType = extractedLightType
                    LightConfigManager.shared.downloadId = extractedDownloadId
                    
                    print("this is the ID:\(extractedLightType)")

                    DispatchQueue.main.async {
                        self.lightType.wrappedValue = extractedLightType
                        self.downloadId.wrappedValue = extractedDownloadId
                    }

                    if !extractedDownloadId.isEmpty {
                        self.downloadUSDZUsingAPI(downloadId: extractedDownloadId)
                    }
                }
            }
            task.resume()
        }

        private func downloadUSDZUsingAPI(downloadId: String) {
            guard let url = URL(string: APIConstants.webConfiguratorDownload(downloadId)) else {
                print("❌ Invalid download URL")
                return
            }

            DispatchQueue.main.async {
                self.isLoading.wrappedValue = true
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
                        self.isLoading.wrappedValue = false
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
                    self.isLoading.wrappedValue = false
                    self.showCustomView.wrappedValue = true
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
                        self.isLoading.wrappedValue = false
                    }
                    return
                }

                guard let data = data else {
                    print("❌ No data in response")
                    DispatchQueue.main.async {
                        self.isLoading.wrappedValue = false
                    }
                    return
                }

                do {
                    try data.write(to: fileURL)
                    print("✅ Model saved at: \(fileURL.path)")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.isLoading.wrappedValue = false
                        self.showCustomView.wrappedValue = true
                    }

                } catch {
                    print("❌ Save error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading.wrappedValue = false
                    }
                }
            }

            task.resume()
        }


        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isOffline.wrappedValue = false
            }
            let script = """
            function setupButtonListeners() {
                const buttons = document.querySelectorAll('button');
                buttons.forEach((btn) => {
                    btn.addEventListener('click', function(event) {
                        if (btn.id === 'open_id') {
                            const spanChild = btn.querySelector('span');
                            if (spanChild && spanChild.id) {
                                window.webkit.messageHandlers.buttonClicked.postMessage(spanChild.id);
                            }
                        }
                    }, { once: true });
                });
            }
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupButtonListeners);
            } else {
                setupButtonListeners();
            }
            setTimeout(setupButtonListeners, 1000);
            setTimeout(setupButtonListeners, 3000);
            """
            webView.evaluateJavaScript(script)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadError(error)
        }

        private func handleLoadError(_ error: Error) {
            DispatchQueue.main.async {
                self.isOffline.wrappedValue = true
                self.isLoading.wrappedValue = false
            }
        }
    }
}

import SwiftUI

struct CustomView: View {
    let lightType: String
    let downloadId: String
    @Binding var showCustomView: Bool
    let card: Card
    var body: some View {
        ZStack {
            // Your AR View
            ARContainerWithOverlay(card: Card(
                imageName: ["chairFront", "chairSide", "chairBack"],
                title: "Placeholder",
                price: 49,
                description: lightType,
                objectName: downloadId,
                size: "22 x 22 x 22",
                color: "red"
            ))
            .onAppear {
                print("🟢 CustomView appeared with downloadId: \(downloadId)")
                print("🟢 CustomView appeared with lightType: \(lightType)")
            }

//            VStack {
//                Spacer()
//
//                // Bottom Overlay
//                ARModelList()
//                    .padding(.bottom, 20)
//            }
        }
        .frame(maxWidth: .infinity)

    }
}




struct PortalWebView_Previews: PreviewProvider {
    static var previews: some View {
        PortalWebView()
    }
}
