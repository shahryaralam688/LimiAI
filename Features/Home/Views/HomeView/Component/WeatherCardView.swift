import SwiftUI

struct WeatherCardView: View {
    let day: String
    let temperature: Int
    let temperatureUnit: String
    let windSpeedKmh: Int
    let humidityPercent: Int
    let lastUpdated: String
    let country: String
    let city: String
    let high: Int
    let low: Int
    let condition: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2E5BFF"), Color(hex: "56A0F5"), Color(hex: "87CEEB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text("\(city), \(country)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))

                    HStack(alignment: .top, spacing: 0) {
                        Text("\(temperature)")
                            .font(.system(size: 68, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                        Text("°")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 6)
                    }

                    HStack(spacing: 16) {
                        Label("\(windSpeedKmh) km/h", systemImage: "wind")
                        Label("\(humidityPercent)%", systemImage: "humidity.fill")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                    HStack {
                        Text("H:\(high)° L:\(low)°")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(lastUpdated)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(20)

                Spacer()

                VStack {
                    Image(systemName: conditionIcon)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.3), radius: 12, y: 4)

                    Text(condition)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)
                }
                .padding(.trailing, 24)
            }
        }
        .frame(height: 220)
        .shadow(color: Color(hex: "2E5BFF").opacity(0.25), radius: 20, y: 10)
    }

    private var conditionIcon: String {
        switch condition.lowercased() {
        case "clear": return "sun.max.fill"
        case "clouds": return "cloud.fill"
        case "rain", "drizzle": return "cloud.rain.fill"
        case "thunderstorm": return "cloud.bolt.fill"
        case "snow": return "snowflake"
        case "mist", "fog", "haze": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }
}

#Preview {
    WeatherCardView(
        day: "Sunday",
        temperature: 26,
        temperatureUnit: "C",
        windSpeedKmh: 28,
        humidityPercent: 42,
        lastUpdated: "11:45",
        country: "USA",
        city: "New York",
        high: 30,
        low: 20,
        condition: "Clear"
    )
    .padding()
    .background(Color.appCanvasPrimary)
    .preferredColorScheme(.dark)
}
