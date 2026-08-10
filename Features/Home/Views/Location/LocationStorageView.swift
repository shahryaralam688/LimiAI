import SwiftUI
import CoreLocation
import MapKit

struct LocationStorageView: View {
    /// When set (e.g. post–storyboard sheet), called after save or skip so the presenter can continue.
    var onFinished: (() -> Void)? = nil
    /// Show “Not now” for optional flows (e.g. right after the AI storyboard).
    var showSkipButton: Bool = false

    @StateObject private var locationManager = LocationManager()
    @StateObject private var storageManager = LocationStorageManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var contentOpacity = 0.0
    @State private var contentOffset: CGFloat = 20
    @State private var ambientVeilExpanded = false

    @AppStorage("locationPromptSkipped") private var locationPromptSkipped = false

    private let brandGreen = Color.appBrandSecondary
    private let ctaGradient = LinearGradient(
        colors: [.appBrandPrimary, .appBrandSecondary, .appBrandTertiary],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
            ambientWaterVeil
            
            VStack {
                headerSection
                
                Spacer()
                
                locationDisplaySection
                
                Spacer()
                
                actionButtonsSection
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .alert("Location Access", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                ambientVeilExpanded = true
            }
        }
        .trackScreen("LocationPrompt")
        .onReceive(locationManager.$authorizationStatus) { status in
            handleLocationAuthorizationChange(status)
        }
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                storageManager.reverseGeocodeLocation(location)
            }
        }
    }

    private var ambientWaterVeil: some View {
        RadialGradient(
            colors: [
                Color.appInfoBright.opacity(0.10),
                Color.appBrandSecondary.opacity(0.08),
                Color.appAIGradientEnd.opacity(0.02),
                Color.clear
            ],
            center: .center,
            startRadius: 80,
            endRadius: 420
        )
        .scaleEffect(ambientVeilExpanded ? 1.08 : 0.94)
        .opacity(ambientVeilExpanded ? 0.95 : 0.72)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Image("logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.appBrandSecondary)
                    .scaledToFit()
                    .frame(width: 201, height: 40)
                    .blur(radius: 18)
                    .opacity(0.24)

                Image("logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.appBrandPrimary)
                    .scaledToFit()
                    .frame(width: 201, height: 40)
            }
            
            VStack(spacing: 12) {
                Text("Share your location")
                    .font(LimiTypography.largeTitle)
                    .foregroundColor(.appTextPrimary)
                
                Text("This helps me tailor your lighting and weather to where you are — only when it feels right for you.")
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.top, 80)
    }
    
    private var locationDisplaySection: some View {
        Group {
            if let location = locationManager.currentLocation {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.appBrandSecondary)
                        Text("Current Location")
                            .font(LimiTypography.button)
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Latitude: \(location.coordinate.latitude, specifier: "%.4f")")
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appTextMuted)
                        Text("Longitude: \(location.coordinate.longitude, specifier: "%.4f")")
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appTextMuted)
                    }
                    
                    if let address = storageManager.currentAddress {
                        Text(address)
                            .font(LimiTypography.callout)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.appBorderPrimary.opacity(0.85), lineWidth: 1)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.appTextQuiet.opacity(0.16),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                                .mask(
                                    Rectangle()
                                        .frame(height: 20)
                                        .offset(y: -1)
                                )
                        }
                        .shadow(color: Color.appCanvasStrong.opacity(0.28), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                locationManager.requestLocationPermission()
                saveLocationAndContinue()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(LimiTypography.button)
                    Text("Share location")
                        .font(LimiTypography.button)
                }
                .foregroundColor(.appTextInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(ctaGradient)
                        .overlay(alignment: .top) {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.themeWhite.opacity(0.22),
                                            Color.appGlassFillMedium,
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .mask(
                                    Rectangle()
                                        .frame(height: 18)
                                        .offset(y: -1)
                                )
                        }
                )
                .clipShape(Capsule(style: .continuous))
                .shadow(color: Color.appBrandPrimary.opacity(0.24), radius: 18, x: 0, y: 10)
            }
            .padding(.horizontal, 24)

            if showSkipButton {
                Button(action: skipAndContinue) {
                    Text("Not now")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 32)
    }
    
    private func saveLocationAndContinue() {
        guard let location = locationManager.currentLocation else {
            alertMessage = "Location not available. Please try again."
            showingAlert = true
            return
        }

        let locationString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        globalUserLocation = locationString

        if let address = storageManager.currentAddress {
            UserDefaults.standard.set(address, forKey: "globalUserAddress")
        }

        NotificationCenter.default.post(name: .limiUserLocationDidChange, object: nil)

        onFinished?()
    }

    private func skipAndContinue() {
        if let finished = onFinished {
            finished()
        } else {
            locationPromptSkipped = true
        }
    }

    private func skipLocationSetup() {
        globalUserLocation = ""
        NotificationCenter.default.post(name: .limiUserLocationDidChange, object: nil)
    }
    
    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            alertMessage = "Location access is denied. Please enable it in Settings to use location features."
            showingAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.ensurePermissionAndStart()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Location Storage Manager
class LocationStorageManager: NSObject, ObservableObject {
    private let geocoder = CLGeocoder()
    
    @Published var currentAddress: String?
    
    func reverseGeocodeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let address = [
                        placemark.subThoroughfare,
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.country
                    ].compactMap { $0 }.joined(separator: ", ")
                    
                    self?.currentAddress = address.isEmpty ? "Unknown Location" : address
                }
            }
        }
    }
}

#Preview {
    LocationStorageView()
}
