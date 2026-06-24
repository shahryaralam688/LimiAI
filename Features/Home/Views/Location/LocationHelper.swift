import Foundation
import CoreLocation

// MARK: - Location Helper Functions
struct LocationHelper {
    
    /// Get the current stored location as CLLocationCoordinate2D
    static func getCurrentLocationCoordinates() -> CLLocationCoordinate2D? {
        let locationString = globalUserLocation
        guard !locationString.isEmpty else { return nil }
        
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Get the current stored location as CLLocation
    static func getCurrentLocation() -> CLLocation? {
        guard let coordinates = getCurrentLocationCoordinates() else { return nil }
        return CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
    
    /// Get the stored address
    static func getCurrentAddress() -> String? {
        return UserDefaults.standard.string(forKey: "globalUserAddress")
    }
    
    /// Check if location is available
    static func isLocationAvailable() -> Bool {
        return !globalUserLocation.isEmpty
    }
    
    /// Clear stored location (for logout or reset)
    static func clearStoredLocation() {
        globalUserLocation = ""
        UserDefaults.standard.removeObject(forKey: "globalUserAddress")
    }
    
    /// Update location with new coordinates
    static func updateLocation(latitude: Double, longitude: Double, address: String? = nil) {
        globalUserLocation = "\(latitude),\(longitude)"
        if let address = address {
            UserDefaults.standard.set(address, forKey: "globalUserAddress")
        }
    }
    
    /// Get location string for display purposes
    static func getLocationDisplayString() -> String {
        if let address = getCurrentAddress() {
            return address
        } else if let coordinates = getCurrentLocationCoordinates() {
            return "Lat: \(String(format: "%.4f", coordinates.latitude)), Lng: \(String(format: "%.4f", coordinates.longitude))"
        } else {
            return "Location not available"
        }
    }
}

// MARK: - Global Location Access
extension LocationHelper {
    
    /// Observable class for SwiftUI views that need to react to location changes
    class LocationObserver: ObservableObject {
        @Published var currentLocation: CLLocation?
        @Published var currentAddress: String?
        @Published var isLocationAvailable: Bool = false
        
        init() {
            updateLocationData()
        }
        
        func updateLocationData() {
            currentLocation = LocationHelper.getCurrentLocation()
            currentAddress = LocationHelper.getCurrentAddress()
            isLocationAvailable = LocationHelper.isLocationAvailable()
        }
        
        func refreshLocation() {
            updateLocationData()
        }
    }
}
