# API Cleanup Roadmap

High-level plan to standardize HTTP/API usage across the LIMI iOS app.

**Status:** Phase D complete (June 2026).

---

## Target architecture

```
Config/*.xcconfig → LimiAPIConfiguration.baseURL
                         ↓
                   APIConstants.*     (Limi backend REST paths)
                   AppURLs.*          (external, web, WLED, weather)
                         ↓
                   LimiHTTPClient      (auth + JSON helpers)
                         ↓
                   URLSession.shared   (single transport for now)
```

**Auth rules (Phase C — unified):**

| Style | When | Header / transport |
|-------|------|-------------------|
| **Bearer JWT** | All authenticated REST routes (default) | `AuthManager.authorizationHeaderValue()` via `LimiAPIAuthPolicy` |
| **None** | Pre-login, public 3D downloads, light-config GET | — |
| **Optional Bearer** | Onboarding prefs, light-config check, room scan upload | Attached when logged in |
| **Webhook raw** | `limi-ai/webhook` only | `LimiHTTPClient` `.webhook` / `webhookAuthValue()` |
| **Socket raw** | Socket.IO connect param | `auth: <jwt>` — not HTTP header |

Policy lives in `LimiAPIAuthPolicy.swift`. Call sites should omit explicit `auth:` and let the policy resolve it.

---

## Phase C — Auth header unification (done)

1. [x] Added `LimiAPIAuthPolicy` — path + method → auth requirement
2. [x] Standardized authenticated REST on **Bearer JWT** (was mixed raw/Bearer)
3. [x] Webhook stays **raw JWT** via `.webhook` requirement
4. [x] Documented Socket.IO raw token in policy + `LightControllingSocket`
5. [x] Removed per-call-site `authStyle` / `.requiredRaw` overrides where policy applies
6. [x] `WebRTCVoiceClient` session + webhook use `LimiHTTPClient.buildRequest`

**Note:** If any legacy route rejects Bearer, add an exception in `LimiAPIAuthPolicy` — do not scatter auth logic in views.

---

## Phase A — Foundation (done in this pass)

- [x] Add `APIConstants.limiAISession`
- [x] Add `AppURLs.External.openMeteoForecast` (active weather API)
- [x] Remove unused `addDeviceInfo`, `transcribeAudio`, OpenWeather `weatherAPI`
- [x] Create `Core/Services/API/LimiHTTPClient.swift`
- [x] Fix Hub views reading `UserDefaults "authToken"` → `AuthManager` via `LimiHTTPClient`
- [x] Wire `WebRTCVoiceClient` session URL to `APIConstants.limiAISession`
- [x] Wire `WeatherService` to `AppURLs.External.openMeteoForecast`
- [x] Migrate `ScanSyncManager` to `LimiHTTPClient` + `.bearer`

---

## Phase B — Migrate call sites to `LimiHTTPClient` (done)

Replace inline `URLRequest` + `URLSession.shared.dataTask` copy-paste.

| Priority | File | Endpoint(s) | Status |
|----------|------|-------------|--------|
| High | `PWM2LEDView`, `DataRGBView`, `MiniControllerView` | `processDeviceData` via `LimiDeviceAPI` | ✅ |
| High | `ConnectedDevice`, `DeviceAllocationService`, `HomeViewModel` | `deviceUser` via `LimiDeviceAPI` | ✅ |
| Medium | `DeviceServiceProtocol` | `getLinkDevices` | ✅ |
| Medium | `UserDataResponse`, `ProfileEditView` | `userData`, `editProfile` | ✅ |
| Medium | `PortalWebView`, `3DModelList`, `LimiWebConfigurator`, `demoARView` | 3D / light-config via `LimiConfiguratorAPI` | ✅ |
| Low | Login flow, `GetStart`, `PULoginView`, `Personalize` | auth / onboarding | ✅ |
| Low | `AuthManger`, `AuthResponseParsing` | Google / Apple login | ✅ |
| Low | `RoomPlanContentView`, `RoomCaptureController` | room 3D models | ✅ |

**New helpers:** `LimiDeviceAPI.swift`, `LimiConfiguratorAPI.swift`, extended `LimiHTTPClient` (`buildRequest`, `perform`, `get`, `download`, `data(for:)` async).

**Acceptance:** ✅ No direct `UserDefaults` token reads; Limi REST call sites use `LimiHTTPClient` / domain APIs.

**Intentionally unchanged (Phase C/D):**
- `WebRTCVoiceClient` — OpenAI + webhook (specialized WebRTC flow)
- `WLEDController` / `WLEDView` — local device HTTP
- `ScanSyncManager` download — uses backend-provided `downloadURL` (not `APIConstants`)
- `WeatherService` / image CDN fetches — external URLs

---

## Phase D — Remaining URL registry (done)

| Item | Status |
|------|--------|
| Device WebSocket `ws://<ip>/ws` | ✅ `AppURLs.Device.webSocketURL(ip:)` → `DeviceWebSocketClient` |
| Socket.IO cloud endpoint | ✅ `AppURLs.Realtime.socketIOURL` → `LightControllingSocket`, `SocketIOExample` |
| OpenAI Realtime | ✅ already `AppURLs.External.openAIRealtime` |
| Vercel configurator / AR portal | ✅ already `AppURLs.Web.*` |
| WLED local HTTP | ✅ already `AppURLs.WLED.*` |
| WhatsApp deep links | ✅ `AppURLs.External.whatsAppURL` |
| Dead hardcoded prod URL (RoomPlan comment) | ✅ removed |

All non-dynamic external URLs now live in `ManagerAPI.swift` → `AppURLs` / `APIConstants` / `LimiAPIConfiguration`.

---

## Phase E — Async API layer (done — June 2026)

- [x] `LimiHTTPClient.perform` / `get` / `postJSON` async (throws `LimiAPIError`)
- [x] `LimiHTTPClient.decode(_:from:)` shared JSON decode
- [x] `LimiAPIError` — HTTP status, transport, decode, backend messages
- [x] `LimiTests` + `URLProtocol` stub (`LimiURLProtocolStub`)
- [x] Sample migration: `UserDataManager.performFetchUserData`

---

## Dead / reserved backend endpoints

These were removed from `APIConstants` because no Swift call site exists. Re-add when wiring UI:

- `admin/add_master_controller_hub_device`
- `limi-ai/transcribe-audio`

---

## Smoke test after each phase

1. Login (Google / Apple / OTP)
2. Home → device list loads
3. Hub device control → `process_device_data` succeeds
4. Voice connect → session + webhook
5. Room scan sync
6. Weather widget

---

*See also: `PHASED_FIX_ROADMAP.md` (security/reliability phases 1–10).*
