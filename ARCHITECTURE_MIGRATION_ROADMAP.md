# Architecture Migration Roadmap — LIMI iOS

> **Diagnosis date:** June 2026  
> **Target:** Feature-based MVVM + `App` / `Core` / `Shared` / `Features` (see `Limi/PHASE_2_MVVM_BLUEPRINT.md`)  
> **Rule:** One architectural concern per phase. Build + smoke test after each phase.

---

## Executive diagnosis

### Does the project follow the target architecture?

**No — partially.** The app is **mid-migration**, not greenfield.

| Layer | Target | Today | Score |
|-------|--------|-------|-------|
| **App** (`LimiApp`, `AppRouter`, DI) | Central routing + composition | `SplashScreen` if/else + per-feature modal flags | 🔴 20% |
| **Core** (services, no UI) | All cross-feature logic | `Core/` exists (~34 files) but Bluetooth + many managers still in `LimiExhibition/` | 🟡 55% |
| **Shared** (reusable UI) | Generic components only | Mixed into `HomeView/Component`, `Hotel Module`, no `Shared/` folder | 🔴 15% |
| **Features** (MVVM per domain) | `Views` / `ViewModels` / `Services` | Folder-by-screen; ~29% of major screens have real ViewModels | 🟡 35% |
| **Networking** | Single HTTP client | `LimiHTTPClient` for Limi API; WLED/weather/raw URLSession elsewhere | 🟡 70% |
| **DI / testability** | Protocols + injection | Strong in `HomeViewModel` only; ~29 `.shared` singletons elsewhere | 🔴 25% |
| **Tests** | Per service + VM | `LimiHTTPClientTests` only (3 tests) | 🔴 10% |

### Closest label today

**Feature-folder MVVM-lite + singleton service locator**

- Not MVC (SwiftUI-first)
- Not Clean Architecture (no domain/use-case layer)
- Not the blueprint’s `App/Core/Shared/Features` layout

### What is already good (keep building on this)

- `Core/Services/API/` — `LimiHTTPClient`, `LimiAPIError`, `AppURLs`, async layer
- `Core/Services/Transport/` — `LimiTransport`, three-door device control
- `Core/Services/Auth/` — Keychain JWT, `AuthManager`
- `HomeViewModel` + `HomeRuntimeAdapters` — **canonical MVVM + protocol DI**
- Login ViewModels (`LoginViewModel`, `OTPVerificationViewModel`)
- `2D RoomPlan` — proper `Views/` / `ViewModels/` / `Models/`
- Design system in `Core/DesignSystem/`

### Biggest gaps

1. **~29 global singletons** — views call `.shared` directly
2. **God views** — `DataRGBView`, `PWM2LEDView`, `GetStart`, `WLEDController`, `DemoScanDevicesView` (UI + API + device logic)
3. **No `AppRouter`** — navigation scattered across `@State`, `@AppStorage`, ViewModel booleans
4. **Split Core boundary** — Bluetooth in `LimiExhibition/Services/`, transport in `Core/`
5. **Inconsistent MVVM** — Hotel WLED, Hub, AR, demo modules have no ViewModels
6. **Minimal tests** — protocols exist but are mostly untested outside Home

---

## Target end state (reference)

```text
Limi/
  App/                    # @main, AppDelegate, AppRouter, AppEnvironment
  Core/                   # API, Auth, Bluetooth, Transport, WebSocket, DesignSystem
  Shared/                 # Reusable SwiftUI components (no feature logic)
  Features/
    Authentication/
    Onboarding/
    Home/
    AddDevice/
    AIChat/
    Configurator/
    ARSession/
    Hotel/
    RoomPlan2D/
    RoomPlan3D/
    Profile/
  Tests/
```

**Dependency rule:** `Features → Core + Shared` only. `Core` must not import `Features`.

---

## Migration phases

Phases A–D are **foundation** (low risk). Phases E–M are **feature MVVM** (medium risk). Phase N is **folder move** (optional, do last).

