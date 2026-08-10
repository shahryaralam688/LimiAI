# LIMI Brand QA — Phase 8 Audit

> Completed: June 2026. Run `./find_hardcoded_colors.sh` after UI changes.

## Summary

| Area | Status | Notes |
|------|--------|-------|
| Color tokens | ✅ | 33+ view files migrated; glass/overlay tokens added |
| Emerald vs Eton | ✅ | CTAs use `brandAction`; accents use `brandHighlight` |
| Typography | ✅ | Phase 6 — all screens on `LimiTypography.*` |
| Logos | ✅ | Phase 2 — inverted variants in asset catalog |
| Purple/cyan brand drift | ✅ | Weather, Hub popup, orbs, AR overlays fixed |
| Hardcoded `Color.*` in views | ✅ | Zero active violations (WLED hex picks excluded) |
| **Full UI consistency (Phase 9)** | ✅ | 115+ files — `LimiGradients`, `limiPanel`, `LimiScreen`, semantic text colors |

---

## Unified Components (use everywhere)

| Layer | API |
|-------|-----|
| Screen shell | `LimiScreen { }` or `.limiScreenBackground()` |
| Cards / panels | `.limiPanel()` / `.glassCard()` |
| Primary CTA | `LimiPrimaryButton` |
| Secondary | `LimiSecondaryButton` |
| Compact pill | `LimiPillButton` |
| CTA gradient | `LimiGradients.cta` |
| Text | `.appTextPrimary` / `.appTextSecondary` / `.appTextMuted` |
| Voice Pendant | `VPSectionCard`, `VPNavRow`, `VPMetricChip` |

---

## New Semantic Tokens (Phase 8)

| Token | Use |
|-------|-----|
| `appGlassFill` / `appGlassFillMedium` / `appGlassFillStrong` | Card overlays, chips |
| `appGlassStroke` / `appGlassStrokeLight` / `appGlassStrokeStrong` | Borders, dividers |
| `appOverlayScrim` / `appOverlayScrimLight` | Modal dimming |
| `appShadowMedium` / `appShadowStrong` | FAB, nav shadows |
| `appToggleOff` | Toggle track (off) |
| `appWeatherClearTop/Mid/Bottom` | Weather card gradient (brand teal/emerald) |
| `appWeatherNightTop/Mid/Bottom` | Night weather gradient |

---

## Screen Checklist

Verify on device (dark mode, sunlight):

- [ ] **Splash / GetStart** — logo inverted, Amenti headings, charcoal bg
- [ ] **SignIn / Login** — neural orb emerald glow (no purple), Poppins body
- [ ] **Personalize** — brand fonts, emerald CTAs, glass cards
- [ ] **Home** — FAB emerald + eton halo, weather card brand gradient
- [ ] **Hotel Home** — Charleston `#292929` bg, green status → `appSuccess`
- [ ] **AI Chat / Voice** — user bubbles emerald, glass assistant bubbles
- [ ] **Add Device** — BLE scan, emerald connect buttons
- [ ] **Voice Pendant** — full typography + brand colors
- [ ] **Onboarding orb** — emerald halo (no cyan rim)

---

## Intentional Exceptions

These are **not** violations:

| Location | Reason |
|----------|--------|
| `Color.swift` | Single source of truth for hex values |
| `RainbowSlider.swift` | Physical light color picker (full spectrum) |
| WLED `Color(hex:)` | User-selected lamp color from device/storage |
| `DataRGBView` / `MiniControllerView` preset swatches | LED hardware color presets |
| `ARViewContainer` UIColor RGB | RealityKit material tinting |
| `ModelEditorView` random UIColor | Dev/debug mesh coloring |

---

## Regression Commands

```bash
# Hardcoded color scan
./find_hardcoded_colors.sh

# Build
xcodebuild -workspace Limi.xcworkspace -scheme Limi \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Remaining (Phase 7+)

- [ ] Designer assets: iconography, patterns (`LIMI Final Files/`)
- [ ] `Info.plist` API keys → server-side proxy (security, not brand)
- [ ] Legacy AR/RoomPlan modules — low-traffic; colors now tokenized where touched
