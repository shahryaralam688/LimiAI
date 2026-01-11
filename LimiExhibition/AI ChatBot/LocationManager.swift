//
//  LocationManager.swift
//  Aura
//
//  Created by Cascade on 02/09/2025.
//

import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Capture current status immediately (important when the app already has permission)
        authorizationStatus = locationManager.authorizationStatus
        // If already authorized, start updates right away
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Ensure we have permission and start updates if authorized
    func ensurePermissionAndStart() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            // Also request an immediate single fix
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Do nothing; UI can show a placeholder and possibly guide user to Settings
            break
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
            locationManager.requestLocation()
        case .denied, .restricted:
            stopLocationUpdates()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // Older iOS API coverage (called on some OS versions)
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationUpdates()
            locationManager.requestLocation()
        case .denied, .restricted:
            stopLocationUpdates()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        #if DEBUG
        // Print detailed location information to console (debug builds only)
        print("📍 Location Updated:")
        print("   Latitude: \(location.coordinate.latitude)")
        print("   Longitude: \(location.coordinate.longitude)")
        print("   Altitude: \(location.altitude) meters")
        print("   Horizontal Accuracy: \(location.horizontalAccuracy) meters")
        print("   Timestamp: \(location.timestamp)")
        
        // Reverse geocode to get readable location name (debug diagnostics)
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("   ❌ Reverse geocoding failed: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                print("   🏠 Address Details:")
                if let name = placemark.name {
                    print("      Name: \(name)")
                }
                if let thoroughfare = placemark.thoroughfare {
                    print("      Street: \(thoroughfare)")
                }
                if let subThoroughfare = placemark.subThoroughfare {
                    print("      Street Number: \(subThoroughfare)")
                }
                if let locality = placemark.locality {
                    print("      City: \(locality)")
                }
                if let subLocality = placemark.subLocality {
                    print("      Sub-locality: \(subLocality)")
                }
                if let administrativeArea = placemark.administrativeArea {
                    print("      State/Province: \(administrativeArea)")
                }
                if let postalCode = placemark.postalCode {
                    print("      Postal Code: \(postalCode)")
                }
                if let country = placemark.country {
                    print("      Country: \(country)")
                }
                if let isoCountryCode = placemark.isoCountryCode {
                    print("      Country Code: \(isoCountryCode)")
                }
                print("   📱 Full Location: \(placemark)")
            }
        }
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
