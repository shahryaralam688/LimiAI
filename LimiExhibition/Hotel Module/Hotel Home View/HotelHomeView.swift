//
//  HomeView.swift
//  Aura
//
//  Created by Cascade on 25/09/2025.
//

import SwiftUI
import CoreLocation

struct HotelHomeView: View {
    private let socketClient = SocketIOExample()
    @State private var didStartBLE = false // BLE auto-connect flag
    @State private var selectedTab: BottomTab = .home
    @State private var orbIntensity: CGFloat = 2.0
    @State private var orbVolume: CGFloat = 0.1
    @State private var showVoiceView = false
    @State private var isSidebarOpen = false
    
    // Floating button states
    @State private var isNavigating = false
    @State private var isLoaded = true
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            // Main content area based on selected tab
            VStack(spacing: 0) {
                // Tab content
                Group {
                    switch selectedTab {
                    case .home:
                        HomeTabView(locationManager: locationManager)
                    case .requests:
                        HotelRequestView()
                    case .system:
                        HotelRoomDevices()
//                        BLEStarterView()
                    case .profile:
                        ProfileView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom tab bar - always visible
                BottomTabBar(
                    selected: $selectedTab,
                    orbIntensity: $orbIntensity,
                    orbVolume: $orbVolume,
                    showVoiceView: $showVoiceView,
                    isSidebarOpen: $isSidebarOpen
                )
            }
            .background(Color.themeBlack)
            .ignoresSafeArea()
            
//            // Sidebar (highest priority) — pin to leading without affecting layout width
//            HotelEnhancedSidebarView(isSidebarOpen: $isSidebarOpen)
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//                .allowsHitTesting(isSidebarOpen)
//                .accessibilityHidden(!isSidebarOpen)
//                .zIndex(3)
        }
        .onAppear {
            socketClient!.onOrderUpdate = { action in
                bluetoothManager.BLESend(message: action)
            }
            socketClient!.connect()
            
            // Ensure permission and start updates (requests if needed)
            locationManager.ensurePermissionAndStart()
        }
//        .onChange(of: bluetoothManager.isBluetoothOn) { isOn in
//            if isOn && !didStartBLE {
//                didStartBLE = true
//                bluetoothManager.startScanning { devices in
//                    if let found = devices.first(where: { $0.name == "1 CH-HUB" }) {
//                        print("🔍 Found newHub, attempting to connect...")
//                        bluetoothManager.connectToDevice(deviceId: found.id)
//                        // Wait for connection, then send message
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
//                            if bluetoothManager.isConnected {
//                                bluetoothManager.BLESend(message: "Connected device")
//                            }
//                        }
//                        bluetoothManager.stopScanning()
//                    }
//                }
//            }
//        }
        .background(Color.appCanvasHotel)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showVoiceView) {
            VoiceView()
        }
        .fullScreenCover(isPresented: $isNavigating) {
//            AddDeviceView()
            BLEStarterView()
        }
    }
}

// MARK: - Hotel Chip
private struct HotelChip: View {
    let title: String
    let location: CLLocation?
    @State private var locationName: String = ""
    
    private var displayText: String {
        if !locationName.isEmpty {
            return locationName
        } else if let location = location {
            let latitude = String(format: "%.4f", location.coordinate.latitude)
            let longitude = String(format: "%.4f", location.coordinate.longitude)
            return "\(latitude), \(longitude)"
        } else {
            return title
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.alabaster)
            
            Text(displayText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.alabaster)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5)) // frosted blur material
                .fill(Color.themeWhite.opacity(0.2))
                .shadow(color: Color.themeBlack.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            reverseGeocode()
        }
        .onChange(of: location) { _, _ in
            reverseGeocode()
        }
    }
    
    private func reverseGeocode() {
        guard let location = location else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    if let city = placemark.locality, let country = placemark.country {
                        self.locationName = "\(city), \(country)"
                    } else if let administrativeArea = placemark.administrativeArea, let country = placemark.country {
                        self.locationName = "\(administrativeArea), \(country)"
                    } else if let country = placemark.country {
                        self.locationName = country
                    }
                }
            }
        }
    }
}

