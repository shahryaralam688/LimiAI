import SwiftUI
import CoreLocation

struct WeatherWidgetView: View {
    @StateObject private var vm = WeatherViewModel()
    @Binding var isExpanded: Bool
    private let contextManager: HomeContextManaging

    init(
        isExpanded: Binding<Bool> = .constant(true),
        contextManager: HomeContextManaging = DefaultHomeContextManager()
    ) {
        self._isExpanded = isExpanded
        self.contextManager = contextManager
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
            contextManager.updateHomeWeather(
                city: vm.cityName,
                condition: vm.conditionDescription,
                tempC: vm.temperature,
                feelsLikeC: vm.feelsLike
            )
        }
        .onChange(of: vm.cityName) { _, _ in
            guard vm.weatherData != nil else { return }
            contextManager.updateHomeWeather(
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
            if isExpanded {
                RoundedRectangle(cornerRadius: LimiCard.radiusLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: vm.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LimiCard.radiusLarge, style: .continuous)
                            .fill(Color.appCanvasPrimary.opacity(0.12))
                    )
            } else {
                RoundedRectangle(cornerRadius: LimiCard.radius, style: .continuous)
                    .fill(LimiGradients.weatherAccent)
            }

            Group {
                if isExpanded {
                    expandedCardContent
                } else {
                    compactCardContent
                }
            }
        }
        .frame(height: isExpanded ? LimiCard.weatherExpandedHeight : LimiCard.weatherCompactHeight)
        .limiHomeCard(cornerRadius: isExpanded ? LimiCard.radiusLarge : LimiCard.radius)
        .shadow(
            color: isExpanded
                ? (vm.gradientColors.first?.opacity(0.2) ?? Color.brandAction.opacity(0.1))
                : Color.brandAction.opacity(0.06),
            radius: isExpanded ? 16 : 8,
            y: isExpanded ? 8 : 4
        )
    }

    // MARK: - Expanded Card

    private var expandedCardContent: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(LimiTypography.caption)
                    Text(vm.cityName.isEmpty ? "Locating..." : vm.cityName)
                        .font(LimiTypography.callout)
                }
                .foregroundColor(.appTextPrimary.opacity(0.9))

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { vm.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(LimiTypography.footnote)
                            .foregroundColor(.appTextPrimary.opacity(0.6))
                    }
                    Image(systemName: "chevron.up")
                        .font(LimiTypography.caption)
                        .foregroundColor(.appTextPrimary.opacity(0.4))
                }
            }

            Spacer().frame(height: 2)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(vm.temperature)")
                            .font(LimiTypography.title2)
                            .foregroundColor(.appTextPrimary)
                        Text("°")
                            .font(LimiTypography.title2)
                            .foregroundColor(.appTextPrimary.opacity(0.8))
                            .padding(.top, 8)
                    }
                    Text(vm.conditionDescription)
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary.opacity(0.85))
                }

                Spacer()

                Image(systemName: vm.sfSymbol)
                    .font(LimiTypography.title2)
                    .foregroundStyle(iconGradient)
                    .shadow(color: iconShadow, radius: 12, y: 4)
                    .padding(.top, 8)
            }

            HStack {
                Text("Feels like \(vm.feelsLike)°")
                    .font(LimiTypography.footnote)
                    .foregroundColor(.appTextPrimary.opacity(0.6))
                Spacer()
                Text(vm.day)
                    .font(LimiTypography.footnote)
                    .foregroundColor(.appTextPrimary.opacity(0.6))
            }
        }
        .padding(20)
    }

    // MARK: - Compact Card (minimized)

    private var compactCardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: vm.sfSymbol)
                .font(LimiTypography.title2)
                .foregroundStyle(iconGradient)
                .shadow(color: iconShadow, radius: 6, y: 2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.cityName.isEmpty ? "Locating..." : vm.cityName)
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary.opacity(0.9))
                Text(vm.conditionDescription)
                    .font(LimiTypography.caption)
                    .foregroundColor(.appTextPrimary.opacity(0.6))
            }

            Spacer()

            HStack(alignment: .top, spacing: 0) {
                Text("\(vm.temperature)")
                    .font(LimiTypography.title2)
                    .foregroundColor(.appTextPrimary)
                Text("°")
                    .font(LimiTypography.body)
                    .foregroundColor(.appTextPrimary.opacity(0.7))
                    .padding(.top, 4)
            }

            Image(systemName: "chevron.down")
                .font(LimiTypography.caption)
                .foregroundColor(.appTextPrimary.opacity(0.4))
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
                            .font(LimiTypography.caption2)
                            .foregroundColor(item.isNow ? .brandAction : .appTextSecondary)

                        Image(systemName: item.icon)
                            .font(LimiTypography.body)
                            .foregroundStyle(
                                item.isNow
                                ? AnyShapeStyle(LinearGradient(colors: LimiGradients.ctaColors, startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.appTextMuted)
                            )
                            .frame(height: 20)

                        Text("\(item.temp)°")
                            .font(LimiTypography.callout)
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
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandAction))
            Text("Loading weather...")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: LimiCard.weatherCompactHeight)
        .limiHomeCard(cornerRadius: LimiCard.radius)
        .padding(.horizontal, 16)
    }

    private func errorState(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.slash.fill")
                .font(LimiTypography.title3)
                .foregroundColor(.brandHighlight)
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather unavailable")
                    .font(LimiTypography.callout)
                    .foregroundColor(.appTextPrimary)
                Text(message)
                    .font(LimiTypography.caption2)
                    .foregroundColor(.appTextMuted)
                    .lineLimit(1)
            }
            Spacer()
            Button("Retry") { vm.refresh() }
                .font(LimiTypography.footnote)
                .foregroundColor(.brandAction)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: LimiCard.weatherCompactHeight)
        .limiHomeCard(cornerRadius: LimiCard.radius)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var iconGradient: some ShapeStyle {
        LinearGradient(
            colors: vm.isDaytime
                ? [Color.appWarmGlow, Color.appOrange.opacity(0.85)]
                : [Color.brandHighlight, Color.brandHighlight.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconShadow: Color {
        vm.isDaytime ? Color.appWarmGlow.opacity(0.35) : Color.brandHighlight.opacity(0.25)
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
                .font(LimiTypography.body)
                .foregroundColor(.brandHighlight)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LimiTypography.caption2)
                    .foregroundColor(.appTextMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(LimiTypography.headline)
                    .foregroundColor(.appTextPrimary)
            }
            Spacer()
        }
        .padding(14)
        .limiHomeCard(cornerRadius: 14)
    }
}

#Preview {
    WeatherWidgetView(isExpanded: .constant(true))
        .background(Color.appCanvasPrimary)
        .preferredColorScheme(.dark)
}
