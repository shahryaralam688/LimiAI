import SwiftUI
import CoreLocation
import MapKit

struct LocationStorageView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var storageManager = LocationStorageManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: "#111214")
                .ignoresSafeArea()
            VStack {
                ZStack {
                    ZStack(alignment: .bottom) {
                        Image("GetStartImage")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 256)
                            .clipped()
                        
                        // Bottom gradient overlay
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(1.0),
                                Color.black.opacity(0.8)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 40)  // height of the blurred border
                        .blur(radius: 60)   // controls softness of blur

                    }
                    .frame(height: 256)
                    .ignoresSafeArea(edges: .top)
                    // Header
                    VStack(spacing: 16) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 201, height: 40)
                        
                        Text("Enable Location")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("We need your location to provide personalized lighting experiences and weather information.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                }

                
                Spacer()
                
                // Current Location Display
                if let location = locationManager.currentLocation {
                    VStack(spacing: 12) {
                        Text("Current Location")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        VStack(spacing: 4) {
                            Text("Latitude: \(location.coordinate.latitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Longitude: \(location.coordinate.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let address = storageManager.currentAddress {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        locationManager.requestLocationPermission()
                        saveLocationAndContinue()

                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Turn on Location")
                        }
                        .font(.headline)
                        .foregroundColor(.charlestonGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.emerald)
                        .cornerRadius(19)
                    }
                    .padding()
                    .padding(.bottom, 50)
                    .padding(.horizontal, 16)
                    
//                    if locationManager.currentLocation != nil {
//                        Button(action: {
//                            saveLocationAndContinue()
//                        }) {
//                            HStack {
//                                Image(systemName: "checkmark.circle.fill")
//                                Text("Save Location & Continue")
//                            }
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .frame(height: 50)
//                            .background(Color.green)
//                            .cornerRadius(25)
//                        }
//                        .padding(.horizontal, 16)
//                    }
                    
//                    Button(action: {
//                        skipLocationSetup()
//                    }) {
//                        Text("Skip for now")
//                            .font(.subheadline)
//                            .foregroundColor(.white.opacity(0.7))
//                            .underline()
//                    }
                }
                
            }
        }
        .alert("Location Access", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(locationManager.$authorizationStatus) { status in
            handleLocationAuthorizationChange(status)
        }
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                storageManager.reverseGeocodeLocation(location)
            }
        }
    }
    
    private func saveLocationAndContinue() {
        guard let location = locationManager.currentLocation else {
            alertMessage = "Location not available. Please try again."
            showingAlert = true
            return
        }
        
        // Store location in global variable
        let locationString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        globalUserLocation = locationString
        
        // Also store the address if available
        if let address = storageManager.currentAddress {
            UserDefaults.standard.set(address, forKey: "globalUserAddress")
        }
    }
    
    private func skipLocationSetup() {
        // Set empty location and continue
        globalUserLocation = ""
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
