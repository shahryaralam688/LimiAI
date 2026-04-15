import SwiftUI
import UIKit

enum AppTheme {
    enum Palette {
        static let themeWhite = Color(hex: "FFFFFF")
        static let themeBlack = Color(hex: "000000")

        // Deep Space brand — purple/blue/neon
        static let brandPrimary = Color(hex: "54BA73")
        static let brandSecondary = Color(hex: "76E094")
        static let brandTertiary = Color(hex: "51D18E")
        static let brandAccent = Color(hex: "00FF8C")

        // Deep Space canvas
        static let canvasPrimary = Color(hex: "0B0B0F")
        static let canvasSecondary = Color(hex: "0D0D12")
        static let canvasTertiary = Color(hex: "080810")
        static let canvasElevated = Color(hex: "131318")
        static let canvasStrong = Color(hex: "16161C")
        static let canvasMuted = Color(hex: "1A1A22")
        static let canvasHotel = Color(hex: "1E1E28")

        // Glass surfaces — slightly lighter, translucent feel
        static let surfacePrimary = Color(hex: "1C1C26")
        static let surfaceSecondary = Color(hex: "22222E")
        static let surfaceSecondaryAlt = Color(hex: "24243A")
        static let surfaceTertiary = Color(hex: "2A2A38")
        static let surfaceQuaternary = Color(hex: "32323E")
        static let surfaceFloating = Color(hex: "1A1A28")
        static let surfaceDark = Color(hex: "141420")
        static let surfaceDarker = Color(hex: "10101A")
        static let surfaceDeep = Color(hex: "12121C")
        static let surfacePanel = Color(hex: "181824")
        static let surfaceInset = Color(hex: "161620")
        static let surfaceInsetAlt = Color(hex: "161622")
        static let surfaceCard = Color(hex: "1E1E2C")
        static let surfaceNeutral = Color(hex: "242430")
        static let surfaceNeutralAlt = Color(hex: "2E2E3A")
        static let surfaceStroke = Color(hex: "3A3A4E")
        static let surfaceField = Color(hex: "44445A")
        static let surfaceChip = Color(hex: "55556A")

        static let textPrimary = Color(hex: "F0ECF8")
        static let textSecondary = Color(hex: "B8B4C8")
        static let textTertiary = Color(hex: "9490A8")
        static let textMuted = Color(hex: "7A7690")
        static let textSubtle = Color(hex: "8884A0")
        static let textInverse = Color(hex: "0B0B0F")
        static let textQuiet = Color(hex: "E8E4F0")
        static let textPlaceholder = Color(hex: "6E6A84")
        static let textDisabled = Color(hex: "5A5670")
        static let textSoft = Color(hex: "D8D4E8")

        static let borderPrimary = Color(hex: "3A3A50")
        static let borderSecondary = Color(hex: "4A4A60")
        static let borderTertiary = Color(hex: "2E2E44")
        static let borderQuaternary = Color(hex: "2C2C42")
        static let borderSoft = Color(hex: "4E4E68")
        static let borderSubtle = Color(hex: "5A5A70")
        static let borderField = Color(hex: "4A4A64")

        static let success = Color(hex: "2ECC71")
        static let successDark = Color(hex: "17543B")
        static let successDeep = Color(hex: "052010")
        static let warning = Color(hex: "FFEB85")
        static let danger = Color(hex: "FF9292")
        static let dangerStrong = Color(hex: "FF0000")

        static let info = Color(hex: "19C6D7")
        static let infoBright = Color(hex: "6FE8F0")
        static let infoDark = Color(hex: "00A5C9")
        static let aiBlue = Color(hex: "00A5C9")
        static let aiBlueDark = Color(hex: "01101C")

        static let yellow = Color(hex: "FFFF00")
        static let orange = Color(hex: "FFA500")
        static let pink = Color(hex: "FFC0CB")
        static let purple = Color(hex: "9B5DE5")
        static let indigo = Color(hex: "6366F1")

