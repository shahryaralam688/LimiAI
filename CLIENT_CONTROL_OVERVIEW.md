# Limi Mobile App — Device Control Overview

**Document for client review**  
**App:** Limi iOS App  
**Reference:** APP_CONTROL_PROTOCOL.md (firmware control specification)

---

## 1. Summary

The Limi app controls lights through **three communication paths** (called **doors** in the firmware spec):

| Priority | Path | When it is used |
|----------|------|-----------------|
| 1 | **MQTT (Cloud)** | Device is on Wi‑Fi and connected to the cloud |
| 2 | **LAN WebSocket** | Device is on Wi‑Fi but cloud (MQTT) is not available |
| 3 | **Bluetooth (BLE)** | Device is not on Wi‑Fi, or Wi‑Fi/cloud is not usable |

In normal use, the app picks the correct path **automatically** based on live device status.  
For testing, the app also includes a **manual Control path** option.

---

## 2. How Control Works (Simple Flow)

```
User opens Connected Devices
        ↓
User taps a device
        ↓
Control screen opens (brightness, color, power)
        ↓
App checks device status (Wi‑Fi, cloud, Bluetooth)
        ↓
App sends command on the correct path
        ↓
Light updates on the device
```

All light commands (on/off, brightness, warm/cool, RGB color, patterns) go through one unified system inside the app called **LimiTransport**.

---

## 3. Alignment with the Firmware Protocol

The mobile app follows the main rules from **APP_CONTROL_PROTOCOL.md**:

### ✅ Implemented as specified

| Feature | Status |
|---------|--------|
| Three-door priority (MQTT → WebSocket → BLE) | ✅ Done |
| Same JSON command format for MQTT and WebSocket | ✅ Done |
| CCT, RGB, power off, and pattern commands | ✅ Done |
| LAN WebSocket at `ws://<device-ip>/ws` | ✅ Done |
| Reject WebSocket when MQTT is active (HTTP 503) | ✅ Done |
| No WebSocket retry after 503 | ✅ Done |
| Slider throttling (latest value every ~40ms + final value on release) | ✅ Done |
| Local device discovery via mDNS (`_Limi1Ch._udp`) | ✅ Done |
| TXT fields: deviceId, channelCount, channelTypes | ✅ Done |
| BLE light commands on characteristic FF03 | ✅ Done |
| BLE Wi‑Fi setup: SSID (FB02) then password (FB03) | ✅ Done |
| Device reset only via MQTT (separate from normal commands) | ✅ Done |
| Wi‑Fi credentials are not cleared when MQTT is down | ✅ Done |

### ⚠️ Important architecture note (for client)

The app does **not** connect directly to an MQTT broker on the phone.

Instead:

```
Mobile App  →  Socket.IO backend  →  MQTT broker  →  Device
```

This matches the current backend design. The app sends the **same JSON payload** defined in the protocol; the backend forwards it to the device MQTT topic.

Device online/cloud status is received from the backend via Socket.IO (`device_status`), not by subscribing to MQTT topics directly on the phone.

---

## 4. Command Format (What the App Sends)

All commands use this structure:

```json
{
  "deviceId": "B8F862E0A604",
  "command": { }
}
```

### Examples

**CCT (warm/cool white):**
```json
{
  "deviceId": "B8F862E0A604",
  "command": {
    "channel": 1,
    "brightness": 75,
    "ww": 100,
    "cw": 0
  }
}
```

**RGB:**
```json
{
  "deviceId": "B8F862E0A604",
  "command": {
    "channel": 1,
    "brightness": 80,
    "red": 255,
    "green": 0,
    "blue": 40
  }
}
```

**Power off:**
```json
{
  "deviceId": "B8F862E0A604",
  "command": {
    "channel": 1,
    "state": "off"
  }
}
```

---

## 5. App Features for Testing & Demo

### Connected Devices screen

