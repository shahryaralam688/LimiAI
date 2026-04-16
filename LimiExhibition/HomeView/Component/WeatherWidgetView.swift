import SwiftUI
import CoreLocation

struct WeatherWidgetView: View {
    @StateObject private var vm = WeatherViewModel()
    @Binding var isExpanded: Bool

    init(isExpanded: Binding<Bool> = .constant(true)) {
        self._isExpanded = isExpanded
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading && vm.weatherData == nil {
                loadingState
            } else if let error = vm.errorMessage, vm.weatherData == nil {
                errorState(error)
            } else {
                weatherContent
            }
        }
        .onAppear { vm.startFetching() }
        .onChange(of: vm.temperature) { _, _ in
            guard vm.weatherData != nil else { return }
            ContextManager.shared.updateHomeWeather(
                city: vm.cityName,
                condition: vm.conditionDescription,
                tempC: vm.temperature,
                feelsLikeC: vm.feelsLike
            )
        }
        .onChange(of: vm.cityName) { _, _ in
            guard vm.weatherData != nil else { return }
            ContextManager.shared.updateHomeWeather(
                city: vm.cityName,
                condition: vm.conditionDescription,
                tempC: vm.temperature,
                feelsLikeC: vm.feelsLike
            )
        }
    }

    // MARK: - Content

    private var weatherContent: some View {
        VStack(spacing: isExpanded ? 12 : 0) {
            mainCard
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                hourlyStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))

                detailsGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: vm.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )

            if isExpanded {
                expandedCardContent
            } else {
                compactCardContent
            }
        }
        .frame(height: isExpanded ? 200 : 80)
        .shadow(color: vm.gradientColors.first?.opacity(0.25) ?? .clear, radius: isExpanded ? 20 : 10, y: isExpanded ? 10 : 4)
    }

    // MARK: - Expanded Card

    private var expandedCardContent: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(vm.cityName.isEmpty ? "Locating..." : vm.cityName)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { vm.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer().frame(height: 2)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(vm.temperature)")
                            .font(.system(size: 72, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                        Text("°")
                            .font(.system(size: 36, weight: .thin, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                    }
                    Text(vm.conditionDescription)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: vm.sfSymbol)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(iconGradient)
                    .shadow(color: iconShadow, radius: 12, y: 4)
                    .padding(.top, 8)
            }

            HStack {
                Text("Feels like \(vm.feelsLike)°")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(vm.day)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(20)
    }

    // MARK: - Compact Card (minimized)

    private var compactCardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: vm.sfSymbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(iconGradient)
                .shadow(color: iconShadow, radius: 6, y: 2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.cityName.isEmpty ? "Locating..." : vm.cityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(vm.conditionDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            HStack(alignment: .top, spacing: 0) {
                Text("\(vm.temperature)")
                    .font(.system(size: 34, weight: .thin, design: .rounded))
                    .foregroundColor(.white)
                Text("°")
                    .font(.system(size: 18, weight: .thin))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Hourly Strip

    private var hourlyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vm.hourlyForecast) { item in
                    VStack(spacing: 8) {
                        Text(item.hour)
                            .font(.system(size: 11, weight: item.isNow ? .bold : .medium))
                            .foregroundColor(item.isNow ? .orbGlow4 : .appTextSecondary)

                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(
                                item.isNow
                                ? AnyShapeStyle(LinearGradient(colors: [.orbGlow4, .orbGlow3], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.appTextMuted)
                            )
                            .frame(height: 20)

                        Text("\(item.temp)°")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    .frame(width: 48)
                    .padding(.vertical, 10)
                    .glassCard(
                        cornerRadius: 14,
                        strokeOpacity: item.isNow ? 0.15 : 0.04,
                        fillOpacity: item.isNow ? 0.08 : 0.03
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            WeatherDetailCell(icon: "humidity.fill", title: "Humidity", value: "\(vm.humidity)%")
            WeatherDetailCell(icon: "wind", title: "Wind", value: "\(vm.windSpeed) km/h")
            WeatherDetailCell(icon: "gauge.medium", title: "Pressure", value: "\(vm.pressure) hPa")
            WeatherDetailCell(icon: "eye.fill", title: "Visibility", value: vm.visibility)
        }
    }

    // MARK: - Loading & Error

    private var loadingState: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .frame(height: 80)
            .overlay(
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orbGlow4))
                    Text("Loading weather...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextMuted)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
    }

    private func errorState(_ message: String) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .frame(height: 80)
            .overlay(
                HStack(spacing: 12) {
                    Image(systemName: "cloud.slash.fill")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.appTextMuted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather unavailable")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.appTextMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Retry") { vm.refresh() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orbGlow4)
                }
                .padding(.horizontal, 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var iconGradient: some ShapeStyle {
        LinearGradient(
            colors: vm.isDaytime
                ? [.yellow, .orange.opacity(0.8)]
                : [.white, .white.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconShadow: Color {
        vm.isDaytime ? .yellow.opacity(0.4) : .white.opacity(0.15)
    }
}

// MARK: - Detail Cell

private struct WeatherDetailCell: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orbGlow3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appTextMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 14, fillOpacity: 0.04)
    }
}

#Preview {
    WeatherWidgetView(isExpanded: .constant(true))
        .background(Color.appCanvasPrimary)
        .preferredColorScheme(.dark)
}
