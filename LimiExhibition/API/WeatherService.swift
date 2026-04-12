//
//  WeatherService.swift
//  LimiExhibition
//
//  Created by Antigravity AI
//

import Foundation
import CoreLocation

// MARK: - Weather Service
class WeatherService: ObservableObject {
    static let shared = WeatherService()
    
    // IMPORTANT: Replace with your actual OpenWeatherMap API key
    // Get your free key at: https://openweathermap.org/api
    private let apiKey = "YOUR_API_KEY_HERE"
    private let baseURL = AppURLs.External.weatherAPI
    
    private init() {}
    
    /// Fetch weather data for given coordinates
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        // Construct URL with parameters
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric") // Celsius
        ]
        
        guard let url = components?.url else {
            throw WeatherError.invalidURL
        }
        
        // Check for API key
        if apiKey == "YOUR_API_KEY_HERE" {
            throw WeatherError.missingAPIKey
        }
        
        // Make network request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WeatherError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse JSON response
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(OpenWeatherMapResponse.self, from: data)
        
        return weatherResponse.toWeatherData()
    }
}

// MARK: - Weather Errors
enum WeatherError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .missingAPIKey:
            return "Please add your OpenWeatherMap API key"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to parse weather data"
        }
    }
}