- Lists devices found on the local network (mDNS/Bonjour)
- Shows online/offline status
- **Control path** picker (for testing):
  - Automatic (firmware) — recommended for normal use
  - MQTT (cloud)
  - LAN WebSocket
  - BLE (Bluetooth)

### Device control screen

- Power on/off
- Brightness slider
- CCT warm/cool or RGB color controls
- Small badge showing which path is active (MQTT / WebSocket / BLE)
- Full-screen sheet with Close button
- Responsive layout (no stretched UI on different phone sizes)

### Multi-channel devices

- Advanced view for hubs with multiple channels
- Channel selection (CCT or RGB per channel)

---

## 6. How to Test (Client / QA Checklist)

### Before testing

- [ ] Real iPhone (recommended over simulator)
- [ ] Limi device powered on
- [ ] Phone and device on the **same Wi‑Fi** (for LAN/cloud tests)
- [ ] Bluetooth **ON** (for BLE tests)
- [ ] Internet available (for MQTT/cloud tests)
- [ ] User logged in to the app

### Basic test (Automatic mode)

1. Open **Connected Devices**
2. Set **Control path** → **Automatic (firmware)**
3. Tap a device (green **Online** dot is best)
4. Turn **Power ON**
5. Move brightness and color sliders
6. Confirm the light changes
7. Check the path badge under Power (MQTT, WebSocket, or BLE)

### Test each path manually

| Control path | What to expect |
|--------------|----------------|
| **Automatic** | App picks the best path based on device state |
| **MQTT (cloud)** | Commands go via backend/cloud; needs internet + cloud connection |
| **LAN WebSocket** | Direct local Wi‑Fi control; needs same network + device IP |
| **Bluetooth (BLE)** | Phone must be Bluetooth-connected to device first; Wi‑Fi can be off |

### BLE note

Bluetooth control requires:

1. Bluetooth enabled on the phone
2. App connected to the device over BLE (via Add Device / scan flow)
3. Control path set to **Bluetooth (BLE)** or **Automatic** when Wi‑Fi is unavailable

---

## 7. Known Limitations

| Item | Detail |
|------|--------|
| Direct MQTT on phone | Not implemented; backend bridge is used instead |
| Manual control path | For testing only; can override firmware priority |
| BLE patterns | Pattern commands are not supported over Bluetooth (per protocol) |
| BLE connection | Connected Devices list alone does not auto-connect Bluetooth; BLE pairing/connect may be needed first |
| Device ID format | App uses the deviceId from mDNS TXT records; confirm firmware accepts the same format in JSON |

---

## 8. What Was Fixed Recently (UI)

The device control screen previously appeared **stretched** when opened from the device list. This has been corrected:

- Proper scroll layout inside the control sheet
- Preview and web configurator sizes scale to the phone/sheet size
- Consistent card-style sections (Power, Color, etc.)
- Clean navigation header with Close button
- Transport path shown as a compact badge (not a long text line)

---

## 9. One-Page Reference

```
┌─────────────────────────────────────────────┐
│  LIMI APP CONTROL — QUICK REFERENCE         │
├─────────────────────────────────────────────┤
│  Normal use:  Control path = Automatic      │
│  Cloud:       MQTT (via backend)            │
│  Same Wi‑Fi:  LAN WebSocket                 │
│  No Wi‑Fi:    Bluetooth (BLE)               │
│  Discovery:   mDNS _Limi1Ch._udp            │
│  Commands:    Unified JSON via LimiTransport│
└─────────────────────────────────────────────┘
```

---

## 10. Contact / Next Steps

For full technical details, see **APP_CONTROL_PROTOCOL.md** (firmware specification).

Suggested next steps for client validation:

1. Test Automatic mode on a live device (1-channel CCT and RGB if available)
2. Confirm cloud (MQTT) control when device is online on Wi‑Fi + internet
3. Confirm LAN WebSocket when cloud is unavailable but Wi‑Fi works
4. Confirm BLE when Wi‑Fi is off and phone is paired via Bluetooth
5. Sign off on UI/control flow on target iPhone models

---

*Last updated: May 2026*
