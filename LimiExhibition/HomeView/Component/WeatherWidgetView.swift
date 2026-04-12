import SwiftUI
import CoreLocation

// MARK: - Weather Widget

struct WeatherWidgetView: View {
    // Colors using existing Color.swift definitions and hex colors
    private let bgDark      = Color.appSurfacePanel   // card background
    private let bgDarker    = Color.appSurfaceDarker   // lower card
    private let chipDark    = Color.appSurfaceSecondary   // "Today" chip
    private let dividerGray = Color.themeWhite.opacity(0.12)
    private let textPrimary = Color.alabaster
    private let textMuted   = Color.alabaster.opacity(0.6)
    private let accentSun   = Color.yellow
    private let accentCloud = Color.appInfo
    private let shadowGlow1 = Color.yellow.opacity(0.45)
    private let shadowGlow2 = Color.appInfoBright.opacity(0.45)

    // Runtime weather state
    @StateObject private var locationManager = LocationManager()
    @State private var weatherData: WeatherData?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                // TOP: main card
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(bgDark)
                        .overlay(
                            // subtle top-to-bottom tint
                            LinearGradient(colors: [Color.themeWhite.opacity(0.05), .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        )
                    // "Today" chip
                    HStack{
                        
                        Spacer()
                        
                        Text("Today")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.9))
                            .frame(width: 131.78, height: 25.53) // Figma width & height
                            .background(
                                Rectangle()
                                    .fill(Color.appCanvasStrong)
                                    .clipShape(
                                        RoundedCorner(radius: 28.83, corners: [.bottomLeft, .bottomRight])
                                    )
                                
                            )
                        
                        Spacer()
                        
                    }



                    HStack(alignment: .center) {
//                        // Weather icon
//                        WeatherIcon(sun: accentSun, cloud: accentCloud)
//                            .frame(width: 92, height: 92)
//                            .padding(.leading, 18)
                        ZStack {
                            // Glowing sun background
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.appWarning.opacity(0.2),  // lighter at edges
                                            Color.appWarning.opacity(0.1),  // warmer mid tone
                                            Color.appWarning.opacity(0.2)   // darker in center
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .blur(radius: 15) // soft glow effect
                                .opacity(0.9)
                                .offset(x : 7, y: -28) // slight upward positioning behind image

                            // Weather icon (in front)
                            Image("weather")
                                .resizable()
                                .frame(width: 150, height: 100)

                        }

                            


                        // Temperature block
                        VStack(alignment: .trailing, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                // Current temperature (runtime)
                                Text("\(weatherData?.temperatureCelsius ?? 28)")
                                    .font(.custom("Poppins-SemiBold", size: 66)) // Closest match to 65.89px
                                    .foregroundColor(textPrimary)
                                    .lineSpacing(0) // to simulate line-height: 100%
                                    .multilineTextAlignment(.center)

                                // Secondary value: feels-like temperature
                                HStack(spacing: 2) {
                                    Text("/").foregroundColor(textPrimary)
                                    Text("\(weatherData?.feelsLikeCelsius ?? 13)°")
                                        .foregroundColor(textPrimary.opacity(0.85))
                                }
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                            }
                            Rectangle()
                                .fill(dividerGray)
                                .frame(height: 1)
                            // Condition description (runtime)
                            Text(weatherData?.conditionDescription ?? "Sunny with cold")
                                .font(.custom("Poppins-Regular", size: 14.8)) // exact match
                                .foregroundColor(textMuted)
                                .lineSpacing(0) // for line-height: 100%
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 20) // space below the "Today" chip
                    .padding(.bottom, 2)

                    // bottom divider inside top card
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(dividerGray)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 0)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28.83)
                        .stroke(Color.themeWhite, lineWidth: 1)
                        .clipShape(
                            RoundedCorner(radius: 28.83, corners: [.bottomLeft, .bottomRight])
                        )
                )
                .frame(height: 170)
                .zIndex(1)
                // BOTTOM: details row card (attached look)
