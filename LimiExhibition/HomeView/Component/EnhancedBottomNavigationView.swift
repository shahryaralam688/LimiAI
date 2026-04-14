import SwiftUI
import ARKit

// MARK: - FAB Menu Item

struct FABMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

// MARK: - Main Floating Navigation

struct EnhancedBottomNavigationView: View {
    @Binding var showARScan: Bool
    @Binding var showCustomer: Bool
    @Binding var showGrouping: Bool
    @Binding var showWebView: Bool
    @Binding var selectedTab: Int
    @Binding var isLoaded: Bool
    @Binding var isSidebarOpen: Bool

    @State private var showVoiceView = false
    @State private var showLidarToast = false
    @State private var isFABOpen = false
    // Stagger: which items are revealed
    @State private var revealedCount: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim overlay
            if isFABOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { closeFAB() }
                    .transition(.opacity)
                    .zIndex(0)
            }

            // Bottom-pinned bar + FAB
            VStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .center) {
                    // Blob menu items positioned relative to center FAB
                    blobMenuItems

                    // Glass nav bar
                    floatingBar

                    // Tab icons
                    HStack(spacing: 0) {
                        navItem(index: 0, icon: "house.fill", title: "Home")
                        navItem(index: 1, icon: "cube.transparent", title: "AR")
                        Color.clear.frame(width: 72)
                        navItem(index: 3, icon: "globe", title: "Web")
                        navItem(index: 4, icon: "person.fill", title: "Profile")
                    }
                    .padding(.horizontal, 20)

                    // Center FAB
                    fabButton
                        .offset(y: -28)
                        .zIndex(10)
                }
                .frame(height: 64)
                .padding(.bottom, 28)
            }
            .zIndex(1)
        }
        .opacity(isSidebarOpen ? 0 : 1)
        .allowsHitTesting(!isSidebarOpen)
        .offset(y: isLoaded ? 0 : 120)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isLoaded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFABOpen)
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
            VoiceView()
        }
        .overlay(alignment: .top) {
            if showLidarToast {
                Text("This device does not support LiDAR-based AR.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 12, fillOpacity: 0.1)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .onChange(of: showLidarToast) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showLidarToast = false }
                }
            }
        }
    }

    // MARK: - Floating Glass Bar

    private var floatingBar: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.appSurfaceInset.opacity(0.65))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .frame(height: 64)
            .padding(.horizontal, 20)
            .shadow(color: Color.orbGlow1.opacity(0.06), radius: 24, y: -4)
            .shadow(color: Color.black.opacity(0.3), radius: 12, y: 4)
    }

    // MARK: - FAB Button

    private var fabButton: some View {
        Button(action: toggleFAB) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orbGlow1.opacity(isFABOpen ? 0.5 : 0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 16,
                            endRadius: 44
                        )
                    )
                    .frame(width: 76, height: 76)

                // Core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isFABOpen
                                ? [Color.appSurfaceTertiary, Color.appSurfaceSecondary]
                                : [.orbGlow4, .orbGlow1],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
                    .shadow(color: (isFABOpen ? Color.white : Color.orbGlow1).opacity(0.4), radius: 14, y: 3)

                // + / × icon with smooth rotation
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isFABOpen ? 45 : 0))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isFABOpen ? 0.95 : 1.0)
    }

    // MARK: - Blob Menu (organic blobs orbit around FAB, sweep left→top→right)

    private var blobMenuItems: some View {
        let items: [(icon: String, color: Color, action: () -> Void)] = [
            ("photo.on.rectangle.angled", Color(hex: "9B5DE5"), {
                closeFAB()
                if deviceSupportsLiDAR { showARScan = true }
                else { withAnimation { showLidarToast = true } }
            }),
            ("video.fill", Color(hex: "E53E3E"), {
                closeFAB(); showVoiceView = true
            }),
            ("bag.fill", Color(hex: "F6AD55"), {
                closeFAB()
            })
        ]

        // Arc positions matching the screenshot:
        // item 0 (purple) — bottom-left
        // item 1 (red)    — top-center
        // item 2 (orange) — right
        let finalOffsets: [(x: CGFloat, y: CGFloat)] = [
            (-62, -72),
            (0,   -100),
            (62,  -72)
        ]

        // Each blob gets a unique rotation so they look irregular
        let blobAngles: [Double] = [25, -10, 15]
        // Different blob variants for each item
        let blobScales: [(w: CGFloat, h: CGFloat)] = [
            (60, 64),
            (64, 60),
            (58, 66)
        ]

        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isShown = isFABOpen && revealedCount > index

                // Animate along a circular arc from center (0,0)
                // When appearing, item orbits from behind the FAB to its position
                let arcProgress: CGFloat = isShown ? 1.0 : 0.0

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    item.action()
                }) {
                    ZStack {
                        BlobShape()
                            .fill(item.color)
                            .frame(width: blobScales[index].w, height: blobScales[index].h)
                            .rotationEffect(.degrees(blobAngles[index] + (isShown ? 0 : -40)))
                            .shadow(color: item.color.opacity(0.45), radius: 10, y: 3)

                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .offset(
                    x: finalOffsets[index].x * arcProgress,
                    y: finalOffsets[index].y * arcProgress
                )
                .scaleEffect(isShown ? 1.0 : 0.1)
                .opacity(isShown ? 1.0 : 0)
                .rotationEffect(.degrees(isShown ? 0 : -60))
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.62)
                    .delay(isShown ? Double(index) * 0.1 : Double(2 - index) * 0.05),
                    value: isShown
                )
            }
        }
        .offset(y: -28)
    }

    // MARK: - Nav Item

    private func navItem(index: Int, icon: String, title: String) -> some View {
        Button {
            guard !isSidebarOpen else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
                switch index {
                case 1:
                    if deviceSupportsLiDAR { showARScan = true }
                    else { showLidarToast = true }
                case 3: showWebView = true
                case 4: showCustomer = true
                default: break
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundColor(selectedTab == index ? .orbGlow4 : .appTextMuted)
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTab == index ? .appTextPrimary : .appTextMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toggleFAB() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if isFABOpen {
            // Close: reverse stagger
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                revealedCount = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isFABOpen = false
                }
            }
        } else {
            // Open: stagger reveal left→center→right
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isFABOpen = true
            }
            // Stagger each item
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        revealedCount = i
                    }
                }
            }
        }
    }

    private func closeFAB() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            revealedCount = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isFABOpen = false
            }
        }
    }

    private var deviceSupportsLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) ||
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
}

