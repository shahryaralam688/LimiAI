import SwiftUI
import ARKit

struct EnhancedBottomNavigationView: View {
    @Binding var showARScan: Bool
    @Binding var showCustomer: Bool
    @Binding var showGrouping: Bool
    @Binding var showWebView: Bool
    @Binding var selectedTab: Int
    @Binding var isLoaded: Bool
    @Binding var isSidebarOpen: Bool
    
    @State private var animateGlow = false
    @State private var showVoiceView = false
    @State private var orbIntensity: CGFloat = 4.0
    @State private var orbVolume: CGFloat = 0.2
    @State private var showLidarToast = false

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                // Background capsule
                Rectangle()
                    .fill(Color(hex: "#1C1C1C").opacity(0.8))
                    .frame(height: 80)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: -2)
                    .onAppear { animateGlow = true }

                // Tab buttons
                HStack(spacing: 8) {
                    // Left side
                    tabItem(index: 0, icon: "home", title: "Home")
                    tabItem(index: 1, icon: "camera", title: "AR Scan")

                    // Center orb
                    Image("Vector-2")
                        .scaledToFit()
                        .offset(y: -35)
                        .onTapGesture {
                            showVoiceView = true
                        }

                    // Right side
                    tabItem(index: 3, icon: "shop", title: "Website")
                    tabItem(index: 4, icon: "bottom_profile_view", title: "Profile")
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .opacity(isSidebarOpen ? 0 : 1)
        .allowsHitTesting(!isSidebarOpen)
        .offset(y: isLoaded ? 0 : 100)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isLoaded)
        // Sheets
        .sheet(isPresented: $showWebView, onDismiss: { selectedTab = 0 }) {
            WebViewScreen(showWebView: $showWebView)
        }
        .sheet(isPresented: $showCustomer, onDismiss: { selectedTab = 0 }) {
            ProfileView()
        }
        .sheet(isPresented: $showARScan, onDismiss: { selectedTab = 0 }) {
            PortalWebView()
        }
        .sheet(isPresented: $showVoiceView, onDismiss: { selectedTab = 0 }) {
//            VoiceView()
            VoiceChatBot()


        }
        .overlay(alignment: .top) {
            if showLidarToast {
                Text("This device does not support LiDAR-based AR.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .onChange(of: showLidarToast) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showLidarToast = false
                }
            }
        }
    }

    // MARK: - Tab Item
    private func tabItem(index: Int, icon: String, title: String) -> some View {
        Button {
            guard !isSidebarOpen else { return }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
                switch index {
                case 1:
                    if deviceSupportsLiDAR {
                        showARScan = true
                    } else {
                        showLidarToast = true
                    }
                case 3:
                    showWebView = true
                case 4:
                    showCustomer = true
                default:
                    break
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(selectedTab == index ? .emerald : .white.opacity(0.8))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.7))
            }
            .frame(width: 64, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Orb View
    private var centerOrbView: some View {
        Button {
            showVoiceView = true
        } label: {
            ZStack {
                Color(hex: "#3a3d42")
                OrbView(intensity: $orbIntensity, currentVolume: $orbVolume)
                    .frame(width: 160, height: 160)
            }
            .frame(width: 78, height: 78)
            .clipShape(Circle())
            .contentShape(Circle())          // <- important: hit area is a circle
            .overlay(
                Circle().stroke(Color.emerald, lineWidth: 0.5)
            )
            .shadow(color: Color.emerald.opacity(0.5), radius: 10)
        }
        .buttonStyle(.plain)
    }

    private var deviceSupportsLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) ||
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
}

#Preview {
    EnhancedBottomNavigationView(
        showARScan: .constant(false),
        showCustomer: .constant(false),
        showGrouping: .constant(false),
        showWebView: .constant(false),
        selectedTab: .constant(0),
        isLoaded: .constant(true),
        isSidebarOpen: .constant(false)
    )
    .background(Color.black) // optional, just to see the bar clearly
}
