# Phase 2: MVVM Target Structure Blueprint

## Objective

Define the target production-ready folder structure for the current SwiftUI app, assign each current area to `App`, `Core`, `Shared`, or `Features`, and establish a safe migration order with `HomeView` as the canonical primary shell.

This phase does not delete files and does not require a full rewrite. It creates the map for later phased migration.

## Canonical App Flow

- App entry: `Limi/LimiExhibition/LimiExhibitionApp.swift`
- Launch/router shell: `Limi/LimiExhibition/Splash Screen Module/SplashScreen.swift`
- Default authenticated shell: `Limi/LimiExhibition/HomeView/HomeView.swift`
- Secondary feature shell: `Limi/LimiExhibition/Hotel Module/Hotel Home View/HotelHomeView.swift`

## Target Structure

```text
Limi/
  App/
    LimiApp.swift
    AppDelegate.swift
    AppRouter.swift
    AppEnvironment.swift

  Core/
    Models/
    Services/
      API/
      Auth/
      Bluetooth/
      Networking/
      Location/
      Storage/
      Web/
      WebSocket/
    Managers/
    Utilities/
    Extensions/
    DesignSystem/
    Resources/
      Fonts/
      Objects/
      Localization/

  Shared/
    Components/
    CommonViews/
    Helpers/

  Features/
    Authentication/
      Models/
      Services/
      ViewModels/
      Views/
      Components/
    Onboarding/
    Personalization/
    Home/
    AddDevice/
    AIChat/
    Configurator/
    ARSession/
    Hotel/
    RoomPlan3D/
    RoomPlan2D/
    Profile/
    Weather/
    AboutLimi/
```

## Naming Conventions

- Folders: PascalCase, no spaces, no underscores
- Feature folders: singular product/domain names where possible, e.g. `AddDevice`, `AIChat`, `RoomPlan2D`
- Horizontal layers inside each feature: `Models`, `Services`, `ViewModels`, `Views`, `Components`
- Shared UI only in `Shared`
- Cross-feature business logic only in `Core`
- `Manager` suffix only for lifecycle/shared coordination types
- `Service` suffix for API, storage, BLE, network, web, and device logic
- `ViewModel` suffix for presentation state and user actions

## Core vs Shared vs Feature Boundaries

### App

Owns:
- app lifecycle
- global routing bootstrap
- dependency composition
- environment injection

Should contain:
- `LimiExhibitionApp.swift`
- `AppDelegate.swift`
- future `AppRouter.swift`

### Core

Owns:
- auth token/session persistence
- API constants and HTTP clients
- Bluetooth stack
- websocket clients
- location infrastructure
- common storage
- global context tracking
- language/runtime settings
- design system and reusable app-wide styling primitives

Must not depend on feature views.

### Shared

Owns:
- reusable SwiftUI components
- generic common views
- presentation helpers with no feature-specific business logic

Should not own auth, BLE, or backend logic.

### Features

Own:
- screen-level flows
- feature-local models
- feature-local services and view models
- navigation within the feature

## Module Mapping: Old to New

### App

- `Limi/LimiExhibition/LimiExhibitionApp.swift` -> `Limi/App/LimiApp.swift`
- `Limi/LimiExhibition/AppDelegate.swift` -> `Limi/App/AppDelegate.swift`
- `Limi/LimiExhibition/ContentView.swift` -> review as legacy/dev shell before move

### Core / Services / API

- `Limi/LimiExhibition/API/ManagerAPI.swift` -> `Limi/Core/Services/API/APIConstants.swift`
- `Limi/LimiExhibition/API/AuthResponseParsing.swift` -> `Limi/Core/Services/Auth/AuthResponseParser.swift`
- `Limi/LimiExhibition/API/WeatherService.swift` -> `Limi/Core/Services/API/WeatherService.swift`
- `Limi/LimiExhibition/API/WeatherData.swift` -> `Limi/Core/Models/WeatherData.swift`

### Core / Services / Auth

- `Limi/LimiExhibition/AuthManager.swift` -> `Limi/Core/Services/Auth/AuthSessionStore.swift`
- `Limi/LimiExhibition/Auth Manager/AuthManger.swift` -> `Limi/Features/Authentication/Services/GoogleAppleAuthService.swift`

### Core / Services / Bluetooth

- `Limi/LimiExhibition/Services/Bluetooth/BluetoothManager.swift` -> split into:
  - `Limi/Core/Services/Bluetooth/BluetoothService.swift`
  - `Limi/Core/Services/Bluetooth/BluetoothProvisioningService.swift`
  - `Limi/Core/Models/DeviceInfo.swift`
  - `Limi/Core/Models/SelectedDevice.swift`
  - `Limi/Core/Managers/SelectedDevicesStore.swift`

### Core / Services / WebSocket

