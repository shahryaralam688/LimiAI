#pragma once
#include "globals.h"
#include <WiFi.h> // Required for grabbing localIP() and MAC for provisioning

// --- NEW I2C COMMAND DEFINES ---
#define CMD_SYNC_TIME   0x0A
#define CMD_MATRIX_CFG  0x0B
#define CMD_PROV_CHUNK  0x0C
#define CMD_PROV_EXEC   0x0D

uint8_t pollIndex = 0;
uint32_t lastPoll = 0;

uint8_t addrForSet(uint8_t setId) {  
  return nodes[setId].i2cAddr;
}

// ===================================================
// 1. STANDARD I2C TRANSMITTERS
// ===================================================

void sendPWM(uint8_t set, uint8_t ww, uint8_t cw) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_PWM); Wire.write(ww); Wire.write(cw);
  Wire.endTransmission();
}

void sendRGB(uint8_t set, uint8_t r, uint8_t g, uint8_t b) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_RGB); 
  Wire.write(r); Wire.write(g); Wire.write(b);
  Wire.endTransmission();
}

void sendPattern(uint8_t set, uint8_t pattern, uint8_t r, uint8_t g, uint8_t b, uint8_t speed) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_PATTERN); Wire.write(pattern); Wire.write(r); Wire.write(g); Wire.write(b); Wire.write(speed);
  Wire.endTransmission();
}

void sendLedCount(uint8_t set, uint16_t count) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_LED_COUNT);
  Wire.write((uint8_t)(count >> 8)); 
  Wire.write((uint8_t)(count & 0xFF));
  Wire.endTransmission();
}

void sendInstantOn(uint8_t set, uint8_t enabled) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_INSTANT_ON); Wire.write(enabled);
  Wire.endTransmission();
}

void sendColorConfig(uint8_t set, uint8_t order, uint8_t r, uint8_t g, uint8_t b) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_SET_COLOR_CFG); Wire.write(order); Wire.write(r); Wire.write(g); Wire.write(b);
  Wire.endTransmission();
}

void sendDiagnosticRequest(uint8_t set) {
  Wire.beginTransmission(addrForSet(set));
  Wire.write(CMD_DIAGNOSTIC);
  Wire.endTransmission();
}

// ===================================================
// 2. SWARM & MATRIX ADVANCED COMMANDS
// ===================================================

// Broadcasts the ESP32's internal millis() to all STM32s to lock their animation frames together
void broadcastTimeSync() {
    uint32_t global_time = millis();
    for (int i = 0; i < nodeCount; i++) {
        if (nodes[i].online) {
            Wire.beginTransmission(nodes[i].i2cAddr);
            Wire.write(CMD_SYNC_TIME);
            Wire.write((uint8_t)(global_time >> 24));
            Wire.write((uint8_t)(global_time >> 16));
            Wire.write((uint8_t)(global_time >> 8));
            Wire.write((uint8_t)(global_time & 0xFF));
            Wire.endTransmission();
        }
    }
}

// Tells a specific STM32 what its physical position is inside a 2D LED Wall
void sendMatrixConfig(uint8_t set, uint8_t width, uint8_t height, uint16_t global_x, uint16_t global_y, uint16_t global_w, uint16_t global_h, uint8_t layout_type) {
    Wire.beginTransmission(addrForSet(set));
    Wire.write(CMD_MATRIX_CFG); 
    Wire.write(width);
    Wire.write(height);
    Wire.write((uint8_t)(global_x >> 8)); Wire.write((uint8_t)(global_x & 0xFF));
    Wire.write((uint8_t)(global_y >> 8)); Wire.write((uint8_t)(global_y & 0xFF));
    Wire.write((uint8_t)(global_w >> 8)); Wire.write((uint8_t)(global_w & 0xFF));
    Wire.write((uint8_t)(global_h >> 8)); Wire.write((uint8_t)(global_h & 0xFF));
    Wire.write(layout_type);
    Wire.endTransmission();
}

