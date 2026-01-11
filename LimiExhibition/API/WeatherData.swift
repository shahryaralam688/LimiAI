//
//  WeatherData.swift
//  LimiExhibition
//
//  Created by Antigravity AI
//

import Foundation

// MARK: - Weather Data Model
struct WeatherData: Codable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let pressure: Int
    let condition: String
    let conditionDescription: String
    let icon: String
    
    // Computed properties for display
    var temperatureCelsius: Int {
        Int(temperature.rounded())
    }
    
    var feelsLikeCelsius: Int {
        Int(feelsLike.rounded())
    }
}

// MARK: - OpenWeatherMap API Response Models
struct OpenWeatherMapResponse: Codable {
    let main: MainWeather
    let weather: [Weather]
    
    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        let pressure: Int
        
        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
            case pressure
        }
    }
    
    struct Weather: Codable {
        let main: String
        let description: String
        let icon: String
    }
    
    // Convert API response to WeatherData
    func toWeatherData() -> WeatherData {
        WeatherData(
            temperature: main.temp,
            feelsLike: main.feelsLike,
            humidity: main.humidity,
            pressure: main.pressure,
            condition: weather.first?.main ?? "Unknown",
            conditionDescription: weather.first?.description.capitalized ?? "Unknown",
            icon: weather.first?.icon ?? "01d"
        )
    }
}