// MARK: - Organic Blob Shape (matches the reference app's irregular rounded shapes)

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Top center — slightly off-center start
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.0))

        // Top-right curve — bulges out
        path.addCurve(
            to: CGPoint(x: w * 1.0, y: h * 0.40),
            control1: CGPoint(x: w * 0.75, y: h * -0.05),
            control2: CGPoint(x: w * 1.05, y: h * 0.12)
        )

        // Right-bottom — tighter curve
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.95),
            control1: CGPoint(x: w * 0.96, y: h * 0.65),
            control2: CGPoint(x: w * 0.95, y: h * 0.85)
        )

        // Bottom — wide gentle curve
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.90),
            control1: CGPoint(x: w * 0.60, y: h * 1.08),
            control2: CGPoint(x: w * 0.35, y: h * 1.05)
        )

        // Left side — bulges left
        path.addCurve(
            to: CGPoint(x: w * 0.02, y: h * 0.35),
            control1: CGPoint(x: w * -0.02, y: h * 0.75),
            control2: CGPoint(x: w * -0.06, y: h * 0.52)
        )

        // Back to top — closes with slight asymmetry
        path.addCurve(
            to: CGPoint(x: w * 0.45, y: h * 0.0),
            control1: CGPoint(x: w * 0.10, y: h * 0.18),
            control2: CGPoint(x: w * 0.25, y: h * 0.02)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DeepSpaceBackground()
        EnhancedBottomNavigationView(
            showARScan: .constant(false),
            showCustomer: .constant(false),
            showGrouping: .constant(false),
            showWebView: .constant(false),
            selectedTab: .constant(0),
            isLoaded: .constant(true),
            isSidebarOpen: .constant(false)
        )
    }
}