// Commands an STM32 to transmit a 1-Wire Manchester encoded setup packet to a smart pendant
void provisionPendantNode(uint8_t set, uint8_t channel_id) {
    Serial.printf("[PROV] Sending Binary Provisioning Data to Set %d...\n", set);
    
    // We build a strict 110-byte memory map for the STM32 to hold in RAM
    uint8_t payload[128] = {0};
    
    // --- 1. Pack SSID (Offset 0 to 32) ---
    payload[0] = saved_ssid.length();
    for(int i=0; i<payload[0]; i++) payload[1+i] = saved_ssid[i];
    
    // --- 2. Pack Password (Offset 33 to 97) ---
    payload[33] = saved_pass.length();
    for(int i=0; i<payload[33]; i++) payload[34+i] = saved_pass[i];
    
    // --- 3. Pack Network Config (Offset 98 to 109) ---
    // Byte 98: Protocol Version (so future pendants know how to read this structure)
    payload[98] = 0x01; 
    
    // Bytes 99-102: IP Address (4 Bytes)
    IPAddress ip = WiFi.localIP();
    payload[99] = ip[0]; payload[100] = ip[1]; payload[101] = ip[2]; payload[102] = ip[3];
    
    // Bytes 103-108: MAC Address / Hub ID (6 Bytes)
    uint8_t mac[6];
    WiFi.macAddress(mac);
    for(int i=0; i<6; i++) payload[103+i] = mac[i];
    
    // Byte 109: Pendant Position / Channel
    payload[109] = channel_id;

    // --- Stream to STM32 in 14-byte I2C Chunks ---
    // I2C buffers crash if we send more than 32 bytes at once, so we slice it up.
    uint8_t total_len = 110;
    uint8_t offset = 0;
    
    while(offset < total_len) {
        uint8_t chunk = (total_len - offset > 14) ? 14 : (total_len - offset);
        
        Wire.beginTransmission(addrForSet(set));
        Wire.write(CMD_PROV_CHUNK); // 0x0C
        Wire.write(offset);         // Tell STM32 exactly where this chunk belongs in its array
        
        for(int i=0; i<chunk; i++) {
            Wire.write(payload[offset+i]);
        }
        Wire.endTransmission();
        
        offset += chunk;
        delay(10); // Give STM32 a moment to safely write to RAM
    }
    
    // --- Trigger the STM32 State Machine ---
    Wire.beginTransmission(addrForSet(set));
    Wire.write(CMD_PROV_EXEC); // 0x0D
    Wire.endTransmission();
}

// ===================================================
// 3. I2C RECEIVERS & POLLING
// ===================================================

