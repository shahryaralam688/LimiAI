//
//  LimiWebView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 24/11/2025.
//


import SwiftUI
@preconcurrency import WebKit
import ARKit

struct LimiWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    // Backward-compatible initializer (no loading binding required)
    init(url: URL) {
        self.url = url
        self._isLoading = .constant(false)
    }

    // Designated initializer with loading binding
    init(url: URL, isLoading: Binding<Bool>) {
        self.url = url
        self._isLoading = isLoading
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()

        // Mobile viewport and positioning fixes
        let mobileFixesJS = """
        // Set mobile viewport
        var viewport = document.querySelector('meta[name="viewport"]');
        if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
        }
        viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        
        // Hide header/footer and fix positioning
        var style = document.createElement('style');
        style.innerHTML = `
            header, footer { display: none !important; }
            body {
                margin: 0 !important;
                padding: 0 !important;
                overflow-x: hidden !important;
                position: fixed !important;
                width: 100vw !important;
                height: 100vh !important;
                top: 0 !important;
                left: 0 !important;
            }
            html {
                margin: 0 !important;
                padding: 0 !important;
                overflow: hidden !important;
                height: 100% !important;
                width: 100% !important;
            }
            * {
                -webkit-overflow-scrolling: touch !important;
            }
        `;
        document.head.appendChild(style);
        """

        // JS for logging and hydration fallback
        let consoleLoggerJS = """
        console.log = function(message) {
            window.webkit.messageHandlers.logger.postMessage("JS LOG: " + message);
        };
        window.onerror = function(msg, url, line, col, error) {
            window.webkit.messageHandlers.logger.postMessage("JS ERROR: " + msg + " at line: " + line);
            if ((msg && msg.toLowerCase().includes("hydration")) || (msg && msg.toLowerCase().includes("react"))) {
                if (!window.__reloadOnce) {
                    window.__reloadOnce = true;
                    setTimeout(() => { location.reload(); }, 500);
                }
            }
        };
        """

        contentController.addUserScript(WKUserScript(source: mobileFixesJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(source: consoleLoggerJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        contentController.add(context.coordinator, name: "logger")

        // Create configuration with separate process pool
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.processPool = WKProcessPool()

        // Improve GPU + network rendering
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        
        // Mobile positioning and scroll fixes
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Appearance fixes
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"

        // Load
        isLoading = true
        print("[WebView] Loading URL: \(url.absoluteString)")
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private var isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("[WebView JS Console] \(message.body)")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame == nil {
                print("[WebView] Intercepted navigation with no targetFrame. Forcing load.")
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[WebView] Started loading...")
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[WebView] Finished loading")
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[WebView] Navigation failed: \(error.localizedDescription)")
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[WebView] Failed provisional load: \(error.localizedDescription)")
            isLoading.wrappedValue = false
        }

        // Handle alert, confirm etc. if JS uses it
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("[WebView] JS Alert: \(message)")
            completionHandler()
        }
    }
}


struct LimiContentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToARPortal = false
    @State private var showNoLiDARAlert = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if let token = AuthManager.shared.getToken(),
                   let url = URL(string: AppURLs.Web.configurator(token: token)) {
                    LimiWebView(url: url)
                        .ignoresSafeArea(.all)
                } else if let url = URL(string: AppURLs.Web.configurator()) {
                    LimiWebView(url: url)
                        .ignoresSafeArea(.all)
                }
                HStack{
                    // 🔙 Back Button
                    LimiBackButton { dismiss() }

                    // 🟩 ARKit Button
                    Button(action: {
                        // Check LiDAR / Scene Depth support before opening the AR portal
                        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) ||
                           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                            navigateToARPortal = true
                        } else {
                            showNoLiDARAlert = true
                        }
                    }) {
                        Image(systemName: "arkit")
                            .foregroundColor(.appTextPrimary)
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 34, height: 34) // same fixed size
                            .background(
                                Circle()
                                    .fill(Color.appCanvasPrimary)
                            )
                    }

                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

            }
            .background(Color.appCanvasPrimary)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $navigateToARPortal) {
                PortalWebView()
                    .ignoresSafeArea(.all)

            }
        }
        .ignoresSafeArea()
        .alert("LiDAR Not Available", isPresented: $showNoLiDARAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not support the AR experience that requires a LiDAR sensor.")
        }
        .onAppear {
            if let token = AuthManager.shared.getToken() {
                let url = AppURLs.Web.configurator(token: token)
                print("Configurator URL: \(url)")
            } else {
                print("No token found")
            }
        }
        .trackScreen("ConfiguratorWebView", metadata: ["surface": "web_configurator", "flow": "product_configurator"])
    }
}

#Preview {
    LimiContentView()
}





// MARK: - Preview