        static let sliderLight = Color(hex: "DDDDDD")
        static let sliderMid = Color(hex: "999999")
        static let sliderDark = Color(hex: "444444")
        static let sliderThumb = Color(hex: "202020")
        static let warmGlow = Color(hex: "FFE4B5")

        static let weatherTop = Color(red: 0.0, green: 0.44, blue: 0.6)
        static let weatherBottom = Color(red: 0.01, green: 0.06, blue: 0.11)
        static let weatherBackground = Color(red: 0.01, green: 0.07, blue: 0.12)
        static let weatherText = Color(red: 0.63, green: 0.72, blue: 0.8)

        static let aiGradientStart = Color(hex: "1A1040")
        static let aiGradientEnd = Color(hex: "0A0818")
        static let chatUserBubble = Color(hex: "6C5CE7")
        static let chatUserBubbleAlt = Color(hex: "A78BFA")
        static let chatSend = Color(hex: "7C3AED")
        static let chatBar = Color(hex: "1A1A28")
        static let neutralLight = Color(red: 0.96, green: 0.96, blue: 0.96)
        static let neutralMid = Color(red: 0.95, green: 0.95, blue: 0.95)
        static let neutralGray = Color(red: 0.5, green: 0.5, blue: 0.5)
        static let placeholderGray = Color(red: 176 / 255, green: 176 / 255, blue: 176 / 255)

        static let inputFill = Color(hex: "181824")
        static let eton = Color(hex: "A78BFA")
        static let alabaster = Color(hex: "F0ECF8")
        static let charlestonGreen = Color(hex: "0B0B0F")
        static let darkGray = Color(red: 0.3, green: 0.3, blue: 0.3)
        static let darkBrown = Color(red: 0.4, green: 0.25, blue: 0.2)
        static let grass = Color(red: 0.0, green: 0.5, blue: 0.0)
        static let mint = Color(hex: "34D399")
        static let spotlightWarm = Color(red: 1.0, green: 0.95, blue: 0.8)
        static let spotlightCool = Color(red: 0.8, green: 0.9, blue: 1.0)
        static let aqua = Color(hex: "67E8F9")
        static let accentMuted = Color(hex: "46A663")
        static let accentLime = Color(hex: "43EB25")
        static let brick = Color(red: 0.7, green: 0.3, blue: 0.2)
        static let tan = Color(red: 0.85, green: 0.7, blue: 0.45)
        static let overlayTint = Color(hex: "00000066")

        // Deep Space accent gradients (Emerald)
        static let orbGlow1 = Color(hex: "059669")
        static let orbGlow2 = Color(hex: "047857")
        static let orbGlow3 = Color(hex: "34D399")
        static let orbGlow4 = Color(hex: "10B981")
        static let glassStroke = Color(hex: "FFFFFF").opacity(0.08)
        static let glassFill = Color(hex: "FFFFFF").opacity(0.04)
    }
}

enum AppThemeDefaults {
    static let selectedColorHex = "059669"
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static func fromHex(_ hex: String) -> Color {
        Color(hex: hex)
    }

    static let themeWhite = AppTheme.Palette.themeWhite
    static let themeBlack = AppTheme.Palette.themeBlack

    static let emerald = AppTheme.Palette.brandPrimary
    static let eton = AppTheme.Palette.eton
    static let charlestonGreen = AppTheme.Palette.charlestonGreen
    static let alabaster = AppTheme.Palette.alabaster

    static let appBrandPrimary = AppTheme.Palette.brandPrimary
    static let appBrandSecondary = AppTheme.Palette.brandSecondary
    static let appBrandTertiary = AppTheme.Palette.brandTertiary
    static let appBrandAccent = AppTheme.Palette.brandAccent

