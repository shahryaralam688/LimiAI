# Limi AI -- Comprehensive Technical Audit

> Produced by a Senior Solutions Architect audit of the full codebase.
> Date: April 16, 2026

---

## 1. Architecture Overview

### Pattern: Pragmatic MVVM with Singleton Services

The application follows a **loose MVVM (Model-View-ViewModel)** pattern, though enforcement is inconsistent across modules. Some modules (`HomeView`, `2D RoomPlan`) adhere to clean MVVM separation with dedicated `ViewModel/`, `Model/`, and `Views/` directories. Others (`Hotel Module`, `Demo`, `Configurator`) embed business logic directly in SwiftUI views.

Cross-cutting concerns (auth, Bluetooth, network, socket) are managed through **singleton `ObservableObject` classes** accessed globally via `.shared` static properties. This is a practical pattern for an IoT app but creates implicit coupling.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift (SwiftUI + UIKit bridges) |
| UI Framework | SwiftUI (primary), UIKit (`WKWebView`, `AVPlayerViewController`, `QLPreviewController`) |
| AR/3D | ARKit, RealityKit, RoomPlan, SceneKit, QuickLook |
| Networking | URLSession (REST), Socket.IO (real-time light control), WebRTC (AI voice) |
| Bluetooth | CoreBluetooth (BLE central + peripheral) |
| Auth | Google Sign-In (CocoaPods), Sign in with Apple (AuthenticationServices) |
| Persistence | UserDefaults (tokens, preferences, device maps), FileManager (USDZ models, scans) |
| Localization | `Localizable.xcstrings` with runtime bundle swizzling |
| Dependency Mgmt | CocoaPods (`Podfile.lock`) + Swift Package Manager (via Xcode project) |
| Build System | Xcode (`Limi.xcworkspace`) |
| Design System | Custom token-based system in `Color/` |
| Web Integration | WKWebView (Vercel-hosted configurator) |

### Layer Interaction

```
                          ┌──────────────────┐
                          │  @main YourApp   │
                          └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │   SplashScreen    │
                          └────────┬─────────┘
                   ┌───────────────┼───────────────┐
                   │               │               │
          ┌────────▼───┐  ┌───────▼──────┐ ┌──────▼──────────┐
          │ Location    │  │ Onboarding   │ │ Auth Check      │
          │ StorageView │  │ View         │ │ (isAuthenticated)│
          └────────────┘  └──────────────┘ └───────┬──────────┘
                                              ┌────┴────┐
                                         ┌────▼──┐ ┌────▼───┐
                                         │GetStart│ │HomeView│
                                         └───┬───┘ └────┬───┘
                                             │          │
                                        ┌────▼──┐  ┌────▼─────────────────────┐
                                        │SignIn │  │ Services Layer            │
                                        │View   │  │  • BluetoothManager      │
                                        └───────┘  │  • LightControllingSocket│
                                                   │  • REST API (URLSession) │
                                                   │  • WeatherService        │
                                                   └────┬─────────────────────┘
                                                        │
                                     ┌──────────────────┼──────────────────┐
                                     │                  │                  │
                                ┌────▼─────┐    ┌──────▼──────┐   ┌──────▼──────┐
                                │AR/Config │    │Hotel Module │   │AI ChatBot  │
                                │(WebView  │    │(WLED, Sched,│   │(WebRTC,    │
                                │ + USDZ)  │    │ Requests)   │   │ Voice)     │
                                └──────────┘    └─────────────┘   └────────────┘
                                                        │
                                          ┌─────────────┼──────────────┐
                                          │             │              │
                                   ┌──────▼──┐  ┌──────▼───┐  ┌──────▼──────┐
                                   │Physical │  │Backend   │  │Open-Meteo  │
                                   │BLE      │  │(REST +   │  │(Weather)   │
                                   │Devices  │  │Socket.IO)│  └────────────┘
                                   └─────────┘  └──────────┘
```

---

## 2. Project Structure and Responsibility Mapping

### Top-Level Directory

| Directory/File | Responsibility |
|---------------|---------------|
| `LimiExhibition/` | Main application target -- all source code, assets, configs |
| `Limi.xcworkspace` | Workspace file (required for CocoaPods integration) |
| `Limi.xcodeproj/` | Xcode project file |
| `Pods/` | CocoaPods-managed dependencies (GoogleSignIn and transitive deps) |
| `Font/` | Custom font files (Amenti, Poppins families) |
| `Objects/` | 3D model assets |
| `Limi Localizations/` | Localization resource bundles |
| `build/` | Build artifacts |
| `*.md` files | Documentation: `README.md`, `PHASED_ROADMAP_AI.md`, `THEME_GUIDE.md`, `FIRMWARE_DEVELOPER_GUIDE.md`, `BOARD_RELEASE_NOTES.md`, `FIRMWARE_BUG_REPORT.md` |

### Module Breakdown (inside `LimiExhibition/`)

#### Core Infrastructure

| File | Responsibility |
|------|---------------|
| `LimiExhibitionApp.swift` | App entry point (`@main`). Initializes language settings, BLE background scan, injects `BackgroundLogic` into SwiftUI environment. |
| `AppDelegate.swift` | Legacy UIKit delegate with empty stubs. Appears **unused** -- no `UIApplicationDelegateAdaptor` is wired in the SwiftUI app. |
| `AuthManager.swift` | Singleton token manager. Stores JWT + expiry in `UserDefaults`. Controls `@Published isAuthenticated` state that drives navigation. |
| `GlobalVariables.swift` | Global computed properties (`globalUserSpace`, `globalUserLocation`) backed by `UserDefaults`. |
| `OrientationLock.swift` | Programmatic orientation locking utility via `UIWindowScene`. |
| `ContentView.swift` | Legacy tab-based dev/testing UI (LED toggles + `MiniControllerView`). **Not** the main app root -- the real root is `SplashScreen`. |

#### API and Networking (`API/`)

| File | Responsibility |
|------|---------------|
| `ManagerAPI.swift` | Central URL constants (`APIConstants`, `AppURLs`). All API endpoints, external URLs, web configurator URLs. Base URL: `https://dev.api.limitless-lighting.co.uk/`. |
| `AuthResponseParsing.swift` | JWT extraction from API responses (`data.token` or `data.data.token` shapes). Also contains `AppleLoginAPI.exchange()` for Apple Sign-In backend handshake. |
| `WeatherData.swift` | Weather model with WMO weather code mapping, SF Symbol resolution, gradient theming per condition, hourly forecasts. Uses Open-Meteo response format. |
| `WeatherService.swift` | Open-Meteo API client (free, no key required). 10-minute in-memory cache. Singleton pattern with `async/await`. |

#### Authentication (`Auth Manager/`, `Login Screen/`)

