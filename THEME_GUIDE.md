# Limi AI - Theme System Guide

## Overview

This project uses a centralized theme system defined in `Core/DesignSystem/Color.swift`. **All colors must use these theme constants** — no hardcoded colors allowed.

Official brand source: `BrandAssets/LIMI_Initial_Presentation_V02.pdf`

---

## Official Brand Palette (PDF)

| Name | Hex | Token | Use |
|------|-----|-------|-----|
| Charleston Green | `#292929` | `.charlestonGreen`, `.appCanvasHotel` | Hotel bg, dark surfaces |
| Eton Blue | `#93CFA2` | `.eton`, `.appBrandSecondary` | Logo accent, highlights, borders |
| Emerald | `#54BB74` | `.emerald`, `.appBrandPrimary` | CTA buttons, active states |
| Alabaster | `#F3EBE2` | `.alabaster` | Warm white text on dark |
| Logo White | `#F6EFEF` | `.logoWhite` | Inverted logo variant |

### Emerald vs Eton (do not mix roles)

- **Emerald** → primary actions: Sign in, Save, sliders, FAB glow
- **Eton** → brand accent: logo green, icon highlights, secondary chips
- Never use purple for brand UI — removed in Phase 3 sync

---

## Quick Reference

### Import
```swift
import SwiftUI
// Color extensions are automatically available
```

### Most Common Colors

| Usage | Color Token | Hex |
|-------|-------------|-----|
| App Background (Dark) | `.appCanvasPrimary` | `#111214` |
| Hotel Background | `.appCanvasHotel` | `#292929` |
| Card/Surface | `.appSurfacePrimary` | `#24262B` |
| Primary Text | `.appTextPrimary` | `#F2EBE3` |
| Secondary Text | `.appTextSecondary` | `#C9C4BD` |
| Muted Text | `.appTextMuted` | `#A19D98` |
| CTA / Buttons | `.appBrandPrimary` | `#54BB74` |
| Logo / Accent Green | `.eton` / `.appBrandSecondary` | `#93CFA2` |
| Bright Accent | `.appBrandAccent` | `#00FF8C` |
| Success | `.appSuccess` | `#2ECC71` |
| Warning | `.appWarning` | `#FFEB85` |
| Danger | `.appDanger` | `#FF9292` |
| Borders | `.appBorderPrimary` | `#484848` |

---

## Color Architecture

### 1. Base Colors
```swift
Color.themeWhite    // #FFFFFF
Color.themeBlack    // #000000
```

### 2. Brand Colors
```swift
Color.appBrandPrimary    // #54BB74 - Emerald (CTAs)
Color.appBrandSecondary  // #93CFA2 - Eton Blue (accents)
Color.appBrandTertiary   // #76E094 - Light emerald
Color.appBrandAccent     // #00FF8C - Bright accent
Color.emerald            // Alias for brandPrimary
Color.eton               // #93CFA2 - Logo / highlight green
Color.alabaster          // #F3EBE2
Color.charlestonGreen    // #292929
Color.logoWhite          // #F6EFEF
```

### 3. Canvas Colors
```swift
Color.appCanvasPrimary    // #111214
Color.appCanvasSecondary  // #101217
Color.appCanvasTertiary   // #0B0E0C
Color.appCanvasElevated   // #171717
Color.appCanvasStrong     // #191B1E
Color.appCanvasHotel      // #292929
```

### 4. Surface Colors
```swift
Color.appSurfacePrimary       // #24262B
Color.appSurfaceSecondary     // #2A2C33
Color.appSurfaceTertiary      // #393C43
Color.appSurfaceCard          // #2C2F33
Color.appSurfaceFloating      // #22242A
Color.appSurfaceInset         // #1C1C1C
Color.appSurfacePanel         // #1F2126
Color.appSurfaceStroke        // #484848
```

### 5. Text Colors
```swift
Color.appTextPrimary    // #F2EBE3
Color.appTextSecondary  // #C9C4BD
Color.appTextTertiary   // #B6BAC2
Color.appTextMuted      // #A19D98
Color.appTextSubtle     // #9AA0A6
Color.appTextInverse    // #111111
Color.appTextQuiet      // #E9E9E9
```

### 6. Semantic Colors
```swift
Color.appSuccess        // #2ECC71
Color.appSuccessDark    // #17543B
Color.appWarning        // #FFEB85
Color.appDanger         // #FF9292
Color.appDangerStrong   // #FF0000
Color.appInfo           // #19C6D7
Color.appInfoBright     // #6FE8F0
Color.appInfoDark       // #00A5C9
```

### Semantic tokens (use in views)

```swift
Color.brandAction       // #54BB74 — buttons, toggles, sliders, FAB, user bubbles
Color.brandHighlight    // #93CFA2 — icons, tags, borders, halos, chips
Color.brandActionDark   // #047857 — gradient depth, idle orb
Color.eton              // alias → brandHighlight (legacy)
Color.emerald           // alias → brandAction (legacy)
Color.orbGlow1/4        // alias → brandAction (legacy)
Color.orbGlow3          // alias → brandHighlight (legacy)
```

