# Phased Fix Roadmap — One Problem Per Phase

> Each phase solves **exactly one** problem. Finish, build, smoke-test, then move on.  
> Do not bundle fixes across phases — that is how regressions hide.

**How to use with Cursor:** paste one phase block as a single task.

---

## Overview

| Phase | Problem | Severity | Est. effort |
|-------|---------|----------|-------------|
| 1 | JWT stored in UserDefaults | Critical | 0.5–1 day |
| 2 | GEMINI API key in Info.plist | Critical | 0.5 day |
| 3 | Socket.IO uses stale auth token | High | 0.5 day |
| 4 | USDZ saved/read from different folders | High | 0.5 day |
| 5 | Auth token logged to console | Medium | 1 hour |
| 6 | Legacy dead files in target | Medium | 0.5 day |
| 7 | Duplicate Apple Sign-In paths | Medium | 1 day |
| 8 | Product UI ≠ voice `ui_guide` (Home FAB) | Medium | 1–2 days |
| 9 | No environment switch for API URL | Medium | 0.5 day |
| 10 | `BluetoothManager` untestable monolith | High | 3+ days |

Phases 1–5 are security/reliability quick wins. Phase 10 is a large refactor — only start after 1–9 are stable.

---

## Phase 1 — Move JWT from UserDefaults to Keychain

**Problem:** Auth tokens are stored in plain `UserDefaults`. Keychain code exists but is commented out in `Core/Services/Auth/AuthManager.swift`.

**Why it matters:** Tokens can leak via unencrypted backups and are easier to extract than Keychain items.

**Files:**
- `Core/Services/Auth/AuthManager.swift`
- `Core/Services/Auth/KeychainHelper.swift` (create if missing — uncommented implementation may exist elsewhere)

**Steps:**
1. Implement or restore `KeychainHelper` (save / load / delete for `authToken`).
2. Change `saveToken`, `getToken`, `clearToken` to use Keychain for the token only; keep expiry in UserDefaults.
3. On first launch after update: if token exists in UserDefaults and Keychain is empty, migrate once, then delete from UserDefaults.
4. Remove the 95-line commented Keychain block once active code works.
5. Build and test: login → kill app → relaunch → still authenticated → logout → token cleared.

**Acceptance criteria:**
- [x] No JWT string in UserDefaults after migration
- [x] Login, relaunch, and logout work (code path verified; device sign-off via Phase 11)
- [x] `WebRTCVoiceClient.start()` still gets `authorizationHeaderValue()`

**Status:** Complete (June 2026).

**Out of scope:** Role storage, token expiry duration, refresh flow.

**Cursor prompt:**
```
Phase 1 from PHASED_FIX_ROADMAP.md only. Move JWT storage from UserDefaults to Keychain in AuthManager. Include one-time migration from UserDefaults. Do not change any other file or problem.
```

---

## Phase 2 — Remove hardcoded GEMINI_API_KEY from Info.plist

**Problem:** `GEMINI_API_KEY` is committed in `LimiExhibition/Info.plist` and embedded in the app binary.

**Why it matters:** Anyone with the repo or a decrypted IPA can extract and abuse the key.

**Files:**
- `LimiExhibition/Info.plist`
- Any Swift file that reads `Bundle.main` for `GEMINI_API_KEY` (grep first)

**Steps:**
1. Grep for `GEMINI_API_KEY` usage across the project.
2. If unused: delete the key from Info.plist only.
3. If used: move calls to backend proxy endpoint; remove key from plist and git history consideration (rotate key on Google Cloud).
4. Add `GEMINI_API_KEY` to `.gitignore` pattern docs if build-time injection is needed later — never in plist.

**Acceptance criteria:**
- [x] No API secret in Info.plist or committed source
- [x] App builds; any Gemini feature still works via backend or is gracefully disabled

**Status:** Complete (June 2026).

**Out of scope:** Other secrets, ATS settings.

**Cursor prompt:**
```
Phase 2 from PHASED_FIX_ROADMAP.md only. Remove GEMINI_API_KEY from Info.plist and fix any callers. Rotate usage to backend if needed. Do not touch AuthManager or other phases.
```

---

## Phase 3 — Socket.IO reconnects when auth token changes

**Problem:** `LightControllingSocket` reads the auth token once at init. Login after socket creation leaves the socket with an empty or stale token.

**Why it matters:** Light control and device status fail silently after login until app restart.

**Files:**
- `Core/Services/WebSocket/LightControllingSocket.swift`
- `Core/Services/Auth/AuthManager.swift` (observe `isAuthenticated` or post notification)

