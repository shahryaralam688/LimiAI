# Limi AI - Theme System Guide

## Overview

This project uses a centralized theme system defined in `LimiExhibition/Color/Color.swift`. **All colors must use these theme constants** — no hardcoded colors allowed.

---

## Quick Reference

### Import
```swift
import SwiftUI
// Color extensions are automatically available
```

### Most Common Colors

| Usage | Color Token | Example |
|-------|-------------|---------|
| App Background (Dark) | `.appCanvasPrimary` or `.themeBlack` | Main screens |
| App Background (Light) | `.alabaster` | Light theme areas |
| Card/Surface Background | `.appSurfacePrimary` | Cards, panels |
| Primary Text | `.appTextPrimary` | Headlines, body |
| Secondary Text | `.appTextSecondary` | Subtitles, hints |
| Muted Text | `.appTextMuted` | Disabled, placeholders |
| Primary Brand/Accent | `.appBrandPrimary` | Buttons, highlights |
| Secondary Brand | `.eton` or `.appBrandSecondary` | Secondary actions |
| Success | `.appSuccess` | Success states |
| Warning | `.appWarning` | Alerts, cautions |
| Danger/Error | `.appDanger` | Errors, destructive |
| Borders | `.appBorderPrimary` | Dividers, outlines |

---

## Color Architecture

### 1. Base Colors
```swift
Color.themeWhite    // #FFFFFF
Color.themeBlack    // #000000
```

### 2. Brand Colors (Green Emerald Theme)
```swift
Color.appBrandPrimary    // #54BA73 - Main brand
Color.appBrandSecondary  // #76E094
Color.appBrandTertiary   // #51D18E
Color.appBrandAccent     // #00FF8C - Bright accent
Color.emerald            // Alias for brandPrimary
Color.eton               // #93CFA2 - Soft green
```

### 3. Canvas Colors (App Backgrounds)
```swift
Color.appCanvasPrimary    // #111214 - Main dark bg
Color.appCanvasSecondary  // #101217
Color.appCanvasTertiary   // #0B0E0C
Color.appCanvasElevated   // #171717 - Elevated surfaces
Color.appCanvasStrong     // #191B1E
Color.appCanvasHotel      // #292929 - Hotel module bg
```

### 4. Surface Colors (Cards, Panels)
```swift
Color.appSurfacePrimary       // #24262B
Color.appSurfaceSecondary     // #2A2C33
Color.appSurfaceTertiary      // #393C43
Color.appSurfaceCard          // #2C2F33
Color.appSurfaceFloating      // #22242A
Color.appSurfaceInset         // #1C1C1C
Color.appSurfacePanel         // #1F2126
Color.appSurfaceStroke        // #484848 - Borders
```

### 5. Text Colors
```swift
Color.appTextPrimary    // #F2EBE3 - Main text
Color.appTextSecondary  // #C9C4BD - Secondary
Color.appTextTertiary   // #B6BAC2
Color.appTextMuted      // #A19D98 - Disabled
Color.appTextSubtle     // #9AA0A6
Color.appTextInverse    // #111111 - For light bg
Color.appTextQuiet      // #E9E9E9
```

### 6. Semantic Colors
```swift
// Success
Color.appSuccess        // #2ECC71
Color.appSuccessDark    // #17543B

// Warning
Color.appWarning        // #FFEB85 (Yellow)

// Danger/Error
Color.appDanger         // #FF9292
Color.appDangerStrong   // #FF0000

// Info
Color.appInfo           // #19C6D7
Color.appInfoBright     // #6FE8F0
Color.appInfoDark       // #00A5C9
```

### 7. Component-Specific
```swift
// AI/Voice
Color.appAIGradientStart    // AI bg gradient start
Color.appAIGradientEnd      // AI bg gradient end
Color.appChatUserBubble     // User message bubble
Color.appChatBar            // Chat input bar

// Weather
Color.appWeatherBackground  // Weather widget bg
Color.appWeatherText        // Weather text

// Lighting Controls
Color.appSliderLight        // Slider track light
Color.appSliderDark         // Slider track dark
Color.appWarmGlow           // Warm light tint
Color.spotlightWarm         // Spotlight warm
Color.spotlightCool         // Spotlight cool
```

