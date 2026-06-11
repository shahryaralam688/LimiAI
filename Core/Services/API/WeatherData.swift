import Foundation
import SwiftUI

// MARK: - Weather Data Model

struct WeatherData: Codable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let pressure: Int
    let condition: String
    let conditionDescription: String
    let weatherCode: Int
    let windSpeed: Double
    let cloudiness: Int
    let visibility: Int
    let cityName: String
    let isDay: Bool
    let hourlyTemps: [Double]
    let hourlyTimes: [String]
    let hourlyCodes: [Int]

    var temperatureCelsius: Int { Int(temperature.rounded()) }
    var feelsLikeCelsius: Int { Int(feelsLike.rounded()) }
    var windSpeedKmh: Int { Int(windSpeed.rounded()) }

    var isDaytime: Bool { isDay }

    var sfSymbol: String {
        Self.sfSymbol(for: weatherCode, isDay: isDay)
    }

    static func sfSymbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:      return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:      return isDay ? "sun.min.fill" : "moon.fill"
        case 2:      return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:      return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 65:     return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 80, 81, 82: return "cloud.rain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95:     return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default:     return "cloud.fill"
        }
    }

    var gradientColors: [GradientStop] {
        if !isDay {
            return [
                GradientStop(hex: "0F0C29"),
                GradientStop(hex: "1A1A3E"),
                GradientStop(hex: "24243E")
            ]
        }
        switch weatherCode {
        case 0, 1:
            return [GradientStop(hex: "2E5BFF"), GradientStop(hex: "56A0F5"), GradientStop(hex: "87CEEB")]
        case 2:
            return [GradientStop(hex: "3B6CB7"), GradientStop(hex: "6A9BD8"), GradientStop(hex: "A8C8E8")]
        case 3, 45, 48:
            return [GradientStop(hex: "4A5568"), GradientStop(hex: "718096"), GradientStop(hex: "A0AEC0")]
        case 51...67, 80...82:
            return [GradientStop(hex: "334155"), GradientStop(hex: "475569"), GradientStop(hex: "64748B")]
        case 71...77, 85, 86:
            return [GradientStop(hex: "CBD5E1"), GradientStop(hex: "E2E8F0"), GradientStop(hex: "F1F5F9")]
        case 95, 96, 99:
            return [GradientStop(hex: "1E1B3A"), GradientStop(hex: "2D2B55"), GradientStop(hex: "44426E")]
        default:
            return [GradientStop(hex: "2E5BFF"), GradientStop(hex: "56A0F5"), GradientStop(hex: "87CEEB")]
        }
    }

    struct GradientStop: Codable {
        let hex: String
        var color: Color { Color(hex: hex) }
    }
}

// MARK: - WMO Weather Code → Description

extension WeatherData {
    static func description(for code: Int) -> (condition: String, description: String) {
        switch code {
        case 0:      return ("Clear", "Clear sky")
        case 1:      return ("Mostly Clear", "Mainly clear")
        case 2:      return ("Partly Cloudy", "Partly cloudy")
        case 3:      return ("Overcast", "Overcast")
        case 45:     return ("Fog", "Fog")
        case 48:     return ("Fog", "Depositing rime fog")
        case 51:     return ("Drizzle", "Light drizzle")
        case 53:     return ("Drizzle", "Moderate drizzle")
        case 55:     return ("Drizzle", "Dense drizzle")
        case 56, 57: return ("Freezing Drizzle", "Freezing drizzle")
        case 61:     return ("Rain", "Slight rain")
        case 63:     return ("Rain", "Moderate rain")
        case 65:     return ("Rain", "Heavy rain")
        case 66, 67: return ("Freezing Rain", "Freezing rain")
        case 71:     return ("Snow", "Slight snow fall")
        case 73:     return ("Snow", "Moderate snow fall")
        case 75:     return ("Snow", "Heavy snow fall")
        case 77:     return ("Snow", "Snow grains")
        case 80:     return ("Showers", "Slight rain showers")
        case 81:     return ("Showers", "Moderate rain showers")
        case 82:     return ("Showers", "Violent rain showers")
        case 85:     return ("Snow Showers", "Slight snow showers")
        case 86:     return ("Snow Showers", "Heavy snow showers")
        case 95:     return ("Thunderstorm", "Thunderstorm")
        case 96:     return ("Thunderstorm", "Thunderstorm with slight hail")
        case 99:     return ("Thunderstorm", "Thunderstorm with heavy hail")
        default:     return ("Unknown", "Unknown conditions")
        }
    }
}

// MARK: - Hourly Item

struct HourlyForecastItem: Identifiable {
    let id = UUID()
    let hour: String
    let temp: Int
    let icon: String
    let isNow: Bool
}

// MARK: - Open-Meteo API Response

struct OpenMeteoResponse: Codable {
    let current: CurrentWeather?
    let hourly: HourlyWeather?

    enum CodingKeys: String, CodingKey {
        case current = "current"
        case hourly
    }

    struct CurrentWeather: Codable {
        let temperature2m: Double?
        let apparentTemperature: Double?
        let relativeHumidity2m: Int?
        let surfacePressure: Double?
        let weatherCode: Int?
        let windSpeed10m: Double?
        let cloudCover: Int?
        let isDay: Int?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case surfacePressure = "surface_pressure"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case cloudCover = "cloud_cover"
            case isDay = "is_day"
        }
    }

    struct HourlyWeather: Codable {
        let time: [String]?
        let temperature2m: [Double]?
        let weatherCode: [Int]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    func toWeatherData(cityName: String) -> WeatherData {
        let code = current?.weatherCode ?? 0
        let desc = WeatherData.description(for: code)

        return WeatherData(
            temperature: current?.temperature2m ?? 0,
            feelsLike: current?.apparentTemperature ?? 0,
            humidity: current?.relativeHumidity2m ?? 0,
            pressure: Int(current?.surfacePressure ?? 0),
            condition: desc.condition,
            conditionDescription: desc.description,
            weatherCode: code,
            windSpeed: current?.windSpeed10m ?? 0,
            cloudiness: current?.cloudCover ?? 0,
            visibility: 10000,
            cityName: cityName,
            isDay: (current?.isDay ?? 1) == 1,
            hourlyTemps: hourly?.temperature2m ?? [],
            hourlyTimes: hourly?.time ?? [],
            hourlyCodes: hourly?.weatherCode ?? []
        )
    }
}
