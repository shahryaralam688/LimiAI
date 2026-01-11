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
            Color(red: 0.01, green: 0.07, blue: 0.12)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.0, green: 0.44, blue: 0.6),
                                    Color(red: 0.01, green: 0.06, blue: 0.11)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    HStack(alignment: .center) {
                        // Left content column
                        VStack(alignment: .leading, spacing: 16) {
                            // Day + degree dot row
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(day)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                            }

                            // Temperature + wind/humidity
                            HStack(alignment: .center, spacing: 16) {
                                HStack(alignment: .top, spacing: 0) {
                                    Text("\(temperature)")
                                        .font(.system(size: 140, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .fixedSize()

                                    Text("°")
                                        .font(.system(size: 72, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.top, 12)
                                }
                                .layoutPriority(1)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wind")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18, weight: .medium))

                                        Text("\(windSpeedKmh) km/h")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "humidity")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18, weight: .medium))

                                        Text("\(humidityPercent)%")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.top, 20)
                            }

                            // Last updated + High/Low
                            HStack(alignment: .top) {
                                Text("Last updated \(lastUpdated)")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(Color(red: 0.63, green: 0.72, blue: 0.8))

                                Spacer(minLength: 24)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("H \(high)°")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)

                                    Text("L \(low)°")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            // Location row
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                                        .frame(width: 26, height: 26)

                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                Text("\(country), \(city)")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                        }
                        .padding(24)

                        Spacer(minLength: 16)

                        // Right icon column
                        VStack {
                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: min(geometry.size.width * 0.33, 180),
                                           height: min(geometry.size.width * 0.33, 180))

                                ZStack {
                                    Circle()
                                        .fill(Color.white)

                                    Circle()
                                        .fill(Color(red: 0.0, green: 0.44, blue: 0.6))
                                        .offset(x: 28)
                                }
                                .frame(width: min(geometry.size.width * 0.26, 150),
                                       height: min(geometry.size.width * 0.26, 150))
                            }

                            Spacer()

                            Text(condition)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.63, green: 0.72, blue: 0.8))
                                .padding(.bottom, 16)
                        }
                        .padding(.trailing, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 227)
            }
        }
    }


}

struct WeatherCardView_Previews: PreviewProvider {
    static var previews: some View {
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
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
