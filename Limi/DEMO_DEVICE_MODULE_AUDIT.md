# Demo and Device Demo Module Audit

## Objective
- Verify whether `LimiExhibition/Demo` and `LimiExhibition/Device Demo Module` still contain removable legacy code.
- Classify files for cleanup without breaking active navigation or device flows.

## Folders Audited
- `Limi/LimiExhibition/Demo`
- `Limi/LimiExhibition/Device Demo Module`

## Files Found

### Demo
- `Limi/LimiExhibition/Demo/DemoAddDeviceView.swift`
- `Limi/LimiExhibition/Demo/DeviceSearchSheet.swift`
- `Limi/LimiExhibition/Demo/LightCard.swift`
- `Limi/LimiExhibition/Demo/LightScreen.swift`

### Device Demo Module
- `Limi/LimiExhibition/Device Demo Module/DemoAddingWifiView.swift`
- `Limi/LimiExhibition/Device Demo Module/DemoConnectedWifiView.swift`
- `Limi/LimiExhibition/Device Demo Module/DemoScanDevicesView.swift`
- `Limi/LimiExhibition/Device Demo Module/SimplePing.swift`
- `Limi/LimiExhibition/Device Demo Module/WifiList.swift`

## Reference Findings

### Demo Folder
- `LightScreen.swift` uses `LightCard` and `DeviceSearchSheet`.
- `HomeView/Component/HubCardView.swift` navigates to `LightScreen(title: hub.name)`.
- `HomeView/Component/EnhancedFloatingButton.swift` presents `DemoAddDeviceView(bluetoothManager: bluetoothManager)`.

### Device Demo Module
- `DemoAddingWifiView.swift` presents `DemoConnectedWifiView`.
- `WifiList.swift` presents both `DemoAddingWifiView` and `DemoConnectedWifiView`.
- `DemoScanDevicesView.swift` uses `SimplePing` and presents `WifiList`.
- `HomeView/Component/EnhancedFloatingButton.swift` presents `DemoScanDevicesView()`.
- `HomeView/Moduler/ConnectedDevice.swift` presents `DemoScanDevicesView()`.
- `Personalize/Personalize.swift` presents `DemoScanDevicesView()`.
- `HomeView/HomeView.swift` presents `WifiList(...)`.

## Classification

| File | Classification | Reason | Risk |
|---|---|---|---|
| `Limi/LimiExhibition/Demo/LightScreen.swift` | Keep | Reached from `HubCardView.swift` | High |
| `Limi/LimiExhibition/Demo/LightCard.swift` | Keep | Used by `LightScreen.swift` | Medium |
| `Limi/LimiExhibition/Demo/DeviceSearchSheet.swift` | Keep | Used by `LightScreen.swift` | Medium |
| `Limi/LimiExhibition/Demo/DemoAddDeviceView.swift` | Review manually | Directly referenced by `EnhancedFloatingButton.swift`; still active but may be replaceable later | Medium |
| `Limi/LimiExhibition/Device Demo Module/DemoScanDevicesView.swift` | Keep, refactor later | Active cross-feature entry point for BLE/Wi-Fi device setup | High |
| `Limi/LimiExhibition/Device Demo Module/WifiList.swift` | Keep | Active sheet from both `HomeView.swift` and `DemoScanDevicesView.swift` | High |
| `Limi/LimiExhibition/Device Demo Module/DemoAddingWifiView.swift` | Keep | Active child flow from `WifiList.swift` | Medium |
| `Limi/LimiExhibition/Device Demo Module/DemoConnectedWifiView.swift` | Keep | Active child flow from `WifiList.swift` and `DemoAddingWifiView.swift` | Medium |
| `Limi/LimiExhibition/Device Demo Module/SimplePing.swift` | Keep | Required by `DemoScanDevicesView.swift` ping flow | Medium |

## Problems Found
- Folder names still imply temporary or demo-only code, but several files are part of active production navigation.
- Active setup flow is spread across `HomeView`, `Personalize`, `ConnectedDevice`, `Demo`, and `Device Demo Module`.
- The names `Demo` and `Device Demo Module` are now misleading and hide real production dependencies.

## Proposed Changes
- Do not delete any file from these two folders yet.
- Treat these folders as active-but-misnamed modules.
- In a later refactor phase, move active files into a real feature path, likely under:
  - `Features/AddDevice`
  - or `Features/ConnectedDevices`
- Refactor `DemoScanDevicesView.swift` first if cleanup is needed later, because it is the main dependency hub.

## Safe Removal Status
- No safe removals identified in this audit pass.

## Validation Checklist
- Confirm cross-feature references before any deletion.
- Build after each future move or cleanup batch.
- Smoke test:
  - `HubCardView -> LightScreen`
  - `EnhancedFloatingButton -> DemoAddDeviceView`
  - `EnhancedFloatingButton -> DemoScanDevicesView`
  - `HomeView -> WifiList`
  - `Personalize -> DemoScanDevicesView`

## Recommendation
- Freeze cleanup for `Demo` and `Device Demo Module` for now.
- Rename and relocate these files later during feature consolidation instead of deleting them.