| File | Responsibility |
|------|---------------|
| `Auth Manager/AuthManger.swift` | `GoogleAuthManager` class: Google Sign-In via GIDSignIn SDK, Apple Sign-In via `ASAuthorizationController`. Both POST identity tokens to backend for JWT exchange. Note: filename has a typo ("Manger" vs "Manager"). |
| `Auth Manager/TestingSignIn.swift` | Debug/testing sign-in UI for development. |
| `Login Screen/LoginView.swift` | Full login screen (~1392 lines): Email OTP flow (`send_otp` / `verify_otp`), Apple button, Google button, guest/installer paths. Contains a **separate** `AppleAuthManager` class distinct from `GoogleAuthManager`. |
| `Login Screen/SignIn.swift` | `SignInView` with social login buttons routing to the auth flows. |
| `Login Screen/Apple.swift` | `AppleLoginView` -- standalone SwiftUI wrapper for Sign in with Apple. |

#### Services (`Services/`)

| File | Responsibility |
|------|---------------|
| `Bluetooth/BluetoothManager.swift` | Central BLE manager (~1142 lines). Device discovery, connection, read/write on custom GATT characteristics (FF02/FF03 for data, FB01-FB05 for WiFi provisioning). Hub storage, background scanning, reconnect logic, device popup UI. **Largest and most complex single file in the project.** |
| `WebSocket/LightControllingSocket.swift` | Socket.IO client connecting to the backend with auth token. Emits `light_controll` events with acknowledgment callback. Real-time LED control channel. |

#### Common Utilities (`Common/`)

| File | Responsibility |
|------|---------------|
| `NetworkMonitor.swift` | `NWPathMonitor` wrapper exposing `@Published isConnected` for connectivity state. |
| `LanguageSettings.swift` | Runtime language switching via ObjC Bundle swizzling. Supports EN, AR, UR, ZH-Hans, ZH-Hant. Includes `LanguagePickerView` and `String.localized` extension. Posts `.appLanguageDidChange` notification. |

#### Design System (`Color/`)

| File | Responsibility |
|------|---------------|
| `Color.swift` | Comprehensive color palette (`AppTheme.Palette`) with 80+ semantic tokens. Hex-based `Color(hex:)` initializer. Extends `Color` with static convenience properties (`.appCanvasPrimary`, `.orbGlow1`, etc.). Defines the "Deep Space" dark theme. Also extends `UIColor` for UIKit interop. Neumorphic palette reduced to single `neuBase` alias into `NeuTheme`. |
| `NeumorphicSystem.swift` | **Limi Neumorphic Engine** -- single source of truth. `NeuTheme` enum (5 constants: `baseCanvas`, `baseSurface`, `shadowLight`, `shadowDark`, `accentEdge`). `NeuElevationModifier` ViewModifier with strict 3-level system: Level 1 (raised with dual shadows + specular edge + `.drawingGroup()`), Level -1 (recessed with inner shadow gradient stroke + `scaleEffect(0.98)`), Level 0 (flat base). View extensions: `.neuElevation(level:cornerRadius:)`, `.neuElevationCircle()`, `.neuElevationCapsule()`, `.applyLimiBackground()`. Legacy bridge preserves `.neuCard()`, `.neuCircle()`, `.neuCapsule()`, `.neuCarvedField()` API. |
| `LimiDesignSystem.swift` | Design tokens: `LimiRadius`, `LimiSpacing`, `LimiTypography`, `LimiMotion` (spring animations). Reusable components: `GlassCardStyle` modifier (internally rewired to `NeuElevationModifier` Level 1), `TapScaleEffect`, `LimiOrbView` (Neural Sphere AI orb -- cyan/violet glow with `neuralOrb` image asset), `LimiPrimaryButton` (emerald gradient inside Level 1/Level -1 toggle on press), `SecondaryButton`/`DangerButton`/`PillButton`, `LimiTextField` (Level -1 carved field), `LimiScreenHeader`, `FloatingInputBar`, `DeepSpaceBackground`, `AmbientParticlesView`, `LimiShimmerModifier`, `LimiAppearModifier`. |

#### Onboarding and First-Run (`Onboard/`, `Personalize/`, `Splash Screen Module/`, `GetStart/`)

| File | Responsibility |
|------|---------------|
| `Splash Screen Module/SplashScreen.swift` | Animated splash with routing logic: checks `storedLocation` -> `isAuthenticated` -> `hasCompletedOnboarding` to decide destination view. ~2.2s animated delay before transition. |
| `Onboard/OnboardingView.swift` | **AI Bubble Storyboard** -- 4-screen swipeable onboarding introducing the floating neural orb AI assistant. The neural orb (56pt) floats as an overlay above all pages and animates position: Screen 1 (20% top-left, "Meet Limi AI"), Screen 2 (45% right, "Chat Naturally"), Screen 3 (70% bottom-left, "Always Within Reach"), Screen 4 (enlarged 160pt centered, "Your AI, Always Ready" with instruction card + neumorphic CTA). Hides `FloatingAssistantManager` bubble during storyboard, shows it on completion. Exits to `SignInView`. |
| `Onboard/GlowOrbView.swift` | Decorative animated orb (multi-layer gradients, breathing animation). Used in other screens, not in the current onboarding. |
| `Onboard/ImageRotationManager.swift` | `ObservableObject` that rotates placeholder asset names on a timer. Legacy -- no longer used by onboarding. |
| `Personalize/Personalize.swift` | Multi-step preference collection flow: name -> use case -> goals -> Bluetooth. `OnboardingViewModel` persists to `UserDefaults` and posts preferences to `APIConstants.sendUserPreference`. |
| `GetStart/GetStart.swift` | Role selection screen (user type picker). |
| `GetStart/UserRoleManager.swift` | `ObservableObject` that persists selected user role. |

#### Home (`HomeView/`)

Well-structured MVVM module with clear separation:

| Path | Responsibility |
|------|---------------|
| `ViewModel/HomeViewModel.swift` | Home screen state management and business logic. |
| `Model/UserDataResponse.swift` | API response models + `UserDataManager` (fetches/saves user data) + `ImageCache` for profile images. |
| `Model/DeviceHome.swift` | Device model for home context display. |
| `Model/KeyboardHelper.swift` | Keyboard avoidance utility. |
| `Component/` (15+ files) | Reusable view components: `WeatherCardView`, `WeatherWidgetView`, `HubCardView`, `HubRowView`, `HubsListView`, `SearchBarView`, `ProfileEditView`, `EmptyStateView`, `BackgroundView`, `HeaderView`, `EnhancedBottomNavigationView`, `EnhancedFloatingButton`, `EnhancedTabBarButton`, `FloatingButtonView`, `SpacesListView`, `DemoHubsListView`, `WebView`, `HubCardContent`. |
| `Component/WeatherViewModel.swift` | Weather data formatting for home widget display. |
| `Moduler/` | Modular device management: `ModulesManager`, `ChannelSelectionView`, `ModulerScreen`, `DeviceModule`, `ConnectedDevice`. |
| `Services/DeviceServiceProtocol.swift` | Protocol abstraction for device API calls (the **only** protocol-based service abstraction in the project). |

