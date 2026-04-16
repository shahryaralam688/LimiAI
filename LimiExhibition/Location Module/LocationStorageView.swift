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

    @AppStorage("locationPromptSkipped") private var locationPromptSkipped = false

    private let brandGreen = Color.appBrandSecondary

    var body: some View {
        ZStack {
            Color.appCanvasPrimary.ignoresSafeArea()
            
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
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            Image("logo")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(brandGreen)
                .scaledToFit()
                .frame(width: 201, height: 40)
                .shadow(color: brandGreen.opacity(0.3), radius: 20, x: 0, y: 0)
            
            VStack(spacing: 12) {
                Text("Enable Location")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.themeWhite)
                
                Text("We need your location to provide personalized lighting experiences and weather information.")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.themeWhite.opacity(0.7))
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
                            .foregroundColor(brandGreen)
                        Text("Current Location")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.themeWhite)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Latitude: \(location.coordinate.latitude, specifier: "%.4f")")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.themeWhite.opacity(0.6))
                        Text("Longitude: \(location.coordinate.longitude, specifier: "%.4f")")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.themeWhite.opacity(0.6))
                    }
                    
                    if let address = storageManager.currentAddress {
                        Text(address)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.themeWhite.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.themeWhite.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(brandGreen.opacity(0.2), lineWidth: 1)
                        )
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
                        .font(.system(size: 18, weight: .semibold))
                    Text("Turn on Location")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                }
                .foregroundColor(.themeBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [.orbGlow4, .orbGlow1], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule(style: .continuous))
                .shadow(color: brandGreen.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 24)

            if showSkipButton {
                Button(action: skipAndContinue) {
                    Text("Not now")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.themeWhite.opacity(0.65))
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