---

## Usage Patterns

### Backgrounds
```swift
// CORRECT
ZStack {
    Color.appCanvasPrimary.ignoresSafeArea()
    // content
}

// WRONG ❌
ZStack {
    Color.black.ignoresSafeArea()
    // or
    Color(hex: "111214").ignoresSafeArea()
}
```

### Text
```swift
// CORRECT
Text("Hello")
    .foregroundColor(.appTextPrimary)

Text("Subtitle")
    .foregroundColor(.appTextSecondary)

// WRONG ❌
Text("Hello")
    .foregroundColor(.white)
    .foregroundColor(Color(hex: "F2EBE3"))
```

### Buttons
```swift
// CORRECT
Button(action: {}) {
    Text("Save")
        .foregroundColor(.themeWhite)
}
.background(Color.appBrandPrimary)

// WRONG ❌
.background(Color.green)
.background(Color(hex: "54BA73"))
```

### Cards/Surfaces
```swift
// CORRECT
RoundedRectangle(cornerRadius: 12)
    .fill(Color.appSurfacePrimary)
    .stroke(Color.appBorderPrimary, lineWidth: 1)

// WRONG ❌
.fill(Color(hex: "24262B"))
.stroke(Color.gray, lineWidth: 1)
```

### Gradients
```swift
// CORRECT
LinearGradient(
    colors: [.appAIGradientStart, .appAIGradientEnd],
    startPoint: .top,
    endPoint: .bottom
)

// Or use predefined
Color.verticalGradient
```

---

## Migration Checklist

When working on a file, check for these patterns and replace:

- [ ] `Color.black` → `.themeBlack` or `.appCanvasPrimary`
- [ ] `Color.white` → `.themeWhite` or `.appTextPrimary`
- [ ] `Color.gray` → `.appTextMuted` or `.appBorderPrimary`
- [ ] `Color.red` → `.appDanger`
- [ ] `Color.green` → `.appSuccess` or `.appBrandPrimary`
- [ ] `Color.blue` → `.appInfo`
- [ ] `Color.yellow` → `.appWarning`
- [ ] `Color.orange` → `.appOrange`
- [ ] `Color(hex: "...")` → matching theme color
- [ ] `Color(red: x, green: y, blue: z)` → matching theme color
- [ ] `.opacity(x)` on colors → use theme's opacity variant if exists

---

## For Designers

### Adding New Colors

1. Add to `AppTheme.Palette` enum in `Color.swift`
2. Create Color extension static var
3. Update this guide
4. **Never use the color directly by hex** — always through theme

### Color Naming Convention

```
[Category][Variant][Modifier]

Examples:
- appCanvasPrimary (category: canvas, variant: primary)
- appSurfaceElevated (category: surface, variant: elevated)
- appTextMuted (category: text, variant: muted)
- appSuccessDark (category: success, modifier: dark)
```

---

## Files with Hardcoded Colors (Needs Cleanup)

Priority files to clean up (most violations):
1. `AI ChatBot/VoiceView.swift` (28 violations)
2. `Hotel Module/HotelHomeView.swift` (26 violations)
3. `Onboard/GlowOrbView.swift` (20 violations)
4. `ARSession/TastingAR.swift` (19 violations)
5. `HomeView/WeatherWidgetView.swift` (17 violations)

---

## Best Practices

1. **Always use theme colors** — never hardcode
2. **Use semantic names** — `.appSuccess` not `.appBrandPrimary` for success states
3. **For opacity** — prefer defined variants over `.opacity()`
4. **For gradients** — use predefined or theme colors
5. **For dynamic themes** — the system supports light/dark via theme switching

---

## Example Refactor

### Before ❌
```swift
VStack {
    Text("Title")
        .foregroundColor(.white)
    Text("Description")
        .foregroundColor(Color(hex: "9AA0A6"))
}
.background(Color.black)
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray, lineWidth: 1)
)
```

### After ✅
```swift
VStack {
    Text("Title")
        .foregroundColor(.appTextPrimary)
    Text("Description")
        .foregroundColor(.appTextSubtle)
}
.background(Color.appCanvasPrimary)
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.appBorderPrimary, lineWidth: 1)
)
```