### 8. AI / Chat
```swift
Color.appAIGradientStart    // #0B0E0C
Color.appAIGradientEnd      // #111214
Color.appChatUserBubble     // #54BB74
Color.appChatUserBubbleAlt  // #93CFA2
Color.appChatSend           // #54BB74
Color.appChatBar            // #22242A
```

---

## Typography (Phase 5–6)

Official brand fonts from `V02_LIMI_Initial_Presentation`:

| Role | Font | Token |
|------|------|-------|
| Headings | **Amenti** Bold / Medium | `LimiTypography.title`, `.title2`, `.largeTitle` |
| Body | **Poppins** Regular / Medium | `LimiTypography.body`, `.callout`, `.subheadline` |
| Buttons | Poppins SemiBold | `LimiTypography.button`, `.buttonSmall` |
| Small UI | Poppins Medium | `LimiTypography.caption`, `.caption2`, `.footnote` |

### Usage

```swift
Text("Welcome")
    .font(LimiTypography.largeTitle)   // Amenti Bold 28

Text("Subtitle")
    .font(LimiTypography.body)         // Poppins Regular 16

Text("Sign in")
    .font(LimiTypography.button)       // Poppins SemiBold 17
```

### Direct helpers

```swift
LimiFont.amenti(size: 24, weight: .bold)
LimiFont.poppins(size: 16, weight: .medium)
```

Fonts live in `Font/` and are registered in `Features/Info.plist`. If a custom font fails to load, helpers fall back to system fonts.

**Phase 6 rollout:** All SwiftUI screens use `LimiTypography.*` tokens. SF Symbol icons keep `.font(.system(size:…))` for correct glyph metrics.

---

## Usage Patterns

### Backgrounds
```swift
ZStack {
    Color.appCanvasPrimary.ignoresSafeArea()
}
```

### Buttons
```swift
Button(action: {}) {
    Text("Save")
        .foregroundColor(.appTextInverse)
}
.background(Color.appBrandPrimary)
```

### Cards
```swift
RoundedRectangle(cornerRadius: 12)
    .fill(Color.appSurfacePrimary)
    .stroke(Color.appBorderPrimary, lineWidth: 1)
```

---

## Unified Design System (Consistency Pass)

Every screen should follow this hierarchy:

| Layer | Component / Token |
|-------|-------------------|
| Screen background | `DeepSpaceBackground()` or `.limiScreenBackground()` |
| Cards / panels | `.limiPanel()` / `.limiHomeCard()` / `.glassCard()` |
| Home grid cards | `LimiCard.radius` (16) — weather compact + modules match |
| Module icons | `.brandHighlight` (Eton) |
| Tab bar active | `.brandHighlight` icon + label |
| FAB | `LimiGradients.cta` fill + `.appTextInverse` icon |
| Primary CTA | `LimiPrimaryButton` → `LimiGradients.cta` |
| Secondary action | `LimiSecondaryButton` |
| Destructive | `LimiDangerButton` |
| Text on dark UI | `.appTextPrimary` / `.appTextSecondary` / `.appTextMuted` |
| Text on emerald CTA | `.appTextInverse` |
| Accent icons | `.brandHighlight` |
| Active toggles / sliders | `.brandAction` |

### CTA gradient (never mix action + highlight as fill)

```swift
LimiGradients.cta          // LinearGradient emerald → dark emerald
LimiGradients.ctaColors    // [.brandAction, .brandActionDark]
```

### Do not use in views

- `Color.white`, `Color.gray`, `Color.green` — use semantic tokens
- Custom inline gradient buttons — use `LimiPrimaryButton`
- Light `themeWhite` cards on dark canvas — use `glassCard`

Run `./find_hardcoded_colors.sh` after UI changes.

---

- [x] `Color.black` → `.appCanvasPrimary` / `.appOverlayScrim`
- [x] `Color.white` → `.themeWhite` / `.appGlassFill*`
- [x] `Color.gray` → `.appTextMuted` / `.appBorderPrimary`
- [x] `Color(hex: "...")` in views → matching theme token
- [x] Purple/cyan brand accents → `.brandAction` / `.brandHighlight`

Run `./find_hardcoded_colors.sh` after UI changes. See `BRAND_QA.md` for screen checklist.

---

## Brand Implementation Status

| Phase | Status |
|-------|--------|
| 1 — Asset extract | ✅ Complete |
| 2 — Logo import | ✅ Complete |
| 3 — Color sync | ✅ Complete |
| 4 — Emerald/Eton project-wide | ✅ Complete |
| 5 — Typography wiring | ✅ Complete |
| 6 — Typography rollout (all screens) | ✅ Complete |
| 7 — Final brand assets (designer) | Pending |
| 8 — Brand QA + hardcoded color cleanup | ✅ Complete |
| 9 — Full UI consistency (buttons, text, backgrounds) | ✅ Complete |

---

## Best Practices

1. **CTA = Emerald**, **accent = Eton**
2. **Charleston `#292929`** for hotel module backgrounds
3. **Warm text** — use Alabaster family, not cool purple-gray
4. **No hardcoded hex** in Views
5. Test on device in sunlight for contrast
