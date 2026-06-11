# AddDevice Cleanup Audit

## Active flow

Current active add-device chain:

1. `LimiExhibition/Add_Device/AddDeviceView.swift`
2. `LimiExhibition/Add_Device/AddDevicesView.swift`
3. `LimiExhibition/Add_Device/BLEStarterView.swift`
4. `LimiExhibition/Add_Device/BLEScanView.swift`
5. `LimiExhibition/Add_Device/BLETestView.swift`

Known entry points referencing this flow:

- `LimiExhibition/HomeView/Component/SpacesListView.swift` -> `AddDeviceView()`
- `LimiExhibition/PULoginView.swift` -> `AddDeviceView()`
- `LimiExhibition/Hotel Module/Hotel Home View/HotelHomeView.swift` -> `BLEStarterView()`

## File classification

### Keep and continue refactoring

- `LimiExhibition/Add_Device/AddDeviceView.swift`
  - Active shell for add-device flow.
  - Already has `AddDeviceViewModel`.

- `LimiExhibition/Add_Device/AddDeviceViewModel.swift`
  - Active ViewModel for shell routing.
  - Keep.

- `LimiExhibition/Add_Device/AddDevicesView.swift`
  - Active selection UI for connection method.
  - Mostly pure UI; low urgency.

- `LimiExhibition/Add_Device/BLEStarterView.swift`
  - Active wrapper around scan flow.
  - Thin, but still active.

- `LimiExhibition/Add_Device/BLEScanView.swift`
  - Active BLE discovery screen.
  - Already partially moved to MVVM.

- `LimiExhibition/Add_Device/BLEScanViewModel.swift`
  - Active ViewModel for scan screen.
  - Keep.

- `LimiExhibition/Add_Device/AddDeviceBluetoothAdapter.swift`
  - Active adapter abstraction around BluetoothManager.
  - Keep.

### Keep, but refactor / review manually

- `LimiExhibition/Add_Device/BLETestView.swift`
  - Actively reachable from `BLEScanView`.
  - Looks like an engineering/debug control panel rather than polished production UI.
  - Strong candidate to either:
    - rename to something intentional like `BLEControlTestView`
    - move to a debug/demo module
    - replace with a real provisioning/control screen later

### Likely unused

- `LimiExhibition/Add_Device/ScanQRCode.swift`
  - `ScanQRCodeView` has no live references found.
  - Very minimal placeholder screen.
  - Strong cleanup candidate after confirmation.

## Architecture observations

- `AddDevicesView.swift` is already close to view-only responsibility.
- `AddDeviceView.swift` had flow-state coupling and is now partially cleaned.
- `BLEScanView.swift` had mixed scan state and Bluetooth reactions; now partially moved into `BLEScanViewModel`.
- `BLETestView.swift` still directly depends on `BluetoothManager.shared` and sends raw BLE command strings from the view.
  - This is the main MVVM violation left in this module.

## Safe removal candidates

### Low risk after confirmation

- `LimiExhibition/Add_Device/ScanQRCode.swift`
  - No inbound references found.
  - Placeholder-only implementation.

## Not safe to remove yet

- `LimiExhibition/Add_Device/BLETestView.swift`
  - Still referenced by `BLEScanView`.

- `LimiExhibition/Add_Device/BLEStarterView.swift`
  - Still referenced by `AddDeviceView` and `HotelHomeView`.

- `LimiExhibition/Add_Device/AddDeviceView.swift`
  - Still referenced by `SpacesListView` and `PULoginView`.

## Recommended next step

1. Refactor `BLETestView` into MVVM or move it behind a clearly debug-only boundary.
2. Verify whether QR flow is actually planned.
3. If not planned, remove:
   - `LimiExhibition/Add_Device/ScanQRCode.swift`
4. Rebuild and smoke-test add-device flow from:
   - Home
   - Production-user flow
   - Hotel shortcut path