---

### Phase A — Architecture guardrails (1 day)

**Problem:** No enforced boundaries; new code copies old patterns.

**Steps:**
1. Add `ARCHITECTURE.md` (this file) + link from `PHASE_2_MVVM_BLUEPRINT.md`.
2. Add Cursor rule or `AGENTS.md` snippet: “New screens need a ViewModel; no `URLSession` in Views; use `LimiHTTPClient`.”
3. Document canonical examples: `HomeViewModel.swift`, `LimiHTTPClient.swift`.

**Acceptance:**
- [ ] Team agrees on target structure
- [ ] New PRs follow Home MVVM pattern for new screens

---

### Phase B — Finish Core extraction (2–3 days)

**Status:** Complete (June 2026).

**Moved to `Core/` (no behavior change):**
- `LimiExhibition/Services/Bluetooth/*` → `Core/Services/Bluetooth/`
- `FloatingAssistant/ContextManager.swift` → `Core/Managers/ContextManager.swift`
- `GlobalVariables.swift` → `Core/Utilities/GlobalVariables.swift`

**Acceptance:**
- [x] Bluetooth compiles from `Core/Services/Bluetooth/`
- [x] `LimiExhibition/Services/Bluetooth/` removed
- [x] Debug build succeeds

---

### Phase C — App shell + routing (2 days)

**Status:** Complete (June 2026).

**Added:**
- `App/AppRouter.swift` — `AppRootRoute` + splash routing logic
- `App/HomeRoute.swift` — Home modal routes
- `HomeViewModel.activeRoute` replaces 8 boolean presentation flags
- `SplashScreen` delegates to `AppRouter`

**Acceptance:**
- [x] One place lists top-level post-splash routes (`AppRouter`)
- [x] Home uses `activeRoute` + `routeBinding(_:)` for modals
- [x] Splash → Home path unchanged
- [x] Debug build succeeds

---

### Phase D — Shared components extraction (1–2 days)

**Status:** Complete (June 2026).

**Created `Shared/Components/`:**
- `VisualEffectBlur.swift` — from `AI ChatBot/` (removed duplicate `HotelVisualEffectBlur`)
- `RainbowSlider.swift` — from `HubHomeView/` (used in Hub + Hotel WLED)
- `LimiModalChrome.swift` — `LimiBackButton`, `LimiCloseToolbarButton`, `limiModalNavigationBar`, `limiModalSheetStyle`, `LimiModalNavigationShell` (extracted from `LimiDesignSystem.swift`)

**Acceptance:**
- [x] `Shared/` has no feature-specific imports
- [x] Debug build succeeds

---

### Phase E — Authentication feature MVVM (2 days)

**Problem:** `LoginView.swift` is ~1400 lines; `GetStart` mixes API + navigation.

**Steps:**
1. Create `Features/Authentication/` (or keep paths, add layers):
   - `ViewModels/GetStartViewModel.swift` — installer/PU login API calls
   - Thin `LoginView` — UI only, delegates to existing ViewModels
2. Move `GoogleAuthManager` → `Features/Authentication/Services/` or `Core/Services/Auth/`.
3. Single entry: `AuthCoordinator` or router case for login flows.

**Acceptance:**
- [x] `GetStart` has no raw `LimiHTTPClient` in View body
- [x] Login / OTP / Apple / Google paths unchanged for users
- [ ] `LoginView` thinned (deferred — existing ViewModels already own OTP; ~1400-line view unchanged this pass)

---

### Phase F — Home feature as reference (1 day, polish)

**Problem:** Home is the best module but still uses some singletons in views.

**Steps:**
1. Inject `BluetoothManager` via `HomeBluetoothAdapter` everywhere in Home (no `.shared` in Views).
2. Move `HomeView/Component/` → triage to `Features/Home/Components/` vs `Shared/`.
3. Add `HomeViewModelTests` with mock protocols.

