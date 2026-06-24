# Phase 5: Cleanup Candidate Report

## Objective

Identify files and modules that appear unused, deprecated, duplicate, temporary, experimental, or legacy, and classify them into safe cleanup buckets.

This report does **not** delete files. It is the approval and execution input for later cleanup.

## Important Project Constraint

The Xcode project uses a synchronized root group for `LimiExhibition`:

- `PBXFileSystemSynchronizedRootGroup` -> `LimiExhibition`

That means many files may be target-visible even when they are not individually listed in `project.pbxproj`.

Because of that:

- absence from `project.pbxproj` is **not enough** to mark a file removable
- direct code references plus feature-flow verification are the main signals
- build validation is mandatory after deletion

## Classification Legend

- `Safe to remove later after confirmation`
- `Likely unused`
- `Likely deprecated or duplicate`
- `Manual review required`
- `Keep`

## A. Safe To Remove Later After Confirmation

**Batch 1 status (Phase 6 — June 2026): removed.** All 12 Swift sources were already absent from `LimiExhibition/`; empty `ModulerHomeView/`, `AIHomeView/`, and `Auth Manager/` folders cleaned. Build verified.

| Path | Reason | Risk | Status |
|---|---|---|---|
| `Limi/LimiExhibition/Splash Screen Module/LocationStorage.swift` | Entire file is commented-out legacy `LocationStorageView` code | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/Auth Manager/TestingSignIn.swift` | Appears to be a standalone auth test view with no active references found | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/AIHomeView/AIHomeView.swift` | Standalone prototype shell, no inbound usage found | Low | **Removed** (already absent; empty dir + asset catalog cleaned) |
| `Limi/LimiExhibition/AI ChatBot/VoiceChatBoot.swift` | Legacy voice/chat boot screen with no active references found | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/AI ChatBot/AnimationResponce.swift` | No active references found | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/AnimationVideoView.swift` | Standalone wrapper/controller with no active references found | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/HomeView/Component/BackgroundView.swift` | No active references found; likely replaced by `DeepSpaceBackground` in design system | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/HubHomeView/SmartHomeApp.swift` | Old standalone app shell artifact | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/HubHomeView/SocketTesting.swift` | Testing artifact, no active references found | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/ModulerHomeView/ModulerHomeView.swift` | No active references found | Low | **Removed** (already absent; empty dir cleaned) |
| `Limi/LimiExhibition/Location Module/LocationUsageExample.swift` | Example/demo utility view, no active product flow usage | Low | **Removed** (already absent) |
| `Limi/LimiExhibition/RoomPlan/Room_PlanApp.swift` | Old standalone `App` entry, not used as current main app shell | Low | **Removed** (already absent) |

## B. Likely Unused

These files are strong candidates for removal, but they overlap with active domains enough that a feature-owner pass is still recommended first.

| Path | Reason | Risk |
|---|---|---|
| `Limi/LimiExhibition/Login Screen/Apple.swift` | Separate Apple auth implementation duplicates Apple sign-in already embedded in `LoginView.swift` and `AuthManger.swift` | Medium | **Removed** (already absent; canonical path is `GoogleAuthManager.signInWithApple` → `AppleLoginAPI.exchange`) |
| `Limi/LimiExhibition/House Sign In Module/TemporaryAddDeviceView.swift` | Large standalone alternate sign-in/add-device flow with no active references found | Medium | **Removed** (already absent; empty `House Sign In Module/` folder deleted June 2026) |

## C. Likely Deprecated Or Duplicate

These files are not necessarily dead, but they show overlap with newer flows or self-identify as obsolete.

| Path | Reason | Risk |
|---|---|---|
| `Limi/LimiExhibition/Add_Device/ScanningView.swift` | File explicitly labels its own flow deprecated and points users toward `DemoScanDevicesView` | Medium | **Removed** (already absent; active flow uses `DemoScanDevicesView`) |
| `Limi/LimiExhibition/Login Screen/Apple.swift` | Duplicate Apple sign-in path | Medium |
| `Limi/LimiExhibition/Splash Screen Module/LocationStorage.swift` | Commented duplicate of current location onboarding/storage UI | Low |

## D. Manual Review Required

These are the highest-probability cleanup buckets, but they are broad enough that deleting them wholesale would be unsafe without per-file confirmation.

### 1. `Limi/LimiExhibition/Demo/`

Files:
- `DemoAddDeviceView.swift`
- `DeviceSearchSheet.swift`
- `LightCard.swift`
- `LightScreen.swift`

Why review:
- some demo add-device flows are still referenced indirectly from active home components
- there may be real fallback flows mixed with prototype UI