#### AR and 3D (`ARSession/`, `Configurator/`, `RoomPlan/`, `2D RoomPlan/`)

| Path | Responsibility |
|------|---------------|
| `ARSession/` (18 files) | AR view containers (`ARViewContainer`), model placement, surface detection (`ARSurfaceDetuction`), snapshot capture (`ARSnapshotManager`), product grids/detail, `BackgroundLogic` (`@Observable` -- the only use of Swift 5.9 Observation macro), `ARModelStateManager`, 3D model listing. |
| `Configurator/LimiWebView.swift` | `WKWebView` wrapper embedding the Vercel-hosted configurator with mobile viewport fixes, JS console bridging, and optional LiDAR-gated navigation to AR portal. |
| `Configurator/LimiWebConfigurator.swift` | Extended web bridge (`LimiWebViewCon`): intercepts "Save" button clicks via injected JS, captures snap IDs, stores MAC-to-downloadId via `DeviceDownloadStore`, downloads USDZ files to `Documents/Configurator/`. |
| `Configurator/PortalWebView.swift` | AR portal hub: Presets tab (`DemoARView` carousel) vs Custom tab (embedded portal web -> fetch light config -> download USDZ -> `CustomView` AR). `LightConfigManager` handles API checks. |
| `Configurator/demoARView.swift` | Carousel of 3 AR cards with offline bundled model IDs (`mount1`-`mount3`) opening `CustomView`, or online API download. |
| `Configurator/DeviceDownloadStore.swift` | Thread-safe `UserDefaults`-backed persistence for MAC address to downloadId mapping. |
| `Configurator/DownloadedModelARView.swift` | Displays cached `.usdz` models via `QLPreviewController`. Reads from `Caches/` directory. |
| `RoomPlan/` (13 files) | Apple RoomPlan integration: `RoomCaptureController` (scan + save + upload), `RoomPlanContentView`, scan sync, USDZ analysis, model editor, file management. Includes experimental "new concept" views. |
| `2D RoomPlan/` (14 files) | Clean MVVM: 2D floor plan editor with `Project`/`Room`/`RoomObject`/`CatalogItem` models, `ProjectEditorViewModel`/`ProjectListViewModel`, and views for editing, catalog browsing, and 3D preview. |

#### IoT Device Management (`Demo/`, `Device Demo Module/`, `Add_Device/`, `HubHomeView/`, `ComandSend/`)

| Path | Responsibility |
|------|---------------|
| `Demo/LightScreen.swift` | Gradient "lights" demo screen with sample device names and Add Device sheet. |
| `Demo/LightCard.swift` | Individual light toggle card with on/off, optional AI animation, navigation to `PWM2LEDView`. |
| `Demo/DeviceSearchSheet.swift` | Simulated BLE discovery sheet that appends lights to the demo list. |
| `Demo/DemoAddDeviceView.swift` | Dummy Bluetooth add-device trigger for demo purposes. |
| `Device Demo Module/DemoScanDevicesView.swift` (~851 lines) | Full device onboarding: BLE scan + Bonjour (`_Limi1Ch._udp.`) discovery + ICMP ping verification. Contains `PingPoller`, `BLEDevice`, `BonjourServiceBrowser`. |
| `Device Demo Module/DemoAddDevicesView.swift` | Multi-device add flow UI. |
| `Device Demo Module/DemoAddingWifiView.swift` | WiFi credential entry for device provisioning. |
| `Device Demo Module/DemoWifiConnected.swift` | Success state after WiFi provisioning (`DemoConnectedWifiView`). |
| `Device Demo Module/WifiList.swift` | WiFi network list retrieved from BLE-connected device. |
| `Device Demo Module/SimplePing.swift` | Raw ICMP ping implementation for device reachability verification. |
| `Add_Device/` (7 files) | Production device pairing: BLE scan (`BLEScanView`), QR code scanning (`ScanQRCode`), step-by-step add device flow, BLE test harness. |
| `HubHomeView/` (14 files) | Hub control UI: `PWM2LEDView` (brightness/color temperature), `HubHomeView`, `MiniControllerView`, `RainbowSlider`, `CurvedSlider`, `CustomVerticalSlider`, `GroupingHub`, `DataRGBView`, `StoreHistory`, `AIButtonView`, `SmartHomeApp`, Socket.IO testing. |
| `ComandSend/CommanSend.swift` | Simple PWM command models (`HubSend`, `DeviceController`). Local-only, not networked. |

#### Hotel Module (`Hotel Module/`)

Standalone feature module for the hospitality use case:

| Path | Responsibility |
|------|---------------|
| `Hotel Home View/HotelHomeView.swift` | Hotel-specific home screen. |
| `Hotel Home View/SocketIOExample.swift` | Socket.IO integration example for hotel context. |
| `AI Views/` (5 files) | AI integrations (`AIMainView`), AI app store (`AIAppStoreView`), connections management (`AIConnectionsView`), new AI integration flow, shared components. |
| `HotelWLED/` (5 files) | WLED device control: `SSPDDiscoveryManager` (SSDP discovery), `WLEDDeviceController` (HTTP-based WLED API), `WLEDView`/`WLEDAPIManager`, `CCTLEDView` (color temperature), `SubDevicesView`, `HotelRoomDevices`. |
| `Profile/ProfileView.swift` | Profile management with settings, AI sheets, RoomPlan access, logout (clears auth + BLE + onboarding flags). |
| `Profile/NotificationView.swift` | Notification preferences with toggle cards. |
| `Profile/PrivacyPolicyView.swift` | Static privacy policy display. |
| `Requests/HotelRequestView.swift` | Hotel service request form. |
| `Requests/RequestSummary.swift` | Request summary display with main item cards. |
| `scheduling/SchedulingView.swift` | Lighting schedule management. `Schedule` is `ObservableObject` with `@Published` fields. Includes `ScheduleCard` and sample data. |
| `scheduling/SchdedulingSummary.swift` | Schedule summary view (note: filename typo "Schdeduling"). |

#### AI (`AI ChatBot/`, `AIHomeView/`)