**Acceptance:**
- [x] Zero `BluetoothManager.shared` in `HomeView/` views
- [x] At least 2 unit tests for `HomeViewModel` (5 tests in `HomeViewModelTests`)

---

### Phase G — Add Device feature (3 days)

**Problem:** Logic split across `Add_Device/`, `Device Demo Module/`, `Demo/`.

**Steps:**
1. Create `AddDeviceViewModel` for `DemoScanDevicesView` (Bonjour + ping state).
2. Extract `BonjourServiceBrowser` from `DemoScanDevicesView.swift` → `Core/Services/Networking/` or `AddDevice/Services/`.
3. One navigation entry: `AddDeviceCoordinator` from Home FAB / Personalize.
4. Consolidate duplicate demo flows (Batch 3 cleanup).

**Acceptance:**
- [x] `DemoScanDevicesView` under 400 lines (138 lines)
- [x] Bonjour browser testable via protocol (`BonjourWiFiBrowsing` + mock in tests)

---

### Phase H — Hotel / WLED feature MVVM (3–4 days)

**Problem:** `WLEDController`, `WLEDView`, `DataRGBView` mix SSDP, HTTP, and UI.

**Steps:**
1. `WLEDDeviceService` protocol + `WLEDDeviceServiceImpl` (SSDP, local HTTP).
2. `WLEDViewModel` — device list, selected device, effect state.
3. Route WLED HTTP through a thin `WLEDHTTPClient` (or extend `AppURLs.WLED` + shared session).
4. Shrink `DataRGBView` / `PWM2LEDView` to bind to ViewModel.

**Acceptance:**
- [x] No `URLSession.shared` in WLED Views
- [x] `HotelHomeViewModel` pattern extended to room devices (`HotelRoomDevicesViewModel` + `HotelRoomBluetoothAdapter`)

**Delivered (2026-06-18):**
- `Hotel/WLED/Services/WLEDHTTPClient.swift` — LAN HTTP (replaces `URLSession.shared` in managers)
- `Hotel/WLED/Services/HotelRoomBluetoothAdapter.swift` — BLE adapter for room devices
- `Hotel/WLED/ViewModels/WLEDDiscoveryViewModel.swift`, `WLEDDeviceControlViewModel.swift`, `WLEDControlViewModel.swift`
- `WLEDView`, `WLEDController` wired to ViewModels; `HotelRoomDevices` uses `HotelRoomDevicesViewModel`
- `HubChannelControlViewModel` created (PWM/RGB wiring deferred — duplicate structs in legacy files)

---

### Phase I — AI Chat feature (2 days)

**Problem:** `WebRTCVoiceClient` is 1500+ lines; owned by View as `@StateObject`.

**Steps:**
1. `Features/AIChat/Services/VoiceSessionService` wrapping WebRTC client.
2. `VoiceViewModel` — connection state, transcript, tool calls.
3. Inject `backendBaseURL` from `LimiAPIConfiguration` via environment.

**Acceptance:**
- [x] `VoiceView` under 300 lines (113 lines)
- [x] Voice connect/disconnect unchanged (`VoiceViewModel` + `VoiceSessionService`)

**Delivered (2026-06-18):**
- `AIChat/Services/VoiceSessionService.swift` — wraps `WebRTCVoiceClient`
- `AIChat/ViewModels/VoiceViewModel.swift` — session state, transcripts, tool calls, chat mode
- `AIChat/Components/` — presence, chat mode, bubble UI extracted from `VoiceView`
- `AIChat/VoiceBackendEnvironment.swift` — `\.limiBackendBaseURL` environment key
- `Tests/VoiceViewModelTests.swift` — 5 tests

---

### Phase J — Configurator + AR features (2 days)

**Problem:** Web bridge + AR loading scattered; some views load models directly.

**Steps:**
1. `ConfiguratorViewModel` — download state, snap ID from web bridge.
2. All AR loaders use `ConfiguratorModelStore.loadEntity` (already started).
3. `ARSessionViewModel` for carousel / preset list (`3DModelList`).

