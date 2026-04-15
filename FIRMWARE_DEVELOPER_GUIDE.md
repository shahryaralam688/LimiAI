# Firmware Developer Documentation - Limi iOS App Communication Protocol

## 1. mDNS/Bonjour TXT Record Requirements

Your firmware MUST broadcast the following TXT records via mDNS/Bonjour for the iOS app to discover and properly communicate with the device.

### Required TXT Record Fields

| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `deviceId` | String | Unique device identifier (MAC address preferred) | `"80b54ee8b228"` |
| `channelCount` | Integer | Number of light channels this device controls | `1` or `2` |
| `channelTypes` | String | Comma-separated channel types (CCT/RGB) | `"CCT,RGB,CCT,CCT"` |

### TXT Record Implementation Example (ESP32/Arduino)

```cpp
#include <ESPmDNS.h>

// In your setup() or WiFi connection handler:
void setupMDNS() {
    // Initialize mDNS
    if (!MDNS.begin("LimiDevice")) {
        Serial.println("Error setting up MDNS responder!");
        while(1) {
            delay(1000);
        }
    }
    
    // Add service - Limi1Ch is the service type the iOS app looks for
    MDNS.addService("_Limi1Ch", "_udp", 5353);
    
    // Add required TXT records
    String deviceId = "80b54ee8b228";  // Your device MAC or unique ID
    String channelCount = "1";          // Number of channels (1 or 2)
    String channelTypes = "CCT,RGB,CCT,CCT";  // Channel types (CCT or RGB)
    
    // Add TXT records for service discovery
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "deviceId", deviceId);
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "channelCount", channelCount);
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "channelTypes", channelTypes);
    
    Serial.println("mDNS initialized with TXT records:");
    Serial.println("  deviceId: " + deviceId);
    Serial.println("  channelCount: " + channelCount);
    Serial.println("  channelPosition: " + channelPosition);
}
```

### Channel Position Logic

- `channelPosition` tells the iOS app which physical channel this device controls
- For single-channel devices, use `1`
- For multi-channel setups, increment the position for each device
- Example: Device A (channels 1-3) → `channelPosition: 1`, Device B (channels 4-6) → `channelPosition: 4`

---

## 2. iOS App View Selection Logic

Based on `channelCount`, the iOS app will display different control interfaces:

| channelCount | View Shown | Description |
|--------------|------------|-------------|
| `0` | Alert | "No pendant connected" error |
| `1` | Direct view | Single channel - opens CCTLEDView or WLEDView based on `channelTypes[0]` |
| `>1` | ChannelSelectionView | Multi-channel popup showing all channels with their types |

---

## 3. WebSocket Command Messages (iOS → Firmware)

The iOS app connects to the backend via WebSocket and sends control commands. Your firmware should listen for these messages on the WebSocket connection.

### 3.1 CCT Light Control (channelCount = 1)

When user adjusts CCT (warm/cool white) lights:

**Event Name:** `light_controll`

**JSON Format:**
```json
{
  "deviceId": "80B54EE8B228",
  "command": {
    "channel": 1,
    "ww": 75,
    "cw": 25,
    "brightness": 200
  }
}
```

**Field Descriptions:**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `deviceId` | String | - | Device MAC address (uppercase) |
| `command.channel` | Integer | 1+ | The 1-based channel index user selected |
| `command.ww` | Integer | 0-100 | Warm white percentage (CCT only) |
| `command.cw` | Integer | 0-100 | Cool white percentage (CCT only) |
| `command.brightness` | Integer | 0-255 | Overall brightness level |

### 3.2 RGB Light Control (channelCount = 2)

When user adjusts RGB lights:

**Event Name:** `light_controll`

**JSON Format:**
```json
{
  "deviceId": "80B54EE8B228",
  "command": {
    "channel": 2,
    "red": 220,
    "green": 20,
    "blue": 200,
    "brightness": 128
  }
}
```

**Field Descriptions:**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `deviceId` | String | - | Device MAC address (uppercase) |
| `command.channel` | Integer | 1+ | The 1-based channel index user selected |
| `command.red` | Integer | 0-255 | Red color value |
| `command.green` | Integer | 0-255 | Green color value |
| `command.blue` | Integer | 0-255 | Blue color value |
| `command.brightness` | Integer | 0-255 | Overall brightness level |

### 3.3 Pattern/Effect Control (RGB Effects)

When user selects an animation pattern:

**Event Name:** `light_controll`

**JSON Format:**
```json
{
  "deviceId": "80B54EE8B228",
  "command": {
    "channel": 2,
    "pattern": {
      "id": 3,
      "speed": 128,
      "intensity": 200,
      "color": [220, 20, 200]
    }
  }
}
```

**Field Descriptions:**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `deviceId` | String | - | Device MAC address (uppercase) |
| `command.channel` | Integer | 1+ | The channel position from TXT record |
| `command.pattern.id` | Integer | 1-31 | Pattern/effect ID (see pattern list below) |
| `command.pattern.speed` | Integer | 0-255 | Animation speed |
| `command.pattern.intensity` | Integer | 0-255 | Effect intensity |
| `command.pattern.color` | Array | [0-255, 0-255, 0-255] | RGB color for effect |