//                HStack(spacing: 0) {
//                    StatItem(
//                        title: "Sensible",
//                        value: weatherData != nil ? "\(weatherData!.feelsLikeCelsius)°" : "25°"
//                    )
//                    Divider().background(dividerGray)
//                        .offset(y: -15)
//
//                    StatItem(
//                        title: "Humidity",
//                        value: weatherData != nil ? "\(weatherData!.humidity)%" : "63%"
//                    )
//                    Divider().background(dividerGray)
//                        .offset(y: -15)
//
//                    StatItem(
//                        title: "Pressure",
//                        value: weatherData != nil ? "\(weatherData!.pressure) hPA" : "1009 hPA"
//                    )
//                }
//                .offset()
//                .frame(height: 82)
//                .frame(width: 283)
//                .background(
//                    Rectangle()
//                        .fill(Color.appCanvasStrong)
//                        .clipShape(
//                            RoundedCorner(radius: 28.83, corners: [.bottomLeft, .bottomRight])
//                        )
//                        .offset(y: -15)
//
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 28.83)
//                        .stroke(Color.themeWhite, lineWidth: 1)
//                        .clipShape(
//                            RoundedCorner(radius: 28.83, corners: [.bottomLeft, .bottomRight])
//                        )
//                        .offset(y: -15)
//                )

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.clear)
        .onAppear {
            // Start location updates so we can fetch weather
            locationManager.ensurePermissionAndStart()
        }
        .onChange(of: locationManager.currentLocation) { _, newValue in
            if let location = newValue {
                fetchWeather(for: location)
            }
        }
    }
}



// MARK: - Pieces

private struct StatItem: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("Poppins-Regular", size: 14.83)) // Figma font & size
                .multilineTextAlignment(.center)               // text-align: center
                .foregroundColor(Color.alabaster.opacity(0.7)) // color with opacity
                .lineSpacing(0)                                // line-height: 100%
                
            Text(title)
                .font(.custom("Poppins-Regular", size: 14.83)) // Figma font & size
                .multilineTextAlignment(.center)               // text-align: center
                .foregroundColor(Color.alabaster.opacity(0.7)) // color with opacity
                .lineSpacing(0)                                // line-height: 100%
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

/// Simple sun + clouds vector built in SwiftUI to avoid assets.
private struct WeatherIcon: View {
    let sun: Color
    let cloud: Color

    var body: some View {
        ZStack {
            // Sun
            Circle()
                .fill(sun)
                .frame(width: 46, height: 46)
                .offset(x: 6, y: -6)
                .overlay(
                    // sun rays
                    ZStack {
                        ForEach(0..<8, id: \.self) { i in
                            Capsule()
                                .fill(sun.opacity(0.9))
                                .frame(width: 18, height: 4)
                                .offset(x: 34)
                                .rotationEffect(.degrees(Double(i) * 45))
                        }
                    }
                    .opacity(0.9)
                )

            // Back cloud (darker)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cloud.opacity(0.55))
                .frame(width: 88, height: 52)
                .offset(x: 12, y: 16)

            // Front cloud
            HStack(spacing: -10) {
                Circle().fill(cloud).frame(width: 48, height: 48)
                Circle().fill(cloud).frame(width: 40, height: 40).offset(y: 4)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cloud)
                    .frame(width: 70, height: 40)
                    .offset(y: 6)
            }
            .offset(x: -8, y: 18)
        }
        .compositingGroup()
    }
}


// MARK: - Preview

struct WeatherWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherWidgetView()
//            .previewLayout(.sizeThatFits)
//            .padding()
            .background(Color.themeBlack) // show outer glow nicely
            .preferredColorScheme(.dark)
    }
}

// MARK: - Weather Fetching

private extension WeatherWidgetView {
    func fetchWeather(for location: CLLocation) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let weather = try await WeatherService.shared.fetchWeather(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )

                await MainActor.run {
                    self.weatherData = weather
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