**Acceptance:**
- [x] Single AR model load path (`ConfiguratorModelStore.loadEntity` / `loadPlacementContainer` / `previewURL`)
- [x] Configurator Save → AR still works (`ConfiguratorDownloadService` + `ConfiguratorViewModel`)

**Delivered (2026-06-18):**
- `Configurator/Services/ConfiguratorDownloadService.swift` — single USDZ download path
- `Configurator/ViewModels/ConfiguratorViewModel.swift` — snap ID + portal save flow
- `Configurator/Models/LightConfigModels.swift` — shared light-config types
- `AR/ViewModels/ARSessionViewModel.swift` — carousel/preset list for `ARModelList`
- Extended `ConfiguratorModelStore` with `previewURL` + `loadPlacementContainer`
- Migrated `ARViewContainer`, `ProductARView`, `QuickLookView`, `TastingAR`, web configurators
- `Tests/ARSessionViewModelTests.swift` — 3 tests

---

### Phase K — RoomPlan 2D + 3D (2 days)

**Problem:** 2D is clean; 3D `RoomPlan/` mixes upload, capture, editor.

**Steps:**
1. Keep `2D RoomPlan` as-is (reference).
2. `RoomCaptureViewModel` from `RoomCaptureController` logic.
3. Upload via `LimiHTTPClient` only in `RoomPlanUploadService`.

**Acceptance:**
- [x] `RoomCaptureController` no multipart building in View layer
- [x] Upload centralized in `RoomPlanUploadService` via `LimiHTTPClient`

**Delivered (2026-06-18):**
- `RoomPlan/Services/RoomPlanUploadService.swift` — multipart upload + list/delete/download/sync
- `RoomPlan/ViewModels/RoomCaptureViewModel.swift` — scan state, save, analyze, upload
- `RoomPlan/ViewModels/RoomPlanListViewModel.swift` — scan list sync/delete (`RoomPlanContentView` slimmed)
- `RoomCaptureController` — thin RoomPlan session bridge only (**325 → 65 lines**)
- `ScanSyncManager` — `URLSession.shared` → `LimiHTTPClient`
- `Tests/RoomPlanUploadServiceTests.swift`, `RoomCaptureViewModelTests.swift`

---

### Phase L — Dependency container (1–2 days)

**Problem:** Default init uses singletons; tests cannot swap dependencies app-wide.

**Steps:**
1. `AppEnvironment` struct holding protocol-typed services.
2. Inject via SwiftUI `.environment(\.appEnvironment, ...)`.
3. Production defaults = current singletons; tests = mocks.

```swift
struct AppEnvironment {
    var auth: AuthProviding
    var http: HTTPPerforming
    var bluetooth: BluetoothControlling
    var transport: LimiTransporting
}
```

**Acceptance:**
- [x] Home + Login use `AppEnvironment` (pilot)
- [x] Test target can create `AppEnvironment.mock`

**Delivered (2026-06-18):**
- `App/DependencyProtocols.swift` — `AuthProviding`, `HTTPPerforming`, `LimiTransporting`, `HomeBluetoothMaking`
- `App/AppEnvironment.swift` — `.live` / `.mock` + `\.appEnvironment` environment key
- `HomeView` + `GetStart` wired to environment-injected ViewModels
- `LimiExhibitionApp` injects `.environment(\.appEnvironment, .live)`
- `Tests/AppEnvironmentTests.swift` — 3 tests

---

### Phase M — Test pyramid ✅

**Problem:** Only HTTP client tested.

**Priority tests:**
1. `AuthManager` — Keychain save/load/migrate
2. `HomeViewModel` — device list, navigation intents
3. `LimiAPIError` — decode edge cases
4. `ConfiguratorModelStore` — path resolution
5. `LightControllingSocket` — auth refresh (mock socket)

**Acceptance:**
- [x] 15+ unit tests
- [x] CI runs `LimiTests` on PR