bool readStm32Status(LightingNode &node) {
  // 1. Explicitly request status with the command byte
  Wire.beginTransmission(node.i2cAddr);
  Wire.write(CMD_GET_STATUS); // 0x20
  if (Wire.endTransmission(false) != 0) return false;

  // 2. We expect exactly 20 bytes now (includes the RGBW flag at byte 19)
  uint8_t len = 20; 
  if (Wire.requestFrom((uint8_t)node.i2cAddr, len) != len) return false;

  uint8_t *p = (uint8_t*)&node.status;
  for (uint8_t i = 0; i < len; i++) {
    p[i] = Wire.read();
  }

  // 3. Verify Packet Integrity
  if (node.status.magic != 0xA5) return false;

  node.lastSeen = millis();
  node.online = true;
  
  // 4. THE SHIELD 
  // If the user is actively sliding (last 2 seconds), skip updating the 'sets' variables
  // so the sliders don't fight the user.
  if (lastUserAction[node.setId] != 0 && (millis() - lastUserAction[node.setId] < 2000)) {
      return true; 
  }

  // 5. MAP HARDWARE TO UI
  LightingSet &s = sets[node.setId];
  
  // Sync Advanced Configs
  s.ledCount = (node.status.led_hi << 8) | node.status.led_lo;
  s.instantOn = node.status.instant_on;
  s.colorOrder = node.status.color_ord;
  s.balR = node.status.bal_r;
  s.balG = node.status.bal_g;
  s.balB = node.status.bal_b;

  // Sync Live Mode & Light state
  if (node.status.mode == 0) { // STM32 CCT Mode
      s.mode = 1; // ESP32 MODE_PWM
      s.ww = node.status.p1;
      s.cw = node.status.p2;
  } else if (node.status.mode == 1) { // STM32 RGB Mode
      // If p1 is 1 (Solid) or 0 (Off), use RGB mode, otherwise Pattern mode
      s.mode = (node.status.p1 <= 1) ? 2 : 3; 
      s.pattern = node.status.p1;
      s.r = node.status.p2;
      s.g = node.status.p3;
      s.b = node.status.p4;
      s.speed = node.status.p5;
  }

  // 6. BEAUTIFUL DEBUG OUTPUT (Rate-limited to once every 5 seconds per node)
  #if DEBUG_MODE
      static unsigned long lastDebugPrint[24] = {0}; // Assumes MAX_SETS is 24 or less
      if (millis() - lastDebugPrint[node.setId] > 10000) {
          lastDebugPrint[node.setId] = millis();
          
          if (s.mode == 1) {
              DEBUG_PRINTF("[SYNC] Node %d (0x%02X) | CCT Mode | LEDs: %d | WW: %d%%, CW: %d%%\n", 
                           node.setId, node.i2cAddr, s.ledCount, s.ww, s.cw);
          } else {
              DEBUG_PRINTF("[SYNC] Node %d (0x%02X) | RGB Mode | LEDs: %d | R:%d G:%d B:%d | Pat: %d\n", 
                           node.setId, node.i2cAddr, s.ledCount, s.r, s.g, s.b, s.pattern);
          }
      }
  #endif

  return true;
}

void i2cScan(){
  byte error;
  uint8_t i2caddress; 
  int nDevices = 0;   
  nodeCount = 0;
  
  Serial.println("Scanning for I2C devices ...");
  for (i2caddress = 0x01; i2caddress < 0x7f; i2caddress++) {
    // Skip the INA226 address if you already know it (e.g., 0x44) to avoid "BadCmd" on sensors
    if (i2caddress == 0x44) {
        nDevices++; 
        continue; 
    }

    Wire.beginTransmission(i2caddress);
    error = Wire.endTransmission();
    
    if (error == 0) {
      if ((i2caddress >= LIGHTING_ADDR_STARTA && i2caddress <= LIGHTING_ADDR_ENDA)||
          (i2caddress >= LIGHTING_ADDR_STARTB && i2caddress <= LIGHTING_ADDR_ENDB)||
          (i2caddress >= LIGHTING_ADDR_STARTC && i2caddress <= LIGHTING_ADDR_ENDC)){
        
        DEBUG_PRINTF("Found Lighting Node at 0x%02X. Syncing...\n", i2caddress);
        
        nodes[nodeCount].i2cAddr = i2caddress;
        nodes[nodeCount].setId = nodeCount;
        
        // --- Download state from STM32 immediately-ish (5ms delay) ---
        delay(5);
        
        // This replaces all those "Setup Defaults" lines.
        if (!readStm32Status(nodes[nodeCount])) {
            DEBUG_PRINTLN("Initial sync failed, using temporary defaults.");
            sets[nodeCount].ledCount = 300; // Fallback only
            sets[nodeCount].mode = 1; 
        }

        nodeCount++;
      }
      nDevices++;
    } 
  }
  activeSets = nodeCount; // More accurate than nDevices - 1
  DEBUG_PRINTF("Scan complete. %d nodes online and synced.\n", nodeCount);
}

void pollStm32s() {
  uint32_t now = millis();
  if (now - lastPoll < POLL_INTERVAL_MS) return;
  lastPoll = now;

  if (nodeCount == 0) return;

  LightingNode &n = nodes[pollIndex];

  if (!readStm32Status(n)) {
    if (now - n.lastSeen > 5000) {
      n.online = false;
    }
  }

  pollIndex++;
  if (pollIndex >= nodeCount) pollIndex = 0;
}
