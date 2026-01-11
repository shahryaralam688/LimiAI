import Foundation
import Combine

final class WeatherViewModel: ObservableObject {
    // MARK: - Published properties used by WeatherCardView
    @Published var day: String = "--"
    @Published var temperature: Int = 0
    @Published var temperatureUnit: String = "C"
    @Published var windSpeedKmh: Int = 0
    @Published var humidityPercent: Int = 0
    @Published var lastUpdated: String = "--:--"
    @Published var country: String = "--"
    @Published var city: String = "--"
    @Published var high: Int = 0
    @Published var low: Int = 0
    @Published var condition: String = "--"

    private var cancellables = Set<AnyCancellable>()

    init() {
        // For now, load static/mock data.
        // Later you can call `refreshFromRealAPIs()` here.
        loadMockData()
    }

    // MARK: - Public API

    /// Call this from your view when you want to refresh weather data.
    func refreshFromRealAPIs() {
        // TODO: Implement actual weather + location fetching here.
        // 1. Use CoreLocation to get current coordinates/city/country.
        // 2. Use WeatherKit or a third-party API to fetch weather data.
        // 3. On the main thread, assign the values below.
    }

    // MARK: - Temporary mock data for UI testing

    private func loadMockData() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        day = formattedWeekday(from: now)
        temperature = 26
        temperatureUnit = "C"
        windSpeedKmh = 28
        humidityPercent = 42
        lastUpdated = formatter.string(from: now)
        country = "USA"
        city = "New York"
        high = 30
        low = 20
        condition = "Clear"
    }

    private func formattedWeekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE" // e.g. Sunday
        return formatter.string(from: date)
    }
}
