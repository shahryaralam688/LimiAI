# Hotel Module Audit

## Objective
- Audit `Hotel Module` for active usage, MVVM violations, cleanup candidates, and safe migration order.
- Prepare the module for incremental refactor without breaking hotel-specific flows.

## Folders Audited
- `Limi/LimiExhibition/Hotel Module/Hotel Home View`
- `Limi/LimiExhibition/Hotel Module/HotelWLED`
- `Limi/LimiExhibition/Hotel Module/Profile`
- `Limi/LimiExhibition/Hotel Module/Requests`
- `Limi/LimiExhibition/Hotel Module/scheduling`
- `Limi/LimiExhibition/Hotel Module/AI Views`

## Active Entry Points
- `Limi/LimiExhibition/GetStart/GetStart.swift` routes to `HotelHomeView()`
- `Limi/LimiExhibition/HubHomeView/DataRGBView.swift` routes to `HotelHomeView()`
- `Limi/LimiExhibition/HubHomeView/PWM2LEDView.swift` routes to `HotelHomeView()`

## Files Found

### Hotel Home View
- `Limi/LimiExhibition/Hotel Module/Hotel Home View/HotelHomeView.swift`

### HotelWLED
- `Limi/LimiExhibition/Hotel Module/HotelWLED/CCTLEDView.swift`
- `Limi/LimiExhibition/Hotel Module/HotelWLED/HotelRoomDevices.swift`
- `Limi/LimiExhibition/Hotel Module/HotelWLED/SubDevicesView.swift`
- `Limi/LimiExhibition/Hotel Module/HotelWLED/WarmCoolSliderPreference.swift`
- `Limi/LimiExhibition/Hotel Module/HotelWLED/WLEDController.swift`
- `Limi/LimiExhibition/Hotel Module/HotelWLED/WLEDView.swift`

### Profile
- `Limi/LimiExhibition/Hotel Module/Profile/NotificationView.swift`
- `Limi/LimiExhibition/Hotel Module/Profile/PrivacyPolicyView.swift`
- `Limi/LimiExhibition/Hotel Module/Profile/ProfileView.swift`

### Requests
- `Limi/LimiExhibition/Hotel Module/Requests/HotelRequestView.swift`
- `Limi/LimiExhibition/Hotel Module/Requests/RequestSummary.swift`

### Scheduling
- `Limi/LimiExhibition/Hotel Module/scheduling/SchdedulingSummary.swift`
- `Limi/LimiExhibition/Hotel Module/scheduling/SchedulingView.swift`

### AI Views
- `Limi/LimiExhibition/Hotel Module/AI Views/AIAppStoreView.swift`
- `Limi/LimiExhibition/Hotel Module/AI Views/AIConnectionsView.swift`
- `Limi/LimiExhibition/Hotel Module/AI Views/AIMainView.swift`
- `Limi/LimiExhibition/Hotel Module/AI Views/IntegrateNewAIView.swift`

## Reference Findings
- `HotelHomeView.swift` is actively reachable from `GetStart.swift`, `DataRGBView.swift`, and `PWM2LEDView.swift`.
- `HotelHomeView.swift` embeds:
  - `HotelRequestView()`
  - `HotelRoomDevices()`
  - `ProfileView()`
- `ProfileView.swift` presents:
  - `PrivacyPolicyView()`
  - `NotificationView()`
  - `AIAppStoreView()`
  - `AIConnectionsView()`
- `VoiceView.swift` also presents `AIAppStoreView()`, so hotel AI views are not strictly hotel-isolated.
- `AIMainView.swift` switches between:
  - `AIAppStoreView()`
  - `AIConnectionsView()`
  - `IntegrateNewAIView()`

## Current Architecture Problems
- `HotelHomeView.swift` is the hotel shell, but it owns tab routing, BLE bootstrap intent, socket setup, location permission start, voice presentation, and feature navigation state.
- `HotelRoomDevices.swift` mixes UI tabs, live BLE state, shared device coordination, routing by raw bytes, and modal presentation in one file.
- `ProfileView.swift` is not hotel-local in behavior; it owns auth/session reset, onboarding reset, room scanning, configurator, AI surfaces, and language switching.
- `WLEDController.swift` contains device model, SSDP discovery, mDNS discovery, network transport, and UI-related observable state in the same file.
- Hotel subfolders are feature-shaped visually, but shared logic is still mixed directly inside views instead of feature services or view models.

## MVVM Violation List

### High Severity
- `Limi/LimiExhibition/Hotel Module/Hotel Home View/HotelHomeView.swift`
  - Directly owns `SocketIOExample`, `BluetoothManager`, and `LocationManager`
  - Starts socket and location lifecycle inside the view
  - Owns tab shell and modal navigation state
- `Limi/LimiExhibition/Hotel Module/HotelWLED/HotelRoomDevices.swift`
  - `BLEDevicesView` directly uses `BluetoothManager.shared` and `SharedDevice.shared`
  - Routes based on raw byte values inside the view
  - Owns BLE connection-to-screen decision logic
- `Limi/LimiExhibition/Hotel Module/Profile/ProfileView.swift`
  - Directly uses `UserDataManager.shared`, `AuthManager.shared`, `BluetoothManager.shared`
  - Handles logout/session reset/onboarding reset in the view
  - Owns cross-feature navigation and role-based gating
- `Limi/LimiExhibition/Hotel Module/HotelWLED/WLEDController.swift`
  - Discovery manager, network transport, parsing, and state are tightly coupled