    static let appCanvasPrimary = AppTheme.Palette.canvasPrimary
    static let appCanvasSecondary = AppTheme.Palette.canvasSecondary
    static let appCanvasTertiary = AppTheme.Palette.canvasTertiary
    static let appCanvasElevated = AppTheme.Palette.canvasElevated
    static let appCanvasStrong = AppTheme.Palette.canvasStrong
    static let appCanvasMuted = AppTheme.Palette.canvasMuted
    static let appCanvasHotel = AppTheme.Palette.canvasHotel

    static let appSurfacePrimary = AppTheme.Palette.surfacePrimary
    static let appSurfaceSecondary = AppTheme.Palette.surfaceSecondary
    static let appSurfaceSecondaryAlt = AppTheme.Palette.surfaceSecondaryAlt
    static let appSurfaceTertiary = AppTheme.Palette.surfaceTertiary
    static let appSurfaceQuaternary = AppTheme.Palette.surfaceQuaternary
    static let appSurfaceFloating = AppTheme.Palette.surfaceFloating
    static let appSurfaceDark = AppTheme.Palette.surfaceDark
    static let appSurfaceDarker = AppTheme.Palette.surfaceDarker
    static let appSurfaceDeep = AppTheme.Palette.surfaceDeep
    static let appSurfacePanel = AppTheme.Palette.surfacePanel
    static let appSurfaceInset = AppTheme.Palette.surfaceInset
    static let appSurfaceInsetAlt = AppTheme.Palette.surfaceInsetAlt
    static let appSurfaceCard = AppTheme.Palette.surfaceCard
    static let appSurfaceNeutral = AppTheme.Palette.surfaceNeutral
    static let appSurfaceNeutralAlt = AppTheme.Palette.surfaceNeutralAlt
    static let appSurfaceStroke = AppTheme.Palette.surfaceStroke
    static let appSurfaceField = AppTheme.Palette.surfaceField
    static let appSurfaceChip = AppTheme.Palette.surfaceChip
    static let appInputFill = AppTheme.Palette.inputFill

    static let appTextPrimary = AppTheme.Palette.textPrimary
    static let appTextSecondary = AppTheme.Palette.textSecondary
    static let appTextTertiary = AppTheme.Palette.textTertiary
    static let appTextMuted = AppTheme.Palette.textMuted
    static let appTextSubtle = AppTheme.Palette.textSubtle
    static let appTextInverse = AppTheme.Palette.textInverse
    static let appTextQuiet = AppTheme.Palette.textQuiet
    static let appTextPlaceholder = AppTheme.Palette.textPlaceholder
    static let appTextDisabled = AppTheme.Palette.textDisabled
    static let appTextSoft = AppTheme.Palette.textSoft

    static let appBorderPrimary = AppTheme.Palette.borderPrimary
    static let appBorderSecondary = AppTheme.Palette.borderSecondary
    static let appBorderTertiary = AppTheme.Palette.borderTertiary
    static let appBorderQuaternary = AppTheme.Palette.borderQuaternary
    static let appBorderSoft = AppTheme.Palette.borderSoft
    static let appBorderSubtle = AppTheme.Palette.borderSubtle
    static let appBorderField = AppTheme.Palette.borderField

    static let appSuccess = AppTheme.Palette.success
    static let appSuccessDark = AppTheme.Palette.successDark
    static let appSuccessDeep = AppTheme.Palette.successDeep
    static let appWarning = AppTheme.Palette.warning
    static let appDanger = AppTheme.Palette.danger
    static let appDangerStrong = AppTheme.Palette.dangerStrong
    static let appInfo = AppTheme.Palette.info
    static let appInfoBright = AppTheme.Palette.infoBright
    static let appInfoDark = AppTheme.Palette.infoDark

    static let appYellow = AppTheme.Palette.yellow
    static let appOrange = AppTheme.Palette.orange
    static let appPink = AppTheme.Palette.pink
    static let appPurple = AppTheme.Palette.purple
    static let appIndigo = AppTheme.Palette.indigo