- `Limi/LimiExhibition/Services/WebSocket/LightControllingSocket.swift` -> `Limi/Core/Services/WebSocket/LightControllingSocket.swift`
- `Limi/LimiExhibition/Hotel Module/Hotel Home View/SocketIOExample.swift` -> `Limi/Core/Services/WebSocket/HotelSocketService.swift`

### Core / Services / Location

- `Limi/LimiExhibition/AI ChatBot/LocationManager.swift` -> `Limi/Core/Services/Location/LocationService.swift`
- `Limi/LimiExhibition/Location Module/LocationHelper.swift` -> `Limi/Core/Services/Location/LocationStorageService.swift`
- `Limi/LimiExhibition/Location Module/LocationStorageView.swift` -> feature view, not core

### Core / Managers

- `Limi/LimiExhibition/FloatingAssistant/ContextManager.swift` -> `Limi/Core/Managers/AppContextManager.swift`
- `Limi/LimiExhibition/FloatingAssistant/FloatingAssistantManager.swift` -> `Limi/Core/Managers/FloatingAssistantManager.swift`
- `Limi/LimiExhibition/Common/LanguageSettings.swift` -> `Limi/Core/Managers/LanguageSettings.swift`
- `Limi/LimiExhibition/ARSession/BackgroundLogic.swift` -> review whether `Core/Managers/AppBackgroundCoordinator.swift` or `Features/ARSession/Managers`

### Core / DesignSystem

- `Limi/LimiExhibition/Color/Color.swift` -> `Limi/Core/DesignSystem/AppColors.swift`
- `Limi/LimiExhibition/Color/LimiDesignSystem.swift` -> `Limi/Core/DesignSystem/LimiDesignSystem.swift`
- `Limi/LimiExhibition/Color/NeumorphicSystem.swift` -> `Limi/Core/DesignSystem/NeumorphicSystem.swift`

### Core / Networking

- `Limi/LimiExhibition/Common/NetworkMonitor.swift` -> `Limi/Core/Services/Networking/NetworkMonitor.swift`

### Core / Resources

- `Limi/Font/*` -> `Limi/Core/Resources/Fonts/`
- `Limi/Objects/*` -> `Limi/Core/Resources/Objects/`
- `Limi/LimiExhibition/Common/Localizable.xcstrings` -> `Limi/Core/Resources/Localization/Localizable.xcstrings`

### Features / Home

- `Limi/LimiExhibition/HomeView/HomeView.swift` -> `Limi/Features/Home/Views/HomeView.swift`
- `Limi/LimiExhibition/HomeView/ViewModel/HomeViewModel.swift` -> `Limi/Features/Home/ViewModels/HomeViewModel.swift`
- `Limi/LimiExhibition/HomeView/Model/*` -> `Limi/Features/Home/Models/`
- `Limi/LimiExhibition/HomeView/Services/*` -> `Limi/Features/Home/Services/`
- `Limi/LimiExhibition/HomeView/Moduler/*` -> split between `Features/Home` and future `Shared/Components`
- `Limi/LimiExhibition/HomeView/Component/*` -> triage into:
  - `Limi/Features/Home/Components/`
  - `Limi/Shared/Components/`
  - `Limi/Features/Weather/`

### Features / Authentication

- `Limi/LimiExhibition/Login Screen/LoginView.swift` -> `Limi/Features/Authentication/Views/LoginView.swift`
- `Limi/LimiExhibition/Login Screen/SignIn.swift` -> `Limi/Features/Authentication/Views/SignInView.swift`
- `Limi/LimiExhibition/Login Screen/Apple.swift` -> merge into auth feature, likely remove later after consolidation
- `Limi/LimiExhibition/Auth Manager/TestingSignIn.swift` -> auth test/demo candidate, review before removal
- `Limi/LimiExhibition/PULoginView.swift` -> `Limi/Features/Authentication/Views/PULoginView.swift`

### Features / Onboarding

- `Limi/LimiExhibition/Onboard/*` -> `Limi/Features/Onboarding/`
- `Limi/LimiExhibition/GetStart/*` -> split across:
  - `Limi/Features/Onboarding/`
  - `Limi/Features/Authentication/`
  - `Limi/Core` for role persistence if shared

### Features / Personalization

- `Limi/LimiExhibition/Personalize/Personalize.swift` -> `Limi/Features/Personalization/Views/PersonalizeView.swift`

### Features / AddDevice

- `Limi/LimiExhibition/Add_Device/*` -> `Limi/Features/AddDevice/`
- `Limi/LimiExhibition/Device Demo Module/*` -> review for merge into `Features/AddDevice` or remove later
- `Limi/LimiExhibition/Demo/*` -> review for merge into `Features/AddDevice` or remove later
- `Limi/LimiExhibition/House Sign In Module/TemporaryAddDeviceView.swift` -> review before migration