### Medium Severity
- `Limi/LimiExhibition/Hotel Module/Requests/HotelRequestView.swift`
  - Static sample data, tab state, and summary composition all live in one view
  - Good refactor candidate for a simple `HotelRequestViewModel`
- `Limi/LimiExhibition/Hotel Module/scheduling/SchedulingView.swift`
  - View owns stateful model array, tab filtering, derived lists, and selection logic
  - `Schedule` is an `ObservableObject` used as a view-local model, which is not ideal for a simple feature list
- `Limi/LimiExhibition/Hotel Module/AI Views/AIMainView.swift`
  - View owns screen switching and voice assistant launch logic

## File Classification

| File | Classification | Reason | Risk |
|---|---|---|---|
| `Limi/LimiExhibition/Hotel Module/Hotel Home View/HotelHomeView.swift` | Refactor into MVVM | Hotel root shell with socket, BLE, location, tab, and modal state | High |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/HotelRoomDevices.swift` | Refactor into MVVM | Strong BLE/shared-device coupling and routing logic in view | High |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/WLEDController.swift` | Move and split | Discovery/network logic should be service-oriented | High |
| `Limi/LimiExhibition/Hotel Module/Profile/ProfileView.swift` | Refactor into MVVM | Shared session/auth/navigation logic inside view | High |
| `Limi/LimiExhibition/Hotel Module/Requests/HotelRequestView.swift` | Refactor into MVVM | Static data and tab state in view | Medium |
| `Limi/LimiExhibition/Hotel Module/scheduling/SchedulingView.swift` | Refactor into MVVM | Derived business logic and mutable list filtering in view | Medium |
| `Limi/LimiExhibition/Hotel Module/AI Views/AIMainView.swift` | Refactor into MVVM | Screen-switching and assistant launch logic in view | Medium |
| `Limi/LimiExhibition/Hotel Module/AI Views/AIAppStoreView.swift` | Keep for now | Active child screen; usage confirmed | Low |
| `Limi/LimiExhibition/Hotel Module/AI Views/AIConnectionsView.swift` | Keep for now | Active child screen; usage confirmed | Low |
| `Limi/LimiExhibition/Hotel Module/AI Views/IntegrateNewAIView.swift` | Review manually | Reached through `AIMainView`, but likely convertible to reusable/shared AI feature later | Medium |
| `Limi/LimiExhibition/Hotel Module/Profile/NotificationView.swift` | Keep as-is for now | Leaf screen; no structural urgency | Low |
| `Limi/LimiExhibition/Hotel Module/Profile/PrivacyPolicyView.swift` | Keep as-is for now | Leaf screen; also used outside hotel auth flow | Low |
| `Limi/LimiExhibition/Hotel Module/Requests/RequestSummary.swift` | Keep as-is for now | Summary screen, likely leaf/detail view | Low |
| `Limi/LimiExhibition/Hotel Module/scheduling/SchdedulingSummary.swift` | Rename | Typo in filename and likely type naming drift | Low |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/CCTLEDView.swift` | Review manually | Also referenced from non-hotel connected-device flows | Medium |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/WLEDView.swift` | Review manually | Also referenced from non-hotel connected-device flows | Medium |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/SubDevicesView.swift` | Review manually | Likely part of WLED flow, but usage should be verified during WLED split | Medium |
| `Limi/LimiExhibition/Hotel Module/HotelWLED/WarmCoolSliderPreference.swift` | Keep as-is | Small utility/helper-style file | Low |

## Proposed Target Structure

```text
Features
  Hotel
    Views
      HotelHomeView.swift
      Requests/
      Scheduling/
      AI/
      Profile/
    ViewModels
      HotelHomeViewModel.swift
      HotelRequestsViewModel.swift
      HotelScheduleViewModel.swift
      HotelProfileViewModel.swift
    Models
      HotelRequest.swift
      HotelSchedule.swift
Core
  Services
    WebSocket/
    Location/
    Discovery/
    WLED/
Shared
  Components
    Hotel/
    AI/
```

## Recommended Refactor Order
1. `HotelHomeView.swift`
2. `HotelRoomDevices.swift`
3. `ProfileView.swift`
4. `WLEDController.swift`
5. `HotelRequestView.swift`
6. `SchedulingView.swift`
7. `AIMainView.swift`

## Safe Cleanup Status
- No safe file removals identified in this pass.
- This module is active and cross-connected.
- Renaming and splitting are safer than deletion.

## Risks
- BLE and socket behavior are tightly coupled to hotel UI entry points.
- `ProfileView.swift` is shared in behavior even if foldered under hotel, so refactoring it may affect non-hotel flows.
- `WLEDView.swift` and `CCTLEDView.swift` are not hotel-exclusive despite their folder placement.

## Validation Checklist
- Build after each extraction step.
- Smoke test:
  - `GetStart -> HotelHomeView`
  - `HotelHomeView` tabs: Home / Requests / System / Profile
  - `HotelRoomDevices` BLE device routing
  - hotel profile logout flow
  - AI sheets from `ProfileView`
  - any WLED/CCT flows launched from connected-device screens

## Recommended Starting Point
- Start with `HotelHomeView.swift`.
- First pass should only extract:
  - tab selection state
  - voice presentation state
  - socket connection bootstrap
  - location startup trigger
- Do not touch `HotelRoomDevices` internals until the shell is stabilized.