    static let appSliderLight = AppTheme.Palette.sliderLight
    static let appSliderMid = AppTheme.Palette.sliderMid
    static let appSliderDark = AppTheme.Palette.sliderDark
    static let appSliderThumb = AppTheme.Palette.sliderThumb
    static let appWarmGlow = AppTheme.Palette.warmGlow

    static let appWeatherTop = AppTheme.Palette.weatherTop
    static let appWeatherBottom = AppTheme.Palette.weatherBottom
    static let appWeatherBackground = AppTheme.Palette.weatherBackground
    static let appWeatherText = AppTheme.Palette.weatherText

    static let appAIGradientStart = AppTheme.Palette.aiGradientStart
    static let appAIGradientEnd = AppTheme.Palette.aiGradientEnd
    static let appChatUserBubble = AppTheme.Palette.chatUserBubble
    static let appChatUserBubbleAlt = AppTheme.Palette.chatUserBubbleAlt
    static let appChatSend = AppTheme.Palette.chatSend
    static let appChatBar = AppTheme.Palette.chatBar
    static let appNeutralLight = AppTheme.Palette.neutralLight
    static let appNeutralMid = AppTheme.Palette.neutralMid
    static let appNeutralGray = AppTheme.Palette.neutralGray
    static let appPlaceholderGray = AppTheme.Palette.placeholderGray
    static let appBrick = AppTheme.Palette.brick
    static let appTan = AppTheme.Palette.tan
    static let appOverlayTint = AppTheme.Palette.overlayTint
    static let mint = AppTheme.Palette.mint
    static let aqua = AppTheme.Palette.aqua
    static let spotlightWarm = AppTheme.Palette.spotlightWarm
    static let spotlightCool = AppTheme.Palette.spotlightCool

    static let darkRed = AppTheme.Palette.dangerStrong
    static let darkGreen = AppTheme.Palette.grass
    static let darkBlue = AppTheme.Palette.infoDark
    static let orange = AppTheme.Palette.orange
    static let yellow = AppTheme.Palette.yellow
    static let indigo = AppTheme.Palette.indigo
    static let purple = AppTheme.Palette.purple
    static let pink = AppTheme.Palette.pink
    static let darkGray = AppTheme.Palette.darkGray
    static let darkBrown = AppTheme.Palette.darkBrown

    static let backgroundColor = AppTheme.Palette.canvasPrimary
    static let cardColor = AppTheme.Palette.surfaceCard
    static let primaryAccent = AppTheme.Palette.brandPrimary
    static let secondaryAccent = AppTheme.Palette.eton

    // Deep Space gradients
    static let orbGlow1 = AppTheme.Palette.orbGlow1
    static let orbGlow2 = AppTheme.Palette.orbGlow2
    static let orbGlow3 = AppTheme.Palette.orbGlow3
    static let orbGlow4 = AppTheme.Palette.orbGlow4

    static let verticalGradient = LinearGradient(
        gradient: Gradient(colors: [AppTheme.Palette.orbGlow4.opacity(0.4), AppTheme.Palette.brandPrimary]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let deepSpaceGradient = LinearGradient(
        colors: [AppTheme.Palette.canvasPrimary, AppTheme.Palette.canvasTertiary],
        startPoint: .top,
        endPoint: .bottom
    )

    static let orbAuraGradient = RadialGradient(
        colors: [
            AppTheme.Palette.orbGlow1.opacity(0.6),
            AppTheme.Palette.orbGlow2.opacity(0.3),
            AppTheme.Palette.orbGlow3.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 40,
        endRadius: 200
    )

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )
    }
}

extension UIColor {
    static let appWhite = UIColor(Color.themeWhite)
    static let appBlack = UIColor(Color.themeBlack)
    static let appCanvasPrimary = UIColor(Color.appCanvasPrimary)
    static let appSurfacePrimary = UIColor(Color.appSurfacePrimary)
    static let appBrandPrimary = UIColor(Color.appBrandPrimary)
    static let appTextPrimary = UIColor(Color.appTextPrimary)
    static let appBorderPrimary = UIColor(Color.appBorderPrimary)
}