// MARK: - Recent Activity Section
private struct RecentActivitySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 4) {
                    Text("✨")
                        .font(.system(size: 18))
                    Text("Suggestions for you")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.themeWhite)
                }
                
                Spacer()
                
                Button("See All") {
                    // Action
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    SuggestionCard(
                        imageName: "Sug1",
                        title: "Oceanview Dinner",
                        rating: "5/5"
                    )
                    
                    SuggestionCard(
                        imageName: "Sug2",
                        title: "Oceanview Dinner",
                        rating: "5/5"
                    )
                    
                    SuggestionCard(
                        imageName: "Sug1",
                        title: "Oceanview Dinner",
                        rating: "5/5"
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
}


// MARK: - Suggestion Card
private struct SuggestionCard: View {
    let imageName: String
    let title: String
    let rating: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Food Image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 286, height: 120)
                .clipped()
                .clipShape(
                    RoundedCorner(radius: 16, corners: [.topLeft, .topRight])
                )
            
            // Content Area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.themeWhite)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text(rating)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.themeWhite)
                            Text("Rating")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.themeWhite.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.themeWhite.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    // Green Arrow Button
                    Button(action: {}) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.themeWhite)
                    }
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.green)
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 286)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurfaceInsetAlt)
        )
    }
}

// MARK: - Feature Card
private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.green.opacity(0.08))
                    )
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.themeWhite)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.themeWhite.opacity(0.7))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.themeBlack.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.themeWhite.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: Color.themeBlack.opacity(0.5), radius: 20, x: 0, y: 12)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Tab Bar
private enum BottomTab: String, CaseIterable {
    case home = "Home"
    case requests = "Requests"
    case system = "Device"
    case profile = "Profile"
}

private struct BottomTabBar: View {
    @Binding var selected: BottomTab
    @Binding var orbIntensity: CGFloat
    @Binding var orbVolume: CGFloat
    @Binding var showVoiceView: Bool
    @Binding var isSidebarOpen: Bool
    @State private var showAddDevice = false

    
    var body: some View {
        ZStack {
            // Sleek horizontal rounded capsule tab bar
            Capsule()
                .fill(Color.appSurfaceTertiary.opacity(0.8))
                .frame(height: 80)
                .overlay(
                    Capsule()
                        .stroke(Color.emerald, lineWidth: 0.5)
                )
            
            HStack(spacing: 16) {
                tabItem(.home, systemIcon: "house.fill")
                tabItem(.requests, systemIcon: "list.bullet")
                centerOrbView
                    .offset(y: -35) // Move the voice button up into the top notch
                
                tabItem(.system, systemIcon: "switch.2")
                tabItem(.profile, systemIcon: "person.crop.circle")
            }
        }
        .background(Color.clear)
        .ignoresSafeArea()
    
    }
    
    private func tabItem(_ tab: BottomTab, systemIcon: String) -> some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            if tab == .system {
                selected = tab

//                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                    showAddDevice = true   // 👈 trigger sheet
//                }
            } else if tab == .profile {
                selected = tab

//                isSidebarOpen = true
            } else {
                selected = tab
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selected == tab ? Color.green : Color.themeWhite.opacity(0.8))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selected == tab ? Color.themeWhite : Color.themeWhite.opacity(0.7))
            }
            .frame(width: 64, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
//        .sheet(isPresented: $showAddDevice) {  // 👈 present view
//            BLEStarterView()
//        }
    }
    
    
    private var centerOrbView: some View {
        Button {
            showVoiceView = true
        } label: {
            ZStack {
                Color.appSurfaceQuaternary // solid gray background

                OrbView(intensity: $orbIntensity, currentVolume: $orbVolume)
                    .frame(width: 160, height: 160) // smaller orb inside
            }
            .frame(width: 78, height: 78)
            .clipShape(Circle()) // makes it circular
            .overlay(
                Circle().stroke(Color.emerald, lineWidth: 0.5) // adds emerald border
            )
        }
        .buttonStyle(.plain)
    }
}



// Simple blur wrapper for compatibility
// (Uses UIVisualEffectView under the hood)
struct HotelVisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

//// MARK: - Enhanced Sidebar with Improved Animation
struct HotelEnhancedSidebarView: View {
    @Binding var isSidebarOpen: Bool
    @State private var showProfileEditView = false
    @State private var showIFrameView = false
    @State private var navigateToLIMI = false
    @State private var showGetStartScreen = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("demoEmail") var demoEmail: String = "umer.asif@terralumen.co.uk"

    var body: some View {
        ZStack {
            // Dimmed background
            if isSidebarOpen {
                Color.themeBlack.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSidebarOpen = false
                        }
                    }
            }
            
            HStack(spacing: 0) {
                // Sidebar content
                VStack(alignment: .leading, spacing: 0) {
                    // Settings Title
                    Text("Settings")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.alabaster)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .padding(.bottom, 30)
                    
                    // Profile Section
                    VStack(spacing: 12) {
                        // Profile Image
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.themeWhite)
                            )
                        