### Pattern ID Reference

| ID | Pattern Name |
|----|--------------|
| 1 | Solid |
| 2 | Pulse |
| 3 | Rainbow |
| 4 | Rainbow Cycle |
| 5 | Fade |
| 6 | Breathe |
| 7 | Chase |
| 8 | Sparkle |
| 9 | Meteor |
| 10 | Fire |
| 11 | Cylon |
| 12 | Rainbow Strobe |
| 13 | Chase Rainbow |
| 14 | Double Chase |
| 15 | Wave |
| 16 | Running Lights |
| 17 | Rainbow Pulse |
| 18 | Gradient |
| 19 | Dots |
| 20 | Fading Blocks |
| 21 | Bouncing Ball |
| 22 | Flashing |
| 23 | Strobe |
| 24 | Color Wipe |
| 25 | Theater Chase |
| 26 | Twinkle |
| 27 | Rainbow Multi |
| 28 | Alternating |
| 29 | Random Flash |
| 30 | Breathing Rainbow |
| 31 | Segment Rainbow |

---

## 4. Full Communication Flow

```
┌─────────────┐      mDNS/Bonjour       ┌─────────────┐
│  Firmware   │ ───────────────────────> │   iOS App   │
│             │  TXT: deviceId           │             │
│             │  TXT: channelCount       │             │
│             │  TXT: channelTypes (CCT,RGB...)   │             │
└─────────────┘                          └─────────────┘
                                                │
                                                │ HTTP POST
                                                ▼
                                        ┌─────────────┐
                                        │   Backend   │
                                        │   Server    │
                                        └─────────────┘
                                                │
                                         WebSocket
                                                │
                                                ▼
┌─────────────┐     WebSocket         ┌─────────────┐
│  Firmware   │ <────────────────────── │   iOS App   │
│   (Listens) │   Event: light_controll  │  (Sends)    │
│             │   JSON commands          │             │
└─────────────┘                          └─────────────┘
```

---

## 5. Implementation Checklist for Firmware Developer

- [ ] Implement mDNS/Bonjour service advertising
- [ ] Add TXT record: `deviceId` (unique device identifier)
- [ ] Add TXT record: `channelCount` (1 or 2)
- [ ] Add TXT record: `channelTypes` (comma-separated: CCT,RGB,CCT,RGB)
- [ ] Implement WebSocket client to connect to backend
- [ ] Listen for `light_controll` events
- [ ] Parse JSON commands for CCT (ww, cw, brightness)
- [ ] Parse JSON commands for RGB (red, green, blue, brightness)
- [ ] Parse JSON commands for patterns (id, speed, intensity, color)
- [ ] Use `command.channel` to determine which physical channel to control
- [ ] Match uppercase `deviceId` from JSON to your device ID

---

## 6. Example Complete Firmware TXT Record Setup

```cpp
// Example for ESP32 with WiFi and mDNS
#include <WiFi.h>
#include <ESPmDNS.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Device configuration
String DEVICE_ID = "80b54ee8b228";  // Your device MAC or unique ID
int CHANNEL_COUNT = 4;               // Number of channels
String CHANNEL_TYPES = "CCT,RGB,CCT,CCT";  // Type of each channel

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWiFi connected");
    Serial.println("IP address: " + WiFi.localIP().toString());
    
    // Initialize mDNS
    if (!MDNS.begin("LimiDevice")) {
        Serial.println("Error setting up MDNS responder!");
        while(1) delay(1000);
    }
    
    // Add Bonjour service
    MDNS.addService("_Limi1Ch", "_udp", 5353);
    
    // Add TXT records - THESE ARE CRITICAL FOR iOS APP DISCOVERY
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "deviceId", DEVICE_ID);
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "channelCount", String(CHANNEL_COUNT));
    MDNS.addServiceTxt("_Limi1Ch", "_udp", "channelTypes", CHANNEL_TYPES);
    
    Serial.println("mDNS service started with:");
    Serial.println("  Service: _Limi1Ch._udp");
    Serial.println("  deviceId: " + DEVICE_ID);
    Serial.println("  channelCount: " + String(CHANNEL_COUNT));
    Serial.println("  channelTypes: " + CHANNEL_TYPES);
}

void loop() {
    // Your main loop - handle WebSocket connections and light control
}
```

---

## 7. Testing Your Implementation

### Verify TXT Records (macOS/Linux):
```bash
# Discover all Limi devices on network
dns-sd -B _Limi1Ch _udp

# Query specific device TXT records
dns-sd -q LimiDevice.local _Limi1Ch._udp
```

### Verify WebSocket Messages:
Connect to the same WebSocket endpoint as the iOS app and listen for `light_controll` events to verify your firmware receives the correct JSON format.

---

**Document Version:** 1.0  
**Last Updated:** March 25, 2026  
**For:** Limi Firmware Development Team