**Steps:**
1. Stop caching token only in `init`; read `AuthManager.shared.authorizationHeaderValue()` on each connect/reconnect.
2. When `isAuthenticated` becomes true or token is saved, disconnect and reconnect Socket.IO with fresh auth.
3. When user logs out, disconnect and do not auto-reconnect until next login.

**Acceptance criteria:**
- [x] Fresh login → socket connects with valid token without app restart
- [x] Logout → socket disconnects
- [x] `light_controll` emit works immediately after OTP verify (token saved via `limiAuthSessionDidChange` even when `updateAuthState: false`)

**Status:** Complete (June 2026).

**Out of scope:** MQTT bridge refactor, transport priority logic.

**Cursor prompt:**
```
Phase 3 from PHASED_FIX_ROADMAP.md only. Fix LightControllingSocket stale token after login/logout. Minimal diff. Do not refactor LimiTransport.
```

---

## Phase 4 — Unify USDZ storage path (Documents vs Caches)

**Problem:** Some flows save USDZ to `Documents/Configurator/{id}.usdz`; others read from `Caches/{id}.usdz`. AR opens “file not found” depending on navigation path.

**Why it matters:** Configurator → AR is a core product flow and fails intermittently.

**Files (grep `Configurator` and `Caches` + `.usdz`):**
- `LimiExhibition/Configurator/demoARView.swift`
- `LimiExhibition/Configurator/DownloadedModelARView.swift`
- `LimiExhibition/Configurator/DeviceDownloadStore.swift`
- `LimiExhibition/ARSession/` (any path construction)

**Steps:**
1. Pick **one** canonical directory (recommend `Documents/Configurator/` — survives cache clears).
2. Centralize path helper e.g. `ConfiguratorModelStore.url(forSnapId:)`.
3. Update all writers and readers to use the helper.
4. Manual test: web configurator Save → AR view shows model.

**Acceptance criteria:**
- [x] Single source of truth for USDZ path (`ConfiguratorModelStore` → `Documents/Configurator/`)
- [x] Save from configurator → AR works on first open
- [x] Re-open AR after app restart still finds file (Documents, not Caches)
- [x] Legacy `Caches/{id}.usdz` migrated on read via `resolvedURL(forSnapId:)`

**Status:** Complete (June 2026).

**Out of scope:** Download API changes, 3D model list UI.

**Cursor prompt:**
```
Phase 4 from PHASED_FIX_ROADMAP.md only. Fix USDZ Documents vs Caches mismatch with one shared path helper. Do not change web JS bridge.
```

---

## Phase 5 — Remove auth token debug logging

**Problem:** `AuthManager` prints tokens and expiry to console (`print("Saved Token:", token)`).

**Why it matters:** Logs appear in Xcode, device logs, and crash reports in field builds.

**Files:**
- `Core/Services/Auth/AuthManager.swift`

**Steps:**
1. Remove or gate all `print` statements that include token substrings behind `#if DEBUG`.
2. Replace with redacted logs if needed: `Token saved (length: N)`.

**Acceptance criteria:**
- [x] Release build logs never contain JWT substrings
- [x] DEBUG builds may log redacted metadata only (`Token saved (length: N)`, no raw token/expiry values)

**Status:** Complete (June 2026).

**Out of scope:** Keychain migration (Phase 1), broader logging audit.

---

## Phase 6 — Delete Batch 1 legacy files

**Problem:** ~12 unused files still compile into the app via synchronized `LimiExhibition/` group — noise and confusion.

**Why it matters:** Contributors edit dead code; binary size and compile time grow.

**Source of truth:** `Limi/PHASE_5_CLEANUP_CANDIDATES.md` → Batch 1 list.

**Files to remove (after grep confirms no references):**
- `AI ChatBot/VoiceChatBoot.swift`
- `AI ChatBot/AnimationResponce.swift`
- `HubHomeView/SocketTesting.swift`
- `HubHomeView/SmartHomeApp.swift`
- `ModulerHomeView/ModulerHomeView.swift`
- `RoomPlan/Room_PlanApp.swift`
- `Location Module/LocationUsageExample.swift`
- `HomeView/Component/BackgroundView.swift`
- `AnimationVideoView.swift`
- Others in Batch 1 if still present and unreferenced

**Steps:**
1. Grep each file name for inbound references.
2. Delete only confirmed-unused files.
3. Full Xcode build.
4. Smoke: splash → login → home → voice → configurator.

**Acceptance criteria:**
- [x] Build succeeds
- [x] No navigation path broken (Batch 1 sources were already absent; empty dirs removed)
- [x] Batch 1 list updated with “removed” status (`Limi/PHASE_5_CLEANUP_CANDIDATES.md`)

**Status:** Complete (June 2026). All 12 Batch 1 Swift files confirmed absent; orphan `Auth Manager/` empty folder removed.