                        Text("Umer")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.themeBlack)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // MY SHOP ONLINE Section
                            SectionHeader(title: "MY SHOP ONLINE")
                            
                            MenuItem(title: "Configurator", action: {
                                showIFrameView = true
                            })
                            MenuItem(title: "What is LIMI AI!", action: {
                                navigateToLIMI = true
                            })
                            MenuItem(title: "My Purchases", action: {})
                            MenuItem(title: "Recently viewed", action: {})
                            
                            // MY ACCOUNT Section
                            SectionHeader(title: "MY ACCOUNT")
                                .padding(.top, 20)
                            
                            MenuItem(title: "Payment options", action: {})
                            MenuItem(title: "Privacy", action: {})
                            MenuItem(title: "Refer a friend", action: {})
                            MenuItem(title: "Help & Contact", action: {})
                            
                            // Logout
                            Button(action: {
                                AuthManager.shared.clearToken()
                                showGetStartScreen = true
                                BluetoothManager.shared.disconnectAllDevices()
                                hasCompletedOnboarding = false
                                hasLaunchedBefore = false
                                demoEmail = ""
                            }) {
                                HStack {
                                    Text("Logout")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.red.opacity(0.5))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.themeWhite)
                            }
                            .padding(.top, 20)
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: UIScreen.main.bounds.width * 0.8)
                .background(Color(uiColor: .systemBackground))
                .offset(x: isSidebarOpen ? 0 : -UIScreen.main.bounds.width * 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSidebarOpen)
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showGetStartScreen) {
            GetStart()
        }
    }
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.gray)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Menu Item
private struct MenuItem: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            action()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.themeBlack)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.themeWhite)
        }
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    @ObservedObject var locationManager: LocationManager

    // MARK: - Greeting + Time
    @State private var now: Date = Date()
    private let greetingTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        default: return "Good Evening,"
        }
    }

    // MARK: - Location chip logic
    private var hotelChipTitle: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Location permission needed"
        case .notDetermined:
            return "Requesting location permission…"
        default:
            return locationManager.currentLocation == nil ? "Locating…" : ""
        }
    }

    var body: some View {
        GeometryReader { geo in
            // Calculate responsive padding dynamically based on screen width
            let width = geo.size.width
            // Dynamically scale horizontal padding for all iPhone models
            let baseWidth: CGFloat = 390 // Reference width (iPhone 12/14/15)

            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        // MARK: - Header background with white overlay
                        ZStack {
                            Image("Frame-2")
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height * 0.5
                                )
                                .clipped()
                            
                            // White overlay for the ocean image effect
                            Color.themeWhite.opacity(0.1)
                                .frame(
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height * 0.5
                                )
                        }
                        .clipShape(
                            RoundedCorner(radius: 24, corners: [.bottomLeft, .bottomRight])
                        )
                        .ignoresSafeArea(edges: .top)

                        // MARK: - Greeting + chips
                        VStack(alignment: .center, spacing: 12) {
                            VStack(spacing: 4) {
                                Text(greeting)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.themeWhite)
                                    .onReceive(greetingTimer) { now = $0 }

                                Text("Welcome Back")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.themeWhite)
                                    .shadow(color: .themeBlack.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .multilineTextAlignment(.center)
                            }
                            
                            HotelChip(
                                title: hotelChipTitle.isEmpty ? "" : hotelChipTitle,
                                location: locationManager.currentLocation
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .frame(maxWidth: .infinity)
                    }

                    // MARK: - Black background section for suggestions
                    VStack(spacing: 0) {
                        RecentActivitySection()
                            .padding(.top, 30)
                        
                        Spacer(minLength: 120)
                    }
                    .background(Color.themeBlack)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.themeBlack)
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Requests Tab View
struct RequestsTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("My Requests")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.themeWhite)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                Text("View and manage your service requests")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.themeWhite.opacity(0.7))
                    .padding(.horizontal, 20)
                
                // Add your request items here
                VStack(spacing: 12) {
                    RequestItemCard(
                        title: "Room Cleaning",
                        status: "In Progress",
                        time: "10:30 AM"
                    )
                    RequestItemCard(
                        title: "Extra Towels",
                        status: "Completed",
                        time: "9:15 AM"
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.themeBlack)
    }
}

// MARK: - Request Item Card
private struct RequestItemCard: View {
    let title: String
    let status: String
    let time: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.themeWhite)
                
                Text(time)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.themeWhite.opacity(0.6))
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(status == "Completed" ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((status == "Completed" ? Color.green : Color.orange).opacity(0.2))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkGray)
        )
    }
}

// MARK: - Hotel Stay Chip
private struct HotelStayChip: View {
    let roomInfo: String
    let stayDates: String
    
    var body: some View {
        HStack {
            Text(roomInfo)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeWhite)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            Text(stayDates)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.themeWhite.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .frame(height: 38) // ✅ fixed height
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.themeBlack.opacity(0.45))
                .shadow(color: Color.themeBlack.opacity(0.35), radius: 16, x: 0, y: 8)
        )
    }
}

// Custom RoundedCorner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = 0.0
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    HotelHomeView()
}