| Path | Responsibility |
|------|---------------|
| `AI ChatBot/WebRTCVoiceClient.swift` | WebRTC client connecting to OpenAI Realtime API for voice-based AI interaction. |
| `AI ChatBot/VoiceChatBoot.swift` | Voice chat bootstrap/coordinator with `AudioManager` for mic/speaker handling. |
| `AI ChatBot/VoiceView.swift` | Voice interaction UI. |
| `AI ChatBot/OrbView.swift` | Visual feedback orb for AI assistant state. |
| `AI ChatBot/AnimationResponce.swift` | Animated UI for voice/chat responses. |
| `AI ChatBot/VisualEffectBlur.swift` | UIKit blur/vibrancy wrapper for SwiftUI. |
| `AI ChatBot/LocationManager.swift` | `CLLocationManager` wrapper providing location context to AI. |
| `AIHomeView/AIHomeView.swift` | AI-focused home screen variant. |

#### Floating AI Assistant (`FloatingAssistant/`)

The floating AI button is a **system-wide, always-on-top UIKit overlay** that lives in its own `UIWindow` above all SwiftUI content. It is the primary entry point for voice-based AI interaction.

| File | Responsibility |
|------|---------------|
| `FloatingAssistantManager.swift` | Singleton manager. Creates a `FloatingWindow` on app launch (via `setup()` called from AppDelegate). Owns the `WebRTCVoiceClient` instance. On bubble tap: toggles voice session (disconnected -> start, connected -> stop). Provides `.show()` / `.hide()` to control visibility (hidden during onboarding). Observes `WebRTCVoiceClient.$state` to update bubble active appearance. Also dispatches long-press menu actions via `NotificationCenter` (`connectDevice`, `deviceHelp`, `systemStatus`). |
| `FloatingWindow.swift` | Custom `UIWindow` at `windowLevel: .statusBar + 1`. Passes through touches that don't hit the bubble (via `hitTest` override returning nil for background taps). |
| `FloatingRootViewController.swift` | Hosts `AIBubbleView`. Manages position persistence (`UserDefaults`), long-press context menu (Connect Device, Device Help, System Status), and bubble active state proxy. |
| `AIBubbleView.swift` | The draggable floating button itself -- a `UIButton` subclass (56pt diameter). **Now displays the `neuralOrb` image asset** (Neural Sphere) instead of a blue gradient with waveform icon. Has `UIPanGestureRecognizer` for drag + edge-snapping, `UITapGestureRecognizer` for voice toggle, and `UILongPressGestureRecognizer` for context menu. Pulse animation layer (cyan glow) activates during voice session. |
| `ContextManager.swift` | Tracks current screen name + metadata. Provides `contextPayload()` for injecting screen context into AI voice session. SwiftUI `.trackScreen()` modifier updates context on `onAppear`. |

**What the AI button does currently:**

1. **Tap** -- Toggles a WebRTC voice session with OpenAI Realtime API. If disconnected, `WebRTCVoiceClient.start()` opens a real-time audio connection. If connected, `.stop()` ends the session. The bubble pulses with cyan glow during an active session.
2. **Drag** -- Can be dragged to any position on screen. Snaps to the nearest left/right edge with spring animation when released. Position persists across app launches via `UserDefaults`.
3. **Long-press** -- Opens a context menu with 3 actions: "Connect Device" (posts notification to trigger BLE pairing), "Device Help" (posts notification for help flow), "System Status" (posts notification for status view). Each action is handled by the main app via `NotificationCenter` observers.
4. **Screen context** -- `ContextManager` tracks which screen the user is on and injects this context into the AI voice session, so the AI assistant knows the user's current screen when answering questions.

#### Assets and Resources

| Path | Responsibility |
|------|---------------|
| `Assets.xcassets/` | ~240+ image sets, app icon, color sets. Includes `neuralOrb` (AI sphere image for floating button + orb views), `storyboard_bg_1` through `storyboard_bg_4` (dark ambient scenes for onboarding storyboard). |
| `Font/` (top-level) | Amenti (6 weights) and Poppins (13 weights) font families, registered in `Info.plist` under `UIAppFonts`. |
| `art.scnassets/` | SceneKit assets for AR scenes. |
| `living-room_2K.exr` | HDR environment map for AR scene lighting. |
| `wrapper.html` | HTML template for web view injection. |
| `Limi Localizations/` | Localization bundles for multi-language support. |
| `Preview Content/` | SwiftUI preview assets. |

---

## 3. Dependency and Integration Graph

### External Dependencies

#### Via CocoaPods

| Dependency | Version | Role |
|-----------|---------|------|
| `GoogleSignIn` | 9.0.0 | Google OAuth authentication |
| `AppAuth` | 2.0.0 | OAuth 2.0 / OpenID Connect (transitive) |
| `AppCheckCore` | 11.2.0 | Firebase App Check (transitive) |
| `GTMAppAuth` | 5.0.0 | Google Toolbox auth (transitive) |
| `GTMSessionFetcher` | 3.5.0 | HTTP session fetching (transitive) |
| `PromisesObjC` | 2.4.0 | Promises library (transitive) |
| `GoogleUtilities` | 8.1.0 | Google shared utilities (transitive) |

#### Via Swift Package Manager (Xcode-managed)

| Dependency | Role |
|-----------|------|
| `FLAnimatedImage` | Animated GIF rendering |
| `SDWebImageSwiftUI` | Async image loading with caching |
| `FocusEntity` | AR anchor/focus entity visualization |
| `WebRTC` | Real-time audio/video for AI voice client |
| `socket` (Socket.IO) | Real-time bidirectional communication for light control |
| `GoogleSignIn-iOS` | **Duplicate** of CocoaPods dependency (potential symbol conflict) |
| `SwiftLAME` | MP3 encoding (likely for audio transcription upload) |
| `AppAuth-iOS` | **Duplicate** of CocoaPods transitive dependency |

### Apple Frameworks Used

| Framework | Purpose |
|----------|---------|
| `SwiftUI` | Primary UI framework |
| `UIKit` | Bridged for `WKWebView`, `AVPlayerViewController`, `QLPreviewController`, `UIApplication` |
| `Foundation` | Core utilities |
| `CoreBluetooth` | BLE device communication |
| `ARKit` + `RealityKit` | Augmented reality experiences |
| `SceneKit` | 3D scene rendering (legacy AR assets) |
| `QuickLook` | USDZ model preview |
| `RoomPlan` | LiDAR-based room scanning |
| `CoreLocation` | User location for weather and context |
| `Network` | `NWPathMonitor` for connectivity |
| `AuthenticationServices` | Sign in with Apple |
| `AVFoundation` + `AVKit` | Video playback (splash animation) |
| `WebKit` | Embedded web views (configurator) |
| `SwiftData` | Imported but **no usage found** -- no `@Model` or `ModelContainer` |
| `Observation` | Swift 5.9 `@Observable` macro (used by `BackgroundLogic`) |
| `ObjectiveC` | Runtime bundle swizzling for localization |

### Coupling Assessment

#### Tightly Coupled Components