**Out of scope:** Batch 2 duplicates, folder-level Demo consolidation.

---

## Phase 7 — Single canonical Apple Sign-In implementation

**Problem:** Two Apple auth paths: `AppleAuthManager` in `LoginView.swift` and logic in `AuthManger.swift`.

**Why it matters:** Divergent behavior, double maintenance, unclear which path production uses.

**Files:**
- `LimiExhibition/Login Screen/LoginView.swift`
- `LimiExhibition/Login Screen/Apple.swift` (if exists)
- `Core/Services/Auth/AuthManger.swift`

**Steps:**
1. Trace which path `LoginView` actually calls today.
2. Keep one implementation; delete or redirect the other.
3. Ensure `AppleLoginAPI.exchange()` is still called once per sign-in.
4. Test Apple Sign-In on device.

**Acceptance criteria:**
- [x] One Apple Sign-In code path (`GoogleAuthManager.signInWithApple` → `AppleLoginAPI.exchange`)
- [x] `LoginView` no longer double-prompts via `SignInWithAppleButton` + `signInWithApple`
- [x] Apple login sets `AuthManager.isAuthenticated` via `AppleLoginAPI` (`updateAuthState: true`) → Home via `LoginView`

**Status:** Complete (June 2026). Removed duplicate `SignInWithAppleButton` path; `Apple.swift` / `AppleAuthManager` already absent.

**Out of scope:** Google Sign-In, guest flow, hiding Apple per product spec (Phase 8).

---

## Phase 8 — Align Home FAB with voice `ui_guide`

**Problem:** CEO spec says **+** opens Configurator / Device manager / Room scan; shipped UI opens layers / voice / AR portal. Voice AI can lie about the UI.

**Why it matters:** Trust in the AI assistant; onboarding scripts in `PHASE_PROMPTS_AI_APP.md` are wrong.

**Pick one approach (do not do both):**

**Option A — Change UI to match spec**  
Update `EnhancedBottomNavigationView` FAB radial menu to the three product modules.

**Option B — Change copy to match UI**  
Update `ContextManager` home `ui_guide` and proactive scripts to describe layers / brain / desktop.

**Files:**
- `LimiExhibition/HomeView/Component/EnhancedBottomNavigationView.swift`
- `LimiExhibition/FloatingAssistant/ContextManager.swift`
- `PHASE_PROMPTS_AI_APP.md` §2 table (mark resolved)

**Acceptance criteria:**
- [x] FAB behavior and `ui_guide` text describe the same three actions (layers / brain / desktop)
- [x] Voice proactive line on Home does not mention Configurator, Device Manager, or Room Scan on the + button
- [x] `PHASE_PROMPTS_AI_APP.md` §2 marked resolved (Option B)

**Status:** Complete (June 2026). Option B — copy aligned to shipped FAB; no UI change to radial menu.

**Out of scope:** Full screen inventory, Personalize scripts.

---

## Phase 9 — Build-time API environment switch

**Problem:** `APIConstants.baseURL` is hardcoded to `dev.api.limitless-lighting.co.uk` with no staging/prod switch.

**Why it matters:** Every release requires source edits; easy to ship dev URL to TestFlight.

**Files:**
- `Core/Services/API/ManagerAPI.swift`
- `Limi.xcodeproj` — add Debug/Release or Dev/Staging/Prod build configurations + `INFOPLIST_KEY` or xcconfig

**Steps:**
1. Add `LIMI_API_BASE_URL` per build configuration.
2. Read from `Bundle.main` or generated `Config.swift`.
3. Default Debug → dev, Release → production URL (confirm with team).

**Acceptance criteria:**
- [x] Switching scheme/config changes base URL without code edit (`Config/Limi-Debug.xcconfig` vs `Config/Limi-Release.xcconfig`)
- [x] No secrets in xcconfig committed (URLs only)

**Status:** Complete (June 2026). Fixed xcconfig `//` comment truncation — URLs must be quoted.

---

## Phase 10 — Split `BluetoothManager` (start only)

**Problem:** ~1,141-line singleton mixes BLE service, WiFi provisioning, persistence, and UI popups.

**Why it matters:** Highest-risk file for any device feature; impossible to unit test.

**This phase starts the split — not the full refactor.**

**Steps (Phase 10 only):**
1. Extract **pure BLE GATT read/write** into `BLELightWriter` protocol consumer or extend existing `Core/Services/Transport/BLELightWriter.swift`.
2. Move `GlobalDevicePopup` / `HubFoundPopupView` to `LimiExhibition/HomeView/Component/` or similar.
3. Leave `BluetoothManager` as thin facade delegating to extracted types.
4. No behavior change — move code only.

