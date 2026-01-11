//
//  LimiWebView 2.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 20/11/2025.
//


import SwiftUI
@preconcurrency import WebKit
import ARKit

struct LimiWebViewCon: UIViewRepresentable {
    let url: URL
    let macAddress: String?
    @Binding var isLoading: Bool

    // Backward-compatible initializer (no loading binding required)
    init(url: URL) {
        self.url = url
        self.macAddress = nil
        self._isLoading = .constant(false)
    }

    // Convenience initializer to allow passing macAddress without requiring isLoading binding
    init(url: URL, macAddress: String?) {
        self.url = url
        self.macAddress = macAddress
        self._isLoading = .constant(false)
    }

    // Designated initializer with loading binding
    init(url: URL, isLoading: Binding<Bool>, macAddress: String? = nil) {
        self.url = url
        self.macAddress = macAddress
        self._isLoading = isLoading
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, macAddress: macAddress)
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
        contentController.add(context.coordinator, name: "buttonClicked")

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
        private let macAddress: String?

        init(isLoading: Binding<Bool>, macAddress: String?) {
            self.isLoading = isLoading
            self.macAddress = macAddress
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "logger":
                print("[WebView JS Console] \(message.body)")
            case "buttonClicked":
                if let snapId = message.body as? String {
                    print("[SnapID] Received: \(snapId)")
                    self.downloadUSDZUsingAPI(downloadId: snapId)
                    if let mac = macAddress, !mac.isEmpty {
                        DeviceDownloadStore.shared.set(downloadId: snapId, forMac: mac)
                        print("[SnapID] Stored mapping mac=\(mac) -> downloadId=\(snapId)")
                        // Read-back prints for verification
                        if let stored = DeviceDownloadStore.shared.get(forMac: mac) {
                            print("[SnapID] Read-back for mac=\(mac): \(stored)")
                        } else {
                            print("[SnapID] Read-back failed for mac=\(mac)")
                        }
                        let allMap = DeviceDownloadStore.shared.all()
                        print("[SnapID] Current Map: \(allMap)")
                    }
                } else {
                    print("[SnapID] Received non-string body: \(message.body)")
                }
            default:
                print("[WebView Message] name=\(message.name) body=\(message.body)")
            }
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

//        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//            print("[WebView] Finished loading")
//            isLoading.wrappedValue = false
//        }

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
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            (function(){
              const STORAGE_KEY = 'snap_ids';
              // Define a safe global 'id' to avoid ReferenceError from page inline handlers like: id = "save_id"
              try { if (typeof window.id === 'undefined') { window.id = null; } } catch(_) {}
              function readIds(){ try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'); } catch(e){ return []; } }
              function writeIds(arr){ try { localStorage.setItem(STORAGE_KEY, JSON.stringify(arr)); } catch(e){} }
              function addIdIfNeeded(id){ if(!id) return; const arr = readIds(); if(!arr.includes(id)) { arr.push(id); writeIds(arr); } }

              // 1) Silence known bad inline code: "id" used as a variable in page onClick
              (function(){
                const prev = window.onerror;
                window.onerror = function(msg, url, line, col, err){
                  try {
                    if (msg && (String(msg).includes("Can't find variable: id") || String(msg).includes('id is not defined'))) {
                      console.log('[SnapID JS] Suppressed ReferenceError for global id');
                      return true; // prevent default logging
                    }
                  } catch(_) {}
                  if (prev) return prev.apply(this, arguments);
                  return false;
                };
              })();

              // 2) Try to auto-tag the Save button if it lacks an id
              function tagSaveButton(){
                try {
                  const buttons = Array.from(document.querySelectorAll('button'));
                  buttons.forEach(btn => {
                    if (!btn.id) {
                      const span = btn.querySelector('span');
                      const text = span && span.textContent ? span.textContent.trim().toLowerCase() : (btn.textContent||'').trim().toLowerCase();
                      if (text === 'save') {
                        btn.id = 'save_id';
                      }
                    }
                  });
                } catch(_) {}
              }

              function handleSnap(buttonEl){
                try {
                  // Prefer the inner span that carries a dynamic id (modelId)
                  const spanChild = buttonEl.querySelector('span[id]');
                  const snapId = spanChild && spanChild.id ? spanChild.id : null;
                  if (snapId) {
                    addIdIfNeeded(snapId);
                    try { console.log('[SnapID JS] '+snapId); } catch(_){ }
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.buttonClicked) {
                      window.webkit.messageHandlers.buttonClicked.postMessage(snapId);
                    }
                  } else {
                    try { console.log('[SnapID JS] No span[id] found inside clicked button'); } catch(_){ }
                  }
                } catch (err) {
                  try { console.log('[SnapID JS] error: '+ (err && err.message ? err.message : err)); } catch(_){ }
                }
              }

              function setupDelegated(){
                document.removeEventListener('click', delegated, true);
                document.addEventListener('click', delegated, true);
                tagSaveButton();
              }
              function delegated(e){
                // React to any button click; prefer the Save button first
                const button = e.target.closest('button#save_id, button');
                if (button) {
                  handleSnap(button);
                }
              }

              if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupDelegated);
              } else {
                setupDelegated();
              }
              setTimeout(setupDelegated, 1000);
              setTimeout(setupDelegated, 3000);
              setTimeout(tagSaveButton, 1500);
            })();
            """
            webView.evaluateJavaScript(script)
            isLoading.wrappedValue = true
        }
        private func downloadUSDZUsingAPI(downloadId: String) {
            guard let url = URL(string: "https://dev.api.limitless-lighting.co.uk/client/3d-models/web-configurator/download/\(downloadId)") else {
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
                } catch {
                    print("❌ Save error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading.wrappedValue = false
                    }
                }
            }

            task.resume()
        }
    }
}


struct LimiContentViewcCon: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToARPortal = false
    @State private var showNoLiDARAlert = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                if let token = AuthManager.shared.getToken(),
                   let url = URL(string: "https://limi-configurator-ios-version-2.vercel.app/configurator?token=\(token)") {
                    LimiWebView(url: url)
                        .ignoresSafeArea(.all)
                } else if let url = URL(string: "https://limi-configurator-ios-version-2.vercel.app/configurator") {
                    LimiWebView(url: url)
                        .ignoresSafeArea(.all)
                }


            }
            .background(Color.charlestonGreen)
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
                let url = "https://limi-configurator-ios.vercel.app/configurator?token=\(token)"
                print("Configurator URL: \(url)")
            } else {
                print("No token found")
            }
        }
    }
}

#Preview {
    LimiContentViewcCon()
}
