import SwiftUI
import CoreLocation

// MARK: - Example of using global location in any view
struct LocationUsageExample: View {
    @StateObject private var locationObserver = LocationHelper.LocationObserver()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Location Usage Example")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Example 1: Simple location display
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Location:")
                    .font(.headline)
                
                if LocationHelper.isLocationAvailable() {
                    Text(LocationHelper.getLocationDisplayString())
                        .font(.body)
                        .foregroundColor(.blue)
                } else {
                    Text("Location not available")
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Example 2: Using coordinates for weather API
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather API Integration:")
                    .font(.headline)
                
                if let coordinates = LocationHelper.getCurrentLocationCoordinates() {
                    Text("Lat: \(coordinates.latitude, specifier: "%.4f")")
                    Text("Lng: \(coordinates.longitude, specifier: "%.4f")")
                    
                    Button("Fetch Weather") {
                        fetchWeatherForCurrentLocation()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else {
                    Text("Need location for weather data")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Example 3: Location-based features
            VStack(alignment: .leading, spacing: 8) {
                Text("Location-based Features:")
                    .font(.headline)
                
                Button("Find Nearby Devices") {
                    findNearbyDevices()
                }
                .disabled(!LocationHelper.isLocationAvailable())
                
                Button("Set Lighting Based on Location") {
                    setLocationBasedLighting()
                }
                .disabled(!LocationHelper.isLocationAvailable())
                
                Button("Clear Location") {
                    LocationHelper.clearStoredLocation()
                    locationObserver.refreshLocation()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .onAppear {
            locationObserver.refreshLocation()
        }
    }
    
    private func fetchWeatherForCurrentLocation() {
        guard let coordinates = LocationHelper.getCurrentLocationCoordinates() else {
            print("No location available for weather fetch")
            return
        }
        
        // Example weather API call
        print("Fetching weather for: \(coordinates.latitude), \(coordinates.longitude)")
        // Here you would make your actual weather API call
        // WeatherAPI.fetch(lat: coordinates.latitude, lng: coordinates.longitude)
    }
    
    private func findNearbyDevices() {
        guard let location = LocationHelper.getCurrentLocation() else {
            print("No location available for device search")
            return
        }
        
        print("Searching for devices near: \(location)")
        // Here you would implement nearby device discovery
    }
    
    private func setLocationBasedLighting() {
        guard let coordinates = LocationHelper.getCurrentLocationCoordinates() else {
            print("No location available for lighting adjustment")
            return
        }
        
        print("Setting lighting based on location: \(coordinates)")
        // Here you would implement location-based lighting logic
        // For example, adjust brightness based on time zone, sunrise/sunset
    }
}

#Preview {
    LocationUsageExample()
}
