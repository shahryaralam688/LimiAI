# Firmware Bug Report - FF02 Handshake Issue

## Bug Description
The FF02 characteristic handshake is being overwritten by a second `setValue` call, causing iOS to receive incorrect data.

## Location in Firmware
File: Your BLE initialization code (where FF02 characteristic is set up)
Lines: Around the `initBLE()` function where FF02 is configured

## Current Code (Buggy)
```cpp
NimBLECharacteristic *pLedCodeChar = pPWMService->createCharacteristic("FF02", NIMBLE_PROPERTY::READ);

// Send the exact 2-byte array the iOS app requires to unlock the UI
// Byte 0: 91 (Normal Mode)
// Byte 1: 0 (Flags/Reserved)
byte appHandshake[2] = {91, 0}; 
pLedCodeChar->setValue(appHandshake, 2);  // ✓ Sets {91, 0} - CORRECT!

// Tell the app what mode the light is currently in
byte status = (sets[0].mode == 1) ? 0x01 : 0x02; // 0x01=CCT, 0x02=RGB
pLedCodeChar->setValue(&status, 1);       // ✗ OVERWRITES with {1} or {2} - BUG!
```

## The Problem
The iOS app reads FF02 expecting `{91, 0}` (Normal mode + flags), but the second `setValue` call overwrites it with either `{0x01}` or `{0x02}` depending on the light mode.

When iOS reads FF02, it checks: `lastReceivedBytes[0] == 91` to determine if the device is in "Normal Mode"
- If the value is `{0x01}` or `{0x02}`, the check fails
- The app may think the device is in an invalid state

## Impact
This may cause the iOS app to:
1. Fail to recognize the device mode correctly
2. Potentially disconnect or show errors
3. Not proceed with the expected flow

## Fix
Replace the two separate `setValue` calls with a single combined call:

```cpp
NimBLECharacteristic *pLedCodeChar = pPWMService->createCharacteristic("FF02", NIMBLE_PROPERTY::READ);

// Combined handshake: {91 (Normal Mode), mode_status}
byte appHandshake[2] = {91, (sets[0].mode == 1) ? 0x01 : 0x02}; 
pLedCodeChar->setValue(appHandshake, 2);
```

## What the Fix Does
- Byte 0: Always `91` (indicates Normal mode to iOS)
- Byte 1: `0x01` for CCT mode or `0x02` for RGB mode

This matches what the iOS app expects to receive on FF02.

## Additional Note: WiFi List Format
Current WiFi list format in firmware is CSV: `Network1,Network2,Network3`

This works with iOS fallback parser, but for better compatibility, consider using JSON format:
```cpp
String wifiListPayload = "[";
for (int i = 0; i < numNetworksFound; i++) {  
    if (i > 0) wifiListPayload += ",";
    wifiListPayload += "\"" + wifiList[i] + "\"";  // Quote each SSID
}
wifiListPayload += "]";
pChar->setValue((uint8_t*)wifiListPayload.c_str(), wifiListPayload.length());
```
Output: `["Network1","Network2","Network3"]`

## iOS UUID Reference
For your reference, here are all the UUIDs the iOS app uses:

| Service | Characteristic | Purpose | iOS Expects |
|---------|---------------|---------|-------------|
| FB01 | FB02 | Write SSID | Write |
| FB01 | FB03 | Write Password | Write |
| FB01 | FB04 | Read WiFi List | Read |
| FB01 | FB05 | ACK/Notify | Read + Notify |
| FF01 | FF02 | Read Status | Read |
| FF01 | FF03 | Write Commands | Write |

All UUIDs match correctly between firmware and iOS. The only issue is the FF02 value being overwritten.

---
Generated: 2024
For: Hardware/Firmware Team