- **`BluetoothManager.shared`** -- Accessed directly from 10+ files across views, view models, and other services. No protocol abstraction exists. Every BLE consumer is coupled to the concrete singleton class.

- **`AuthManager.shared`** -- Global singleton referenced across the API layer, views, sockets, and web views. Token persistence in `UserDefaults` has no abstraction layer.

- **`APIConstants`** -- Hardcoded URL strings referenced directly throughout the codebase. `baseURL` and `secondaryBaseURL` are identical (`dev.api.limitless-lighting.co.uk`). No environment switching mechanism exists.

- **`Color` extensions** -- 80+ static color properties extended onto `Color`. Every view file in the project references these directly. Changes to the color system propagate everywhere.

#### Loosely Coupled Components

- **`WeatherService`** -- Clean singleton with `async/await` API. No dependencies on other app modules. Self-contained with its own model (`WeatherData`, `OpenMeteoResponse`).

- **`DeviceDownloadStore`** -- Thread-safe, self-contained persistence using a concurrent `DispatchQueue` with barrier writes. No external dependencies.

- **`2D RoomPlan` module** -- Clean MVVM with its own `Models/`, `ViewModels/`, `Views/`, `Services/`, and `Utils/` directories. Minimal coupling to the rest of the app.

- **`HomeView/Services/DeviceServiceProtocol.swift`** -- The **only** protocol-based service abstraction found in the project. Indicates awareness of the pattern but no widespread adoption.

### Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     View Layer                              │
│  HomeView, HotelModule, AR/Configurator, Login, Demo       │
└───────────────────────────┬─────────────────────────────────┘
                            │ references .shared singletons
┌───────────────────────────▼─────────────────────────────────┐
│                  Service Singletons                         │
│  AuthManager ◄──── LightControllingSocket (reads token)     │
│  BluetoothManager                                           │
│  WeatherService                                             │
│  NetworkMonitor                                             │
│  SharedDevice                                               │
│  DeviceDownloadStore                                        │
└───────────────────────────┬─────────────────────────────────┘
                            │ URLSession / Socket.IO / BLE
┌───────────────────────────▼─────────────────────────────────┐
│                  External Systems                           │
│  Backend API (dev.api.limitless-lighting.co.uk)             │
│  Open-Meteo (weather)                                       │
│  OpenAI Realtime (AI voice via WebRTC)                      │
│  Physical BLE Devices (Limi hubs)                           │
│  WLED Devices (HTTP on local network)                       │
│  Vercel Web Configurator (embedded WKWebView)               │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Data Flow and State Management

### Authentication Flow

```
User taps Google / Apple / Email OTP on LoginView
    │
    ▼
GoogleAuthManager.signInWithGoogle()  ──or──  signInWithApple()
    │                                          │
    ▼                                          ▼
POST /client/google/login              POST /client/apple/login
  (id_token + server_auth_code)          (identity_token + user)
    │                                          │
    ▼                                          ▼
Backend returns: { data: { token: "JWT" } }
    │
    ▼
AuthResponseParsing.appToken(from: data)  extracts JWT
    │
    ▼
AuthManager.shared.saveToken(jwt)
  → UserDefaults.set(token, forKey: "authToken")
  → UserDefaults.set(expiryTime, forKey: "authTokenExpiry")
  → self.isAuthenticated = true   (@Published → triggers UI)
    │
    ▼
SplashScreen observes isAuthenticated → navigates to HomeView
```

### Device Control Flow (BLE + Socket.IO)

```
User adjusts brightness/color slider in PWM2LEDView
    │
    ├──► BluetoothManager.shared.writeValue([header, payload])
    │       │
    │       ▼
    │    BLE Write to FF03 characteristic on connected device
    │       │
    │       ▼
    │    Device processes command, notifies on FF02
    │       │
    │       ▼
    │    BluetoothManager updates @Published properties
    │       │
    │       ▼
    │    SwiftUI view reacts to state change
    │
    └──► LightControllingSocket.emit("light_controll", payload)
            │
            ▼
         Socket.IO event → Backend processes → Acknowledgment
```

### Web Configurator → AR Flow

```
LimiWebViewCon loads Vercel configurator URL (with auth token)
    │
    ▼
User configures a light product in the web UI, taps "Save"
    │
    ▼
Injected JS intercepts click, extracts snap ID from <span> element
    │
    ▼
JS posts snapId via window.webkit.messageHandlers.buttonClicked
    │
    ▼
Native Coordinator receives snapId:
  1. Calls downloadUSDZUsingAPI(downloadId: snapId)
  2. Stores MAC → snapId mapping via DeviceDownloadStore
    │
    ▼
USDZ file downloaded to Documents/Configurator/{snapId}.usdz
    │
    ▼
fullScreenCover presents CustomView with AR experience
```

### Source of Truth Table

| Data | Storage | Access Pattern |
|------|---------|---------------|
| Auth token + expiry | `UserDefaults` | `AuthManager.shared.getToken()` |
| User role | `UserDefaults` | `AuthManager.shared.getRole()` |
| User space / location | `UserDefaults` via global computed properties | `globalUserSpace`, `globalUserLocation` |
| Onboarding completion | `@AppStorage` | `hasLaunchedBefore`, `hasCompletedOnboarding` |
| Connected BLE devices | In-memory on `BluetoothManager` + `UserDefaults` persistence | `BluetoothManager.shared.storedHubs` |
| Device-to-model mapping | `UserDefaults` via `DeviceDownloadStore` | `DeviceDownloadStore.shared.get(forMac:)` |
| 3D model files (USDZ) | `FileManager` (`Documents/Configurator/` and `Caches/`) | Direct file path construction |
| Room scans | `FileManager` via `RoominatorFileManager` | `RoominatorFileManager.shared` |
| Weather data | In-memory cache (600s TTL) | `WeatherService.shared.fetchWeather()` |
| Language preference | `UserDefaults` | `LanguageSettings.currentLanguage()` |
| Personalization prefs | `UserDefaults` via `OnboardingViewModel` | Direct `UserDefaults` key access |

### State Management Approach

The app uses **no centralized state management framework** (no Redux, TCA, or similar). State is distributed across these mechanisms:

1. **`ObservableObject` singletons** -- `AuthManager`, `BluetoothManager`, `WeatherService`, `NetworkMonitor`, `LightControllingSocket`, `SharedDevice`, `SelectedDevicesStorage`. These are the de facto "stores" and are the primary state holders.

2. **`@Observable` (Observation framework)** -- Used only for `BackgroundLogic` (AR session state) and `RoomCaptureController`. Represents a newer Swift 5.9 approach but is not widely adopted.

3. **`@AppStorage`** -- Used for onboarding flags (`hasLaunchedBefore`, `hasCompletedOnboarding`) and location storage.