**Delivered (2026-06-18):**
- `Tests/AuthManagerTests.swift` — 6 tests (save/load, expiry, UserDefaults migration, Bearer header, clear, role)
- `Tests/LimiAPIErrorTests.swift` — 6 tests (HTTP status, URLError, missingAuth, backend wrap)
- `Tests/ConfiguratorModelStoreTests.swift` — 5 tests (URL normalize, save, resolve, cache migration)
- `Tests/LightControllingSocketAuthPolicyTests.swift` — 4 tests (auth rebuild/disconnect policy)
- `Tests/HomeViewModelTests.swift` — added `testFetchLinkedDevicesPopulatesListOnSuccess`
- `Core/Services/WebSocket/LightControllingSocket.swift` — extracted `LightControllingSocketAuthPolicy` for testability
- `.github/workflows/limi-tests.yml` — `xcodebuild test -only-testing:LimiTests` on PR
- **44 unit tests** across 12 suites — all passing locally

---

### Phase N — Physical folder restructure ✅

**Problem:** `LimiExhibition/` flat module folders vs blueprint `Features/`.

**Only do after Phases A–M are stable.**

**Steps:**
1. Rename `LimiExhibition/` → `Features/` incrementally (one feature per PR).
2. Move `LimiExhibitionApp.swift` → `App/LimiApp.swift`.
3. Update Xcode synchronized root / target membership.

**Acceptance:**
- [x] Folder names match blueprint
- [ ] Full smoke test passes (deferred — user runs once at end)

**Delivered (2026-06-19):**
- `LimiExhibition/` renamed to `Features/`; Xcode sync root updated
- Root MVVM modules nested under `Features/` (`Authentication`, `Home`, `AddDevice`, `Hotel`, `AIChat`, `Configurator`, `ARSession`, `RoomPlan3D`)
- Legacy view folders moved into `Features/*/Views/` (e.g. `HomeView` → `Features/Home/Views/`)
- `App/LimiApp.swift` + `App/AppDelegate.swift` — app entry outside sync root
- `INFOPLIST_FILE` + `DEVELOPMENT_ASSET_PATHS` point to `Features/`
- Debug build + 44 unit tests passing

---

## Recommended execution order

```text
A (guardrails) → B (Core) → C (Router) → D (Shared)
    → E (Auth) → F (Home polish) → G (AddDevice) → H (Hotel)
    → I (AI) → J (Configurator/AR) → K (RoomPlan)
    → L (DI container) → M (Tests, parallel)
    → N (folder rename, last)
```

**Parallel track:** Phase M tests can start after Phase F.

---

## What NOT to do

- **Do not** rewrite everything to Clean Architecture / TCA / VIPER — cost >> benefit for this codebase.
- **Do not** remove all singletons at once — wrap with protocols first, inject later.
- **Do not** rename folders (Phase N) before ViewModels exist — moves are painful without tests.
- **Do not** merge Home and Hotel — keep separate features per blueprint.

---

## Quick reference — canonical files today

| Pattern | File |
|---------|------|
| Best ViewModel | `Features/Home/Views/HomeView/ViewModel/HomeViewModel.swift` |
| Protocol adapters | `Features/Home/HomeRuntimeAdapters.swift` |
| HTTP layer | `Core/Services/API/LimiHTTPClient.swift` |
| Transport | `Core/Services/Transport/LimiTransport.swift` |
| Auth | `Core/Services/Auth/AuthManager.swift` |
| Blueprint | `Limi/PHASE_2_MVVM_BLUEPRINT.md` |

---

## Cursor prompt template

```
Phase [X] from ARCHITECTURE_MIGRATION_ROADMAP.md only.
[One sentence goal]. Minimal diff. No behavior change unless phase says so.
Build Debug after edits.
```

---

*Aligns with `Limi/PHASE_2_MVVM_BLUEPRINT.md` and post-reliability `PHASED_FIX_ROADMAP.md` (Phases 1–14).*