Current recommendation:
- do not remove folder wholesale
- review file-by-file and fold required files into `Features/AddDevice`

### 2. `Limi/LimiExhibition/Device Demo Module/`

Files include:
- `DemoAddDevicesView.swift`
- `DemoAddingWifiView.swift`
- `DemoScanDevicesView.swift`
- `DemoWifiConnected.swift`
- `SimplePing.swift`
- `WifiList.swift`

Why review:
- parts of this module are referenced by active home/add-device flows
- `ScanningView.swift` points users toward `DemoScanDevicesView`

Current recommendation:
- keep for now
- later consolidate into `Features/AddDevice`

### 3. `Limi/LimiExhibition/House Sign In Module/`

Why review:
- naming suggests temporary or legacy flow
- `TemporaryAddDeviceView.swift` appears unreferenced, but the whole area should be reviewed before removal in case assets or helpers are reused elsewhere

Current recommendation:
- isolate and review before delete

### 4. `Limi/LimiExhibition/HubHomeView/`

Why review:
- likely legacy smart-home module
- some files may still contain reusable device-control UI even if the module shell is unused

Current recommendation:
- likely major cleanup candidate
- do not remove as one batch until file-level usage is checked

## E. Keep

These should remain part of the current product baseline for now.

### Core active areas

- `Limi/LimiExhibition/API/`
- `Limi/LimiExhibition/Common/`
- `Limi/LimiExhibition/Color/`
- `Limi/LimiExhibition/Services/`
- `Limi/LimiExhibition/FloatingAssistant/`
- `Limi/LimiExhibition/Location Module/LocationHelper.swift`
- `Limi/LimiExhibition/LimiExhibitionApp.swift`
- `Limi/LimiExhibition/Splash Screen Module/SplashScreen.swift`

### Active feature areas

- `Limi/LimiExhibition/HomeView/`
- `Limi/LimiExhibition/Login Screen/LoginView.swift`
- `Limi/LimiExhibition/GetStart/`
- `Limi/LimiExhibition/Onboard/`
- `Limi/LimiExhibition/Personalize/`
- `Limi/LimiExhibition/Add_Device/` except explicitly deprecated candidates
- `Limi/LimiExhibition/AI ChatBot/VoiceView.swift`
- `Limi/LimiExhibition/AI ChatBot/WebRTCVoiceClient.swift`
- `Limi/LimiExhibition/AI ChatBot/WhatsAppContactMessenger.swift`
- `Limi/LimiExhibition/Configurator/`
- `Limi/LimiExhibition/ARSession/`
- `Limi/LimiExhibition/Hotel Module/`
- `Limi/LimiExhibition/2D RoomPlan/`
- `Limi/LimiExhibition/RoomPlan/` except `Room_PlanApp.swift`

## Proposed Deletion Order

Delete in the smallest-risk batches first.

### Batch 1: Low-risk isolated files

- `Splash Screen Module/LocationStorage.swift`
- `Auth Manager/TestingSignIn.swift`
- `AIHomeView/AIHomeView.swift`
- `AI ChatBot/VoiceChatBoot.swift`
- `AI ChatBot/AnimationResponce.swift`
- `AnimationVideoView.swift`
- `HomeView/Component/BackgroundView.swift`
- `HubHomeView/SmartHomeApp.swift`
- `HubHomeView/SocketTesting.swift`
- `ModulerHomeView/ModulerHomeView.swift`
- `Location Module/LocationUsageExample.swift`
- `RoomPlan/Room_PlanApp.swift`

### Batch 2: Duplicate/legacy flows

**Status (Phase 14 — June 2026): removed.** All three Swift sources were already absent; empty `House Sign In Module/` folder deleted. Device scan flow uses `DemoScanDevicesView`; Apple Sign-In uses `GoogleAuthManager.signInWithApple` → `AppleLoginAPI.exchange`.

- `Login Screen/Apple.swift` — **removed**
- `Add_Device/ScanningView.swift` — **removed**
- `House Sign In Module/TemporaryAddDeviceView.swift` — **removed**

### Batch 3: Folder-level consolidation after validation

- selected files from `Demo/`
- selected files from `Device Demo Module/`
- selected files from `HubHomeView/`

## Validation Checklist Before Any Deletion

- grep/reference scan shows no active inbound references
- feature owner confirms no manual navigation path depends on the file
- Xcode build passes after deletion batch
- navigation smoke test passes for:
  - splash
  - onboarding
  - login
  - home
  - add device
  - voice chat
  - configurator
  - hotel

## Recommended Next Action

Execute cleanup in `Batch 1` only, then build and re-audit.