4. **`@State` / `@StateObject`** -- Heavy use for local view state throughout all modules.

5. **`@EnvironmentObject` / `.environment()`** -- Sparingly used. `BackgroundLogic` is injected via `.environment()` from the app root.

6. **`UserDefaults`** -- The primary persistent store for all non-file data, including authentication tokens (not Keychain).

---

## 5. Execution Flow and Entry Points

### App Launch Sequence

```
1. @main struct YourApp: App
   ├── init()
   │   ├── LanguageSettings.applyRuntimeLanguage()
   │   │     → Swizzles Bundle.main to use selected language bundle
   │   └── BluetoothManager.shared.enableBackgroundScan()
   │         → Starts CoreBluetooth central manager in background mode
   │
   ├── body: WindowGroup
   │   └── SplashScreen()
   │       ├── .environment(bgLogic)         // BackgroundLogic @Observable
   │       ├── .environment(\.locale, ...)   // Dynamic locale from LanguageSettings
   │       ├── .environment(\.layoutDirection, ...) // RTL for AR/UR
   │       ├── .preferredColorScheme(.dark)  // Always dark mode
   │       └── .onReceive(.appLanguageDidChange) { languageRefreshID = UUID() }

2. SplashScreen (animated, ~2.2 second delay)
   ├── Animates logo + tagline + orbiting dot
   └── After 2.2s, evaluates destination:
       │
       ├── IF storedLocation.isEmpty
       │   └── → LocationStorageView (collect location first)
       │
       ├── ELSE IF authManager.isAuthenticated
       │   └── → HomeView (main app)
       │
       ├── ELSE IF !hasLaunchedBefore || !hasCompletedOnboarding
       │   └── → OnboardingView (5-page walkthrough → SignIn)
       │
       └── ELSE
           └── → GetStart (role selection → SignIn → Login)

3. Post-Authentication
   ├── Personalize flow (if first time: name, use case, goals, BLE)
   │   └── Posts preferences to APIConstants.sendUserPreference
   └── HomeView (primary app shell)
       ├── EnhancedBottomNavigationView (custom tab bar)
       ├── Weather widget (WeatherService → WeatherCardView)
       ├── Hub/device list (BluetoothManager → HubCardView)
       ├── AI orb floating button (→ AI ChatBot module)
       ├── Configurator / AR access (→ PortalWebView)
       └── Hotel module access (role-dependent)
```

### Background Modes (declared in Info.plist)

| Mode | Status | Purpose |
|------|--------|---------|
| `bluetooth-central` | **Active** | BLE scanning and connection in background. Used by `BluetoothManager.enableBackgroundScan()`. |
| `bluetooth-peripheral` | **Declared, unused** | BLE peripheral mode. No peripheral code found in the project. |
| `nearby-interaction` | **Declared, unused** | U1 chip nearby interaction. No `NISession` code found. |
| `voip` | **Likely active** | Keeps audio session alive for WebRTC AI voice calls. |

### Required Device Capabilities (Info.plist)

| Capability | Impact |
|-----------|--------|
| `arm64` | Excludes 32-bit devices (pre-iPhone 5s) |
| `metal` | Requires Metal GPU support |
| `gyroscope` | Required for AR motion tracking |
| `arkit` | **Limits to ARKit-capable devices** (iPhone 6s and later). This is a significant constraint -- users without ARKit devices cannot install the app from the App Store. |

### Additional Info.plist Configuration

- **Bundle display name**: "LIMI AI"
- **URL Scheme**: `com.googleusercontent.apps.687943495551-...` (Google OAuth callback)
- **ATS**: `NSAllowsArbitraryLoads = true` and `NSAllowsArbitraryLoadsInLocalNetworking = true`
- **Bonjour services**: `_wled._tcp.`, `_http._tcp.`, `_Limi1Ch._udp.`
- **Custom fonts**: 23 font files registered (Amenti + Poppins families)
- **Orientation**: Portrait only on iPhone, all orientations on iPad

---

## 6. Risk and Complexity Assessment

### High-Complexity Areas

#### `BluetoothManager.swift` (~1142 lines)

The single most complex file in the project. It handles:
- CoreBluetooth delegate callbacks (central + peripheral)
- Device discovery with filtering
- Connection lifecycle and reconnection
- Read/write on custom GATT characteristics (FF02/FF03 for data, FB01-FB05 for WiFi provisioning)
- Hub storage and persistence
- Background scanning with popup UI (`GlobalDevicePopup`, `HubFoundPopupView`)
- Shared device state (`SharedDevice`, `SelectedDevicesStorage`)

Any BLE-related feature change requires understanding this entire monolith. The file mixes UI components, data models, and service logic in a single compilation unit.

#### `LoginView.swift` (~1392 lines)

Contains multiple complete flows in a single file:
- Email + OTP verification flow (`send_otp` / `verify_otp`)
- Apple Sign-In flow (with its own `AppleAuthManager` class)
- Google Sign-In integration
- Guest/installer login paths
- Full UI with animations, error handling, and navigation

The presence of a second `AppleAuthManager` class (distinct from `GoogleAuthManager` in `AuthManger.swift`) creates ambiguity about the canonical Apple sign-in implementation.

#### Web-to-Native Bridge (`LimiWebConfigurator.swift`)

Injects ~80 lines of JavaScript into the WKWebView to:
- Auto-tag "Save" buttons without IDs
- Intercept all button clicks via event delegation
- Extract snap IDs from `<span>` child elements
- Suppress `ReferenceError` for global `id` variable
- Bridge snap IDs to native via `window.webkit.messageHandlers`

This JS relies on the DOM structure of the Vercel-hosted configurator. **Any web-side UI change can silently break the native download flow** with no compile-time or runtime warning until a user encounters it.

#### Dual Auth Managers

Two separate classes handle Apple Sign-In:
- `GoogleAuthManager` (in `Auth Manager/AuthManger.swift`) -- handles both Google **and** Apple auth via `ASAuthorizationController`
- `AppleAuthManager` (in `Login Screen/LoginView.swift`) -- a separate Apple auth implementation

Both ultimately call `AppleLoginAPI.exchange()` but take different code paths to get there. This creates confusion about which is the canonical Apple sign-in handler and risks divergent behavior.

### Security Concerns

