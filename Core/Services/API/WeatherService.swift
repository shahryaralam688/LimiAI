import Foundation
import CoreLocation

// Uses Open-Meteo — completely free, no API key, no signup, no limits
// https://open-meteo.com

class WeatherService: ObservableObject {
    static let shared = WeatherService()

    private let baseURL = AppURLs.External.openMeteoForecast

    private var cachedData: WeatherData?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 600

    private init() {}

    func fetchWeather(latitude: Double, longitude: Double, cityName: String = "") async throws -> WeatherData {
        if let cached = cachedData,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheDuration {
            return cached
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,surface_pressure,weather_code,wind_speed_10m,cloud_cover,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw WeatherError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let meteoResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
        let result = meteoResponse.toWeatherData(cityName: cityName)

        cachedData = result
        cacheTimestamp = Date()

        return result
    }
}

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "Server error: \(code)"
        case .decodingError: return "Failed to parse weather data"
        }
    }
}
