import SwiftUI

enum HubChannelKind {
    case pwm
    case rgb
}

/// Shared channel control state for hub PWM/RGB views (Phase H).
@MainActor
final class HubChannelControlViewModel: ObservableObject {
    @Published var isOn: Bool
    @Published var brightness: Double
    @Published var warmCold: Double
    @Published var selectedColorHex: String
    @Published var selectedColor: Color

    let hub: Hub
    let kind: HubChannelKind

    init(hub: Hub, kind: HubChannelKind) {
        self.hub = hub
        self.kind = kind

        switch kind {
        case .pwm:
            self.isOn = UserDefaults.standard.object(forKey: "lampPWM") as? Bool ?? false
            self.brightness = UserDefaults.standard.object(forKey: "led2Brightness") as? Double ?? 50
            self.warmCold = UserDefaults.standard.object(forKey: "led1WarmCold") as? Double ?? 50
            let hex = AppThemeDefaults.selectedColorHex
            self.selectedColorHex = hex
            self.selectedColor = Color(hex: hex)
        case .rgb:
            self.isOn = UserDefaults.standard.object(forKey: "lampRGB") as? Bool ?? false
            self.brightness = UserDefaults.standard.object(forKey: "RGBBrightness") as? Double ?? 50
            self.warmCold = 50
            let hex = UserDefaults.standard.string(forKey: "selectedColorHex") ?? AppThemeDefaults.selectedColorHex
            self.selectedColorHex = hex
            self.selectedColor = Color(hex: hex)
        }
    }

    func persistPWMState() {
        UserDefaults.standard.set(isOn, forKey: "lampPWM")
        UserDefaults.standard.set(brightness, forKey: "led2Brightness")
        UserDefaults.standard.set(warmCold, forKey: "led1WarmCold")
    }

    func persistRGBState() {
        UserDefaults.standard.set(isOn, forKey: "lampRGB")
        UserDefaults.standard.set(brightness, forKey: "RGBBrightness")
        UserDefaults.standard.set(selectedColorHex, forKey: "selectedColorHex")
    }

    func updateSelectedColor(_ color: Color) {
        selectedColor = color
        selectedColorHex = color.toHexRGB()
    }
}

private extension Color {
    func toHexRGB() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