| Concern | Severity | Details |
|---------|----------|---------|
| Auth token in UserDefaults | **High** | JWT stored in `UserDefaults`, not Keychain. A commented-out Keychain implementation exists (`AuthManager.swift` lines 97-191) but is not active. `UserDefaults` is not encrypted and is accessible via unencrypted device backups. |
| GEMINI_API_KEY in Info.plist | **High** | API key `AIzaSyAdCUDJGu673rS7QOki9CuaEOrfBtbOInU` is hardcoded in `Info.plist`, committed to source control, and embedded in the app binary. Should be moved to a server-side proxy or at minimum to a build configuration excluded from VCS. |
| ATS disabled | **Medium** | `NSAllowsArbitraryLoads = true` disables App Transport Security entirely, allowing all HTTP (non-TLS) connections. Required for local WLED device communication but overly broad. |
| Token expiry duration | **Medium** | Default expiry passed to `saveToken()` is 600,000 seconds (~6.9 days). This is unusually long for a mobile session token. |
| Google OAuth Client ID | **Low** | Client ID visible in URL scheme registration. This is standard practice for mobile OAuth but should be noted. |

### Potential Bottlenecks

#### No Offline Queue for API Calls
Network requests fail silently or show error UI. There is no retry/queue mechanism for intermittent connectivity, which is a common scenario in IoT environments where devices may be in areas with poor WiFi. The `NetworkMonitor` detects connectivity state but does not drive any retry logic.

#### Socket.IO Token Capture at Init
`LightControllingSocket` reads the auth token **once** during initialization via `AuthManager.shared.getToken()`. If the user logs in after socket creation, or if the token refreshes, the socket continues using the stale/empty token until the entire object is recreated.

#### USDZ Storage Path Mismatch
`ARCardView` (in `demoARView.swift`) downloads USDZ files to `Documents/Configurator/{id}.usdz`, while `DownloadedModelARView` reads from `Caches/{id}.usdz`. These are **different directories** and will cause "file not found" errors when navigating between these flows.

#### No Unified Image/Asset Caching
Beyond the simple `ImageCache` class in `UserDataResponse.swift` (an `NSCache`-based in-memory cache), there is no unified caching strategy. `SDWebImageSwiftUI` is included as an SPM dependency but its adoption across views is unclear.

### Inconsistencies and Technical Debt

| Issue | Impact |
|-------|--------|
| **Duplicate dependency declarations** | `GoogleSignIn` and `AppAuth` appear in both CocoaPods and SPM. This can cause duplicate symbol linker errors or unexpected behavior. |
| **Unused `AppDelegate.swift`** | File exists with empty lifecycle stubs but is not wired to the SwiftUI app via `UIApplicationDelegateAdaptor`. Dead code. |
| **File naming typos** | `AuthManger.swift` (should be "Manager"), `CommanSend.swift` (should be "CommandSend"), `SchdedulingSummary.swift` (should be "Scheduling"), `ARSurfaceDetuction.swift` (should be "Detection"). |
| **Significant commented-out code** | `AuthManager.swift` has a 95-line commented Keychain implementation. `demoARView.swift` has commented online mode. `LimiExhibitionApp.swift` has a commented `StartView`. |
| **Mixed state paradigms** | Some classes use `@Observable` (Observation), others use `ObservableObject` (Combine). `RoomCaptureController` uses **both simultaneously**. While functional, this is confusing for contributors. |
| **Global mutable state** | `globalUserSpace` and `globalUserLocation` are global computed properties backed by `UserDefaults`. Any code anywhere can read/write them without going through a service layer, making data flow hard to trace. |
| **SwiftData imported but unused** | `SwiftData` is imported in `LimiExhibitionApp.swift` but no `@Model`, `ModelContainer`, or `ModelContext` usage exists anywhere in the project. |

### Areas of Risk for Future Modifications

#### Adding a New Auth Provider
Requires understanding and modifying at least 3 files:
- `GoogleAuthManager` (in `Auth Manager/AuthManger.swift`)
- `AppleAuthManager` (in `Login Screen/LoginView.swift`)
- `AuthResponseParsing.swift`
- Plus the `AuthManager` token persistence flow

No protocol abstraction (`AuthProviderProtocol` or similar) exists to standardize provider implementations.

#### Changing the API Base URL / Environment
`APIConstants.baseURL` and `secondaryBaseURL` are identical hardcoded strings pointing to `dev.api.limitless-lighting.co.uk`. There is no build configuration, scheme switching, or environment variable mechanism. Moving to staging or production requires editing source code.

#### Refactoring BluetoothManager
**Extremely high risk.** The 1142-line singleton is directly referenced across the entire application. No protocol abstraction means every consumer is tightly coupled to the concrete class. Any refactoring (splitting responsibilities, adding protocol abstraction, changing the API surface) ripples through dozens of files.

#### Web Configurator Updates
The JavaScript injection in `LimiWebConfigurator.swift` is inherently fragile. It depends on:
- The web configurator having `<button>` elements with specific structure
- A `<span>` child carrying the model ID
- The "Save" button being identifiable by text content

Any DOM restructuring on the Vercel-hosted site silently breaks the native snap ID capture and USDZ download pipeline.

#### Localization Expansion
The runtime bundle swizzling approach (`LanguageSettings.applyRuntimeLanguage()`) works by patching `Bundle.main` at the ObjC runtime level. While effective, this is a workaround for SwiftUI's native localization system and requires careful integration testing when adding new languages or updating to new SwiftUI versions.

---

## Appendix: Key Singleton Registry

| Singleton | Class | File |
|----------|-------|------|
| `AuthManager.shared` | `AuthManager: ObservableObject` | `LimiExhibition/AuthManager.swift` |
| `BluetoothManager.shared` | `BluetoothManager: ObservableObject` | `LimiExhibition/Services/Bluetooth/BluetoothManager.swift` |
| `WeatherService.shared` | `WeatherService: ObservableObject` | `LimiExhibition/API/WeatherService.swift` |
| `SharedDevice.shared` | `SharedDevice: ObservableObject` | `LimiExhibition/Services/Bluetooth/BluetoothManager.swift` |
| `SelectedDevicesStorage.shared` | `SelectedDevicesStorage: ObservableObject` | `LimiExhibition/Services/Bluetooth/BluetoothManager.swift` |
| `DeviceDownloadStore.shared` | `DeviceDownloadStore` | `LimiExhibition/Configurator/DeviceDownloadStore.swift` |
| `RoominatorFileManager.shared` | `RoominatorFileManager` | `LimiExhibition/RoomPlan/FileManager.swift` |

## Appendix: ObservableObject / Observable Registry