### Features / AIChat

- `Limi/LimiExhibition/AI ChatBot/VoiceView.swift` -> `Limi/Features/AIChat/Views/VoiceView.swift`
- `Limi/LimiExhibition/AI ChatBot/WebRTCVoiceClient.swift` -> `Limi/Features/AIChat/Services/WebRTCVoiceClient.swift`
- `Limi/LimiExhibition/AI ChatBot/WhatsAppContactMessenger.swift` -> `Limi/Features/AIChat/Services/WhatsAppContactMessenger.swift`
- `Limi/LimiExhibition/AI ChatBot/OrbView.swift` -> `Limi/Features/AIChat/Components/OrbView.swift`
- `Limi/LimiExhibition/AI ChatBot/VisualEffectBlur.swift` -> `Limi/Shared/CommonViews/VisualEffectBlur.swift`
- `Limi/LimiExhibition/AI ChatBot/VoiceChatBoot.swift` -> likely legacy/demo review
- `Limi/LimiExhibition/AI ChatBot/AnimationResponce.swift` -> likely legacy/demo review
- `Limi/LimiExhibition/AIHomeView/AIHomeView.swift` -> likely unused prototype, review before removal

### Features / Configurator

- `Limi/LimiExhibition/Configurator/*` -> `Limi/Features/Configurator/`

### Features / ARSession

- `Limi/LimiExhibition/ARSession/*` -> `Limi/Features/ARSession/`
- `Limi/LimiExhibition/ARSession/Data/*` -> `Limi/Features/ARSession/Models/` and `ViewModels/`

### Features / Hotel

- `Limi/LimiExhibition/Hotel Module/*` -> `Limi/Features/Hotel/`
- Subfolders normalize to:
  - `AI Views` -> `Views/AI/` or merge with `Features/AIChat` if not hotel-specific
  - `Hotel Home View` -> `Views/Home/`
  - `HotelWLED` -> `Services/WLED/` + `Views/WLED/`
  - `Profile` -> `Views/Profile/`
  - `Requests` -> `Views/Requests/`
  - `scheduling` -> `Views/Scheduling/`

### Features / RoomPlan2D

- `Limi/LimiExhibition/2D RoomPlan/*` -> `Limi/Features/RoomPlan2D/`

### Features / RoomPlan3D

- `Limi/LimiExhibition/RoomPlan/*` -> `Limi/Features/RoomPlan3D/`

### Features / AboutLimi

- `Limi/LimiExhibition/What is Limi/*` -> `Limi/Features/AboutLimi/`

### Shared

Likely candidates:
- `Limi/LimiExhibition/AI ChatBot/VisualEffectBlur.swift`
- selected reusable controls from `HomeView/Component`
- selected reusable controls from `Hotel Module`

Move only after deduplicating feature-specific assumptions.

## Consolidation Decisions

### Merge Candidates

- `AuthManager.swift` + auth persistence pieces used by login flows
- `Login Screen/Apple.swift` into main authentication feature
- duplicated/demo add-device flows across `Add_Device`, `Demo`, and `Device Demo Module`
- weather UI pieces currently split between `HomeView/Component/WeatherViewModel.swift` and generic API models/services

### Keep Separate

- `RoomPlan2D` and `RoomPlan3D`
- `Home` and `Hotel`
- `Configurator` and `ARSession`

## Migration Order

1. App shell normalization
2. Core extraction
3. Authentication feature
4. Home feature
5. AddDevice feature
6. AIChat feature
7. Configurator feature
8. ARSession feature
9. Hotel feature
10. RoomPlan3D
11. RoomPlan2D
12. Cleanup pass

## Why This Order

- `Authentication` and `Home` control the primary user path.
- `Core` extraction reduces repeated refactors inside later features.
- `AddDevice`, `AIChat`, `Configurator`, and `ARSession` are tightly coupled to shared infrastructure and benefit from early normalization.
- `Hotel` is now explicitly secondary to `HomeView`.
- `RoomPlan2D` is already relatively well-structured and can wait.

## Risks

- Moving files physically too early may break target membership and previews.
- Refactoring `BluetoothManager` prematurely could destabilize active device flows.
- Authentication routing is spread across onboarding, splash, login, and hotel flows.
- Some “unused” files may still be target members or referenced via Xcode-only navigation.

## Validation Checklist for Phase 2

- `HomeView` remains the canonical post-login shell
- each current folder has an explicit target destination
- `Core` contains only cross-feature logic
- `Shared` contains only reusable UI/helpers
- feature names are normalized and consistent
- no files are deleted in this phase

## What Waits for Later Phases

- actual file moves
- target membership cleanup
- extraction of view models from large views
- splitting `BluetoothManager`
- deletion of legacy/demo/prototype files
- build verification after each migration step
