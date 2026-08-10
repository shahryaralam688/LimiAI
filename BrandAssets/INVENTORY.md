# LIMI Brand Assets — Inventory

> Phase 1 complete. Source: `/Users/shahrukhahmed/Downloads/Limi/Graphics/`  
> Extracted: June 26, 2026. App code unchanged — import in Phase 2.

## Folder Structure

```
BrandAssets/
├── LIMI_Initial_Presentation_V02.pdf   # Brand concepts (3 pages)
├── INVENTORY.md                        # This file
├── Previews/                           # Presentation preview PNGs
├── Logo/
│   ├── PNG/                            # 12 raster logos (@1x from designer)
│   ├── SVG/                            # 23 vector logos
│   └── EPS/                            # 1 print vector
└── Source/
    └── LIMI_Logo_Masterfile.ai         # Adobe Illustrator master (291 KB)
```

## Official Brand Colors (from PDF)

| Name | Hex | Use |
|------|-----|-----|
| Charleston Green | `#292929` | Dark backgrounds, logo body |
| Eton Blue | `#93cfa2` | Logo accent (L frame, i dot) |
| Emerald | `#54bb74` | CTA / buttons (app) |
| Alabaster | `#f3ebe2` | Light text / warm white |

SVG production colors: `#93cfa2`, `#292929`, `#f6efef` (inverted/white variant).

---

## PNG Assets (12)

| File | Original | Recommended Use |
|------|----------|-----------------|
| `PrimaryLogo_Colored.png` | `__Primary_Logo_Colored` | Login, splash (dark bg) |
| `PrimaryLogo_White.png` | `__Primary_Logo_White` | Pure dark backgrounds |
| `PrimaryLogo_Black.png` | `__Primary_Logo_Black` | Light/print backgrounds |
| `PrimaryLogo_Inverted.png` | `__Primary_Logo_Inverted` | Marketing, onboarding |
| `LogoIcon_Colored.png` | `__Logo_Icon_Colored` | Tab bar, small UI, app icon base |
| `LogoIcon_White.png` | `__Logo_Icon_White` | Dark toolbar icon |
| `LogoIcon_Black.png` | `__Logo_Icon_Black` | Light toolbar icon |
| `LogoIcon_Inverted.png` | `__Logo_Icon_Inverted` | Feature highlights |
| `IconWordmark_Colored.png` | `__Icon_Wordmark_Colored` | Compact header (icon + LIMI) |
| `IconWordmark_White.png` | `__Icon_Wordmark_White` | Dark header compact |
| `IconWordmark_Black.png` | `__Icon_Wordmark_Black` | Light header compact |
| `IconWordmark_Inverted.png` | `__Icon_Wordmark_Inverted` | Onboarding compact |

## SVG Assets (23)

Same variants as PNG, plus:

| File | Use |
|------|-----|
| `VerticalLogo_A_Colored.svg` | Stacked logo + tagline (variant A) |
| `VerticalLogo_A_White.svg` | Vertical A on dark bg |
| `VerticalLogo_A_Black.svg` | Vertical A monochrome |
| `VerticalLogo_A_Inverted.svg` | Vertical A inverted |
| `VerticalLogo_B_*.svg` | Vertical B (LIMITLESS on own line) |
| `Wordmark_Black.svg` | LIMI text only |
| `Wordmark_White.svg` | LIMI text only (light) |
| `Wordmark_Green.svg` | LIMI text only (Eton green) |

## Source Files

| File | Format | Notes |
|------|--------|-------|
| `Source/LIMI_Logo_Masterfile.ai` | Illustrator | Editable master — do not modify for app import |
| `Logo/EPS/LIMI_Logo_Masterfile.eps` | EPS | Print / vendor handoff |

## Previews (from presentation)

| File | Description |
|------|-------------|
| `Previews/VerticalLogo_A.png` | Concept preview — Vertical Logo A |
| `Previews/VerticalLogo_B.png` | Concept preview — Vertical Logo B |
| `Previews/IconWordmark_Preview.png` | Concept preview — Icon + Wordmark |

---

## Extraction Log

| Archive | Status | Notes |
|---------|--------|-------|
| `PNG-20250212T120705Z-001` | ✅ Copied + renamed | Was pre-extracted in source folder |
| `SVG-20250212T120708Z-001.zip` | ✅ Extracted | 23 files → `Logo/SVG/` |
| `EPS-20250212T120703Z-001.zip` | ✅ Extracted | 1 file → `Logo/EPS/` |
| `Masterfile-20250212T120704Z-001.zip` | ✅ Extracted | 1 file → `Source/` |
| JPG zip | ⚠️ Not provided | Source folder empty — no JPG zip in Graphics |

## Still Missing (Phase 7)

- `LIMI Final Files/` — iconography, patterns, imagery (empty in source)
- JPG exports — not in designer zip bundle
- Inter font files (Concept #02) — not in repo

## Phase 2 — App Import (Complete)

| Asset catalog name | Source PNG | Screens |
|--------------------|------------|---------|
| `LoginViewLogo` | `PrimaryLogo_Inverted.png` | GetStart, LoginView, SignIn |
| `logoSplash` | `LogoIcon_Inverted.png` | SplashScreen, PULoginView, ProfileEditView |
| `logo` | `IconWordmark_Inverted.png` | HomeView HeaderView, LocationStorageView |
| `Logo Files/PNG/*` | All 12 variants | Available for future use |

**Phase 3:** Sync `Color.swift` with official brand palette — ✅ Complete (June 2026).

**Phase 4:** Emerald vs Eton — ✅ Complete project-wide (June 2026).

**Phase 5:** Wire `LimiTypography` to Amenti + Poppins — ✅ Complete (June 2026).

**Phase 6:** Typography rollout — ✅ Complete (June 2026). 120+ Swift files migrated to `LimiTypography.*`; Lexend/Inter removed; SF Symbol icons retain system font sizing.

**Phase 8:** Brand QA + hardcoded color cleanup — ✅ Complete (June 2026). Glass/overlay tokens added; 40+ files migrated; weather + orb purple drift fixed. See `BRAND_QA.md`.

## Next Step

**Phase 7:** Obtain `LIMI Final Files` (iconography, patterns, brand guidelines PDF) from designer.