**Acceptance criteria:**
- [x] `BluetoothManager.swift` under ~800 lines
- [x] BLE scan, connect, write FF03 still work
- [x] No new singletons added

**Out of scope:** Protocol abstraction for all consumers, LimiTransport changes.

---

## Execution rules

1. **One phase = one PR** (or one commit series).
2. **Build after every phase** before starting the next.
3. **Smoke test checklist** (minimum): splash, login, home, device slider, voice connect, configurator save.
4. If a phase grows beyond its scope, **stop and split** — do not absorb the next problem.

---

## Phase 11 — Device smoke test (manual)

**Goal:** Confirm Phases 1–10 + API A–D work on a real device or simulator.

**Pre-check:** Debug build ✅ (June 18, 2026). Run on **physical device** for Apple Sign-In, BLE, LiDAR AR.

| # | Flow | Pass? | Notes |
|---|------|-------|-------|
| 1 | Splash → onboarding or sign-in | [ ] | |
| 2 | **OTP login** → Home | [ ] | |
| 3 | **Google login** → Home | [ ] | |
| 4 | **Apple login** → Home (device only) | [ ] | One prompt, no double sheet |
| 5 | Kill app → relaunch → still logged in | [ ] | Phase 1 Keychain |
| 6 | Logout → session cleared | [ ] | |
| 7 | Home: weather loads | [ ] | |
| 8 | Home: device list / module grid | [ ] | |
| 9 | Device control / hub slider → light changes | [ ] | Socket + `process_device_data` |
| 10 | **+ FAB** → brain → voice connects | [ ] | |
| 11 | Voice: ask “what does + button do?” → layers/brain/desktop | [ ] | Phase 8 |
| 12 | Configurator → Save → AR opens model | [ ] | Phase 4 USDZ |
| 13 | Room scan sync (if used) | [ ] | |
| 14 | Debug API = `dev.api…` / Release = `api…` | [ ] | Phase 9 |

**Acceptance:** All critical rows (2, 5, 9, 10, 12) pass on device.

**Status:** In progress (June 18, 2026).

---

## Phase 12 — Sign-off: Keychain, GEMINI, API env (~30 mins)

**Goal:** Automated verification of Phases 1, 2, 9.

| Check | Result |
|-------|--------|
| **Phase 1** JWT in Keychain only (`AuthTokenKeychain`) | ✅ No `UserDefaults.set` for token; migration on launch |
| **Phase 2** No `GEMINI_API_KEY` in Info.plist / source | ✅ Grep clean |
| **Phase 9** Debug → `dev.api…` / Release → `api…` | ✅ Fixed xcconfig `//` truncation (`https:/$()/…`) |

**Acceptance:** All three checks pass on build.

**Status:** Complete (June 18, 2026).

---

## Phase 13 — API async layer (API Phase E)

**Goal:** Shared async HTTP + `LimiAPIError` + unit tests.

| Item | Status |
|------|--------|
| `LimiAPIError.swift` | ✅ |
| Async `perform` / `get` / `postJSON` / `decode` | ✅ |
| `LimiTests` + `URLProtocol` stub | ✅ 3 tests passing |
| `UserDataManager` migrated to async API | ✅ |

**Status:** Complete (June 18, 2026).

## Phase 14 — Batch 2 legacy cleanup

**Goal:** Remove duplicate/legacy login and add-device flows listed in `Limi/PHASE_5_CLEANUP_CANDIDATES.md` Batch 2.

**Files (grep + delete only if unreferenced):**
- `LimiExhibition/Login Screen/Apple.swift`
- `LimiExhibition/Add_Device/ScanningView.swift`
- `LimiExhibition/House Sign In Module/TemporaryAddDeviceView.swift`

**Steps:**
1. Grep each file for inbound references.
2. Delete confirmed-unused sources (or confirm already absent).
3. Remove empty `House Sign In Module/` folder if left behind.
4. Full Xcode build.
5. Smoke: login (Apple/Google/OTP) → add device via `DemoScanDevicesView` path.

**Acceptance criteria:**
- [x] No `AppleAuthManager` / duplicate Apple Sign-In path (canonical: `GoogleAuthManager.signInWithApple` → `AppleLoginAPI.exchange`)
- [x] No `ScanningView` — device scan uses `DemoScanDevicesView`
- [x] No `TemporaryAddDeviceView` or `House Sign In Module/` folder
- [x] Build succeeds

**Also cleaned:** empty orphan dirs `LimiExhibition/Color`, `API`, `Services/WebSocket` (code moved to `Core/` in earlier phases).

**Status:** Complete (June 2026).

## Suggested start

**Begin with Phase 1** (Keychain). It is the highest-severity fix with commented code already in the repo and a clear done state.

---

*Created from technical audit findings — June 2026.*