| Class | Pattern | File |
|-------|---------|------|
| `BackgroundLogic` | `@Observable` | `ARSession/BackgroundLogic.swift` |
| `RoomCaptureController` | `@Observable` + `ObservableObject` | `RoomPlan/RoomCaptureController.swift` |
| `AuthManager` | `ObservableObject` | `AuthManager.swift` |
| `BluetoothManager` | `ObservableObject` | `Services/Bluetooth/BluetoothManager.swift` |
| `GoogleAuthManager` | `ObservableObject` | `Auth Manager/AuthManger.swift` |
| `HomeViewModel` | `ObservableObject` | `HomeView/ViewModel/HomeViewModel.swift` |
| `WeatherViewModel` | `ObservableObject` | `HomeView/Component/WeatherViewModel.swift` |
| `UserDataManager` | `ObservableObject` | `HomeView/Model/UserDataResponse.swift` |
| `ModulesManager` | `ObservableObject` | `HomeView/Moduler/ModulesManager.swift` |
| `OnboardingViewModel` | `ObservableObject` | `Personalize/Personalize.swift` |
| `UserRoleManager` | `ObservableObject` | `GetStart/UserRoleManager.swift` |
| `LocationManager` | `ObservableObject` | `AI ChatBot/LocationManager.swift` |
| `LocationObserver` | `ObservableObject` | `Location Module/LocationHelper.swift` |
| `LocationStorageManager` | `ObservableObject` | `Location Module/LocationStorageView.swift` |
| `WebRTCVoiceClient` | `ObservableObject` | `AI ChatBot/WebRTCVoiceClient.swift` |
| `AudioManager` | `ObservableObject` | `AI ChatBot/VoiceChatBoot.swift` |
| `NetworkMonitor` | `ObservableObject` | `Common/NetworkMonitor.swift` |
| `WeatherService` | `ObservableObject` | `API/WeatherService.swift` |
| `LightControllingSocket` | `ObservableObject` | `Services/WebSocket/LightControllingSocket.swift` |
| `ImageRotationManager` | `ObservableObject` | `Onboard/ImageRotationManager.swift` |
| `ImageRotationCeiling` | `ObservableObject` | `Onboard/OnboardingView.swift` |
| `LEDStateManager` | `ObservableObject` | `HubHomeView/MiniControllerView.swift` |
| `StoreHistory` | `ObservableObject` | `HubHomeView/StoreHistory.swift` |
| `Schedule` | `ObservableObject` | `Hotel Module/scheduling/SchedulingView.swift` |
| `AppleAuthManager` | `ObservableObject` | `Login Screen/LoginView.swift` |
| `BonjourServiceBrowser` | `ObservableObject` | `Device Demo Module/DemoScanDevicesView.swift` |
| `WLEDAPIManager` | `ObservableObject` | `Hotel Module/HotelWLED/WLEDView.swift` |
| `SSPDDiscoveryManager` | `ObservableObject` | `Hotel Module/HotelWLED/WLEDController.swift` |
| `WLEDDeviceController` | `ObservableObject` | `Hotel Module/HotelWLED/WLEDController.swift` |
| `ARViewHolder` | `ObservableObject` | `ARSession/ARViewContainer.swift` |
| `ARModelStateManager` | `ObservableObject` | `ARSession/ARModelStateManager.swift` |
| `ProjectListViewModel` | `ObservableObject` | `2D RoomPlan/ViewModels/ProjectListViewModel.swift` |
| `ProjectEditorViewModel` | `ObservableObject` | `2D RoomPlan/ViewModels/ProjectEditorViewModel.swift` |
| `KeyboardHelper` | `ObservableObject` | `HomeView/Model/KeyboardHelper.swift` |
| `SharedDevice` | `ObservableObject` | `Services/Bluetooth/BluetoothManager.swift` |
| `SelectedDevicesStorage` | `ObservableObject` | `Services/Bluetooth/BluetoothManager.swift` |

---

## Appendix: Design System Migration Changelog

### Neumorphic Engine (implemented)

| Change | Files Modified |
|--------|---------------|
| Created `NeuTheme` enum with 5 strict constants (baseCanvas, baseSurface, shadowLight, shadowDark, accentEdge) | `NeumorphicSystem.swift` (full rewrite) |
| Created `NeuElevationModifier` with 3-level system (Level 1 raised, Level -1 recessed, Level 0 base) | `NeumorphicSystem.swift` |
| Added `.neuElevation(level:cornerRadius:)`, `.neuElevationCircle()`, `.neuElevationCapsule()`, `.applyLimiBackground()` | `NeumorphicSystem.swift` |
| Legacy bridge: `.neuCard()`, `.neuCircle()`, `.neuCapsule()`, `.neuCarvedField()` delegate to level-based system | `NeumorphicSystem.swift` |
| Removed 9 old neumorphic palette tokens, kept single `neuBase` alias | `Color.swift` |
| `GlassCardStyle` body rewired to `NeuElevationModifier(level: 1)` -- all 24+ `.glassCard()` call sites now render as neumorphic | `LimiDesignSystem.swift` |
| `LimiPrimaryButton` uses `DragGesture` press state toggle: Level 1 (default) to Level -1 (pressed) | `LimiDesignSystem.swift` |
| `LimiTextField` uses Level -1 carved field via legacy bridge | `LimiDesignSystem.swift` |
| `LimiBackButton` uses Level 1 raised via legacy bridge | `LimiDesignSystem.swift` |
| `LimiIconButton` uses Level 1/Level -1 circle toggle via legacy bridge | `LimiDesignSystem.swift` |

### Neural Sphere Visual Identity (implemented)

| Change | Files Modified |
|--------|---------------|
| `LimiOrbView` redesigned: cyan/violet color palette, `neuralOrb` image asset, rotating ring, pulsing specular highlight | `LimiDesignSystem.swift` |
| `AIBubbleView` (floating draggable button) replaced blue gradient + waveform icon with `neuralOrb` image + cyan glow | `FloatingAssistant/AIBubbleView.swift` |
| Hotel `centerOrbView` replaced gray `OrbView` with `neuralOrb` image + cyan/violet glow | `Hotel Module/HotelHomeView.swift` |
| HomeView `fabButton` replaced emerald gradient + "+" icon with `neuralOrb` image | `HomeView/Component/EnhancedBottomNavigationView.swift` |
| Added `neuralOrb.imageset` to asset catalog | `Assets.xcassets/neuralOrb.imageset/` |

### AI Storyboard Onboarding (implemented)

| Change | Files Modified |
|--------|---------------|
| Replaced 5-page photo onboarding with 4-screen AI bubble storyboard | `Onboard/OnboardingView.swift` (full rewrite) |
| Neural orb floats as overlay, animates position per page (20% top-left, 45% right, 70% bottom-left, centered enlarged) | `Onboard/OnboardingView.swift` |
| Each page has neumorphic speech card with headline + detail text about Limi AI capabilities | `Onboard/OnboardingView.swift` |
| Final screen: enlarged orb + instruction card (tap/drag/long-press/hide) + neumorphic "Continue" CTA | `Onboard/OnboardingView.swift` |
| Floating AI bubble hidden during onboarding (`FloatingAssistantManager.shared.hide()`) | `Onboard/OnboardingView.swift` |
| Added 4 AI-generated dark ambient background images | `Assets.xcassets/storyboard_bg_1-4.imageset/` |
