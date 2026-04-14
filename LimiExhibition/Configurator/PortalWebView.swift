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
    enum TabType: String, CaseIterable {
        case presets = "Presets"
        case custom = "Custom"
    }

    @State private var selectedTab: TabType = .presets
    @State private var showCustomView = false
    @State private var lightType: String = "Placeholder"
    @State private var downloadId: String = "686d23da93bc73cdc3a280ca"
    @State private var isLoading = false
    @State private var showWebViewContainer = false
    @State private var didCheckLightConfigs = false
    @State private var isOffline = false
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DeepSpaceBackground(showParticles: false)

            VStack(spacing: 0) {
                header
                tabPicker
                    .padding(.top, 12)

                // Content
                Group {
                    if selectedTab == .presets {
                        DemoARView()
                            .ignoresSafeArea()
                    } else {
                        customTabContent
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }

            if isLoading {
                loadingOverlay
            }
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .onAppear {
            checkLightConfigs()
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .fullScreenCover(isPresented: $showCustomView) {
            CustomView(
                lightType: LightConfigManager.shared.lightType,
                downloadId: LightConfigManager.shared.downloadId,
                showCustomView: $showCustomView,
                card: Card(
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 14) {
            LimiBackButton { dismiss() }

            VStack(alignment: .leading, spacing: 3) {
                Text("AR Experience")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Text("Explore and customize in AR")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.easeOut(duration: 0.5), value: appeared)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(TabType.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .appTextPrimary : .appTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 16, strokeOpacity: 0.06, fillOpacity: 0.04)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
    }

    // MARK: - Custom Tab Content

    private var customTabContent: some View {
        NavigationView {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()

                if isOffline {
                    offlineState
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

    // MARK: - Offline State

    private var offlineState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cube.transparent")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.appTextMuted)

            Text("No Designs Yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            LimiPrimaryButton(title: "Open Configurator", height: 48) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isOffline = false
                    showWebViewContainer = true
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.3)
                    .progressViewStyle(CircularProgressViewStyle(tint: .orbGlow4))
                Text("Loading model...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(30)
            .glassCard(cornerRadius: 20, fillOpacity: 0.12)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .zIndex(10)
    }
}

// MARK: - API Check

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

// MARK: - Web View Container

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
            const buttons = document.querySelectorAll('.portal-button, [data-action="openCustomView"]');
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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
            if message.name == "buttonClicked", let spanID = message.body as? String {
                fetchLightConfig(for: spanID)
            }
        }

        private func fetchLightConfig(for spanID: String) {
            guard let url = URL(string: APIConstants.lightConfig(spanID)) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                let extractedLightType = json["light_type"] as? String ?? "Unknown"
                let extractedDownloadId = json["download_Id"] as? String ?? ""

                LightConfigManager.shared.lightType = extractedLightType
                LightConfigManager.shared.downloadId = extractedDownloadId

                DispatchQueue.main.async {
                    self.lightType.wrappedValue = extractedLightType
                    self.downloadId.wrappedValue = extractedDownloadId
                }

                if !extractedDownloadId.isEmpty {
                    self.downloadUSDZUsingAPI(downloadId: extractedDownloadId)
                }
            }.resume()
        }

        private func downloadUSDZUsingAPI(downloadId: String) {
            guard let url = URL(string: APIConstants.webConfiguratorDownload(downloadId)) else { return }

            DispatchQueue.main.async { self.isLoading.wrappedValue = true }

            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let configuratorFolderURL = documentsURL.appendingPathComponent("Configurator")

            if !fileManager.fileExists(atPath: configuratorFolderURL.path) {
                try? fileManager.createDirectory(at: configuratorFolderURL, withIntermediateDirectories: true)
            }

            let fileURL = configuratorFolderURL.appendingPathComponent("\(downloadId).usdz")

            if fileManager.fileExists(atPath: fileURL.path) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isLoading.wrappedValue = false
                    self.showCustomView.wrappedValue = true
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            URLSession.shared.dataTask(with: request) { data, _, error in
                guard error == nil, let data = data else {
                    DispatchQueue.main.async { self.isLoading.wrappedValue = false }
                    return
                }
                do {
                    try data.write(to: fileURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.isLoading.wrappedValue = false
                        self.showCustomView.wrappedValue = true
                    }
                } catch {
                    DispatchQueue.main.async { self.isLoading.wrappedValue = false }
                }
            }.resume()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isOffline.wrappedValue = false }
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
            handleLoadError()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadError()
        }

        private func handleLoadError() {
            DispatchQueue.main.async {
                self.isOffline.wrappedValue = true
                self.isLoading.wrappedValue = false
            }
        }
    }
}

// MARK: - Custom AR View

struct CustomView: View {
    let lightType: String
    let downloadId: String
    @Binding var showCustomView: Bool
    let card: Card

    var body: some View {
        ARContainerWithOverlay(card: Card(
            imageName: ["chairFront", "chairSide", "chairBack"],
            title: "Placeholder",
            price: 49,
            description: lightType,
            objectName: downloadId,
            size: "22 x 22 x 22",
            color: "red"
        ))
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PortalWebView()
}
