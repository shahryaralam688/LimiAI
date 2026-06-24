import Foundation
import Combine
import CoreLocation
import SwiftUI

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cityName = ""

    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var hasFetched = false

    var temperature: Int { weatherData?.temperatureCelsius ?? 0 }
    var feelsLike: Int { weatherData?.feelsLikeCelsius ?? 0 }
    var condition: String { weatherData?.condition ?? "--" }
    var conditionDescription: String { weatherData?.conditionDescription ?? "--" }
    var humidity: Int { weatherData?.humidity ?? 0 }
    var windSpeed: Int { weatherData?.windSpeedKmh ?? 0 }
    var pressure: Int { weatherData?.pressure ?? 0 }
    var visibility: String {
        guard let v = weatherData?.visibility else { return "--" }
        return v >= 1000 ? "\(v / 1000) km" : "\(v) m"
    }
    var sfSymbol: String { weatherData?.sfSymbol ?? "cloud.fill" }
    var isDaytime: Bool { weatherData?.isDaytime ?? true }
    var cloudiness: Int { weatherData?.cloudiness ?? 0 }

    var gradientColors: [Color] {
        guard let data = weatherData else {
            return [Color(hex: "0B0B0F"), Color(hex: "1A1A3E"), Color(hex: "0B0B0F")]
        }
        return data.gradientColors.map { $0.color }
    }

    var day: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    var lastUpdated: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    var hourlyForecast: [HourlyForecastItem] {
        guard let data = weatherData else { return [] }

        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: Date())

        // Use real hourly data from Open-Meteo
        if !data.hourlyTemps.isEmpty && !data.hourlyTimes.isEmpty {
            let startIndex = min(currentHour, data.hourlyTemps.count - 1)
            let endIndex = min(startIndex + 12, data.hourlyTemps.count)

            return (startIndex..<endIndex).enumerated().map { offset, i in
                let isNow = offset == 0
                let hour = i % 24
                let code = i < data.hourlyCodes.count ? data.hourlyCodes[i] : data.weatherCode
                let icon = WeatherData.sfSymbol(for: code, isDay: hour >= 6 && hour < 20)
                return HourlyForecastItem(
                    hour: isNow ? "Now" : String(format: "%02d:00", hour),
                    temp: Int(data.hourlyTemps[i].rounded()),
                    icon: icon,
                    isNow: isNow
                )
            }
        }

        // Fallback: simulate from current temp
        return (0..<12).map { i in
            let h = (currentHour + i) % 24
            let delta = [-1, 0, 1, 2, 1, 0, -1, -2, -1, 0, 1, 0][i]
            return HourlyForecastItem(
                hour: i == 0 ? "Now" : String(format: "%02d:00", h),
                temp: data.temperatureCelsius + delta,
                icon: data.sfSymbol,
                isNow: i == 0
            )
        }
    }

    init() {
        observeLocation()
    }

    func startFetching() {
        locationManager.ensurePermissionAndStart()
    }

    func refresh() {
        hasFetched = false
        locationManager.ensurePermissionAndStart()
    }

    private func observeLocation() {
        locationManager.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { a, b in
                a.coordinate.latitude == b.coordinate.latitude &&
                a.coordinate.longitude == b.coordinate.longitude
            }
            .sink { [weak self] location in
                guard let self, !self.hasFetched else { return }
                self.hasFetched = true
                Task { await self.fetchWeather(for: location) }
            }
            .store(in: &cancellables)
    }

    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil

        // Geocode city name first
        var resolvedCity = ""
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            resolvedCity = placemark.locality ?? placemark.name ?? ""
        }

        do {
            let weather = try await WeatherService.shared.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: resolvedCity
            )
            weatherData = weather
            cityName = resolvedCity.isEmpty ? "Your Location" : resolvedCity
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
