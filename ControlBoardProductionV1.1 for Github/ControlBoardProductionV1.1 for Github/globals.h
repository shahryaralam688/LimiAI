#pragma once
#define DEBUG_MODE 1  // Change to 0 to completely disable all debug prints

#if DEBUG_MODE
  #define DEBUG_PRINT(x) Serial.print(x)
  #define DEBUG_PRINTLN(x) Serial.println(x)
  #define DEBUG_PRINTF(...) Serial.printf(__VA_ARGS__)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
  #define DEBUG_PRINTF(...)
#endif

#include "globals.h"
#include <Arduino.h>
#include <Arduino_JSON.h>
#include "Wire.h"
#include "INA226.h"

// --- DEFINES ---
#define MAX_WIFI 15
#define MAX_SETS 64 
#define POLL_INTERVAL_MS 150 
#define CMD_SET_PWM 0x01
#define CMD_SET_RGB 0x02
#define CMD_SET_PATTERN 0x03 
#define CMD_DIAGNOSTIC 0x04 
#define CMD_SET_LED_COUNT 0x05 
#define CMD_SET_INSTANT_ON 0x06 
#define CMD_SET_COLOR_CFG 0x07 
#define CMD_GET_STATUS 0x20   
// Add these missing definitions to globals.h
#define AP_SSID       "LIMI-Setup"
#define AP_PASS       "12345678"
#define WIFI_TIMEOUT  10000
#define DNS_PORT      53

#define LIGHTING_ADDR_STARTA 0x08
#define LIGHTING_ADDR_ENDA   0x3F
#define LIGHTING_ADDR_STARTB 0x50
#define LIGHTING_ADDR_ENDB   0x5F
#define LIGHTING_ADDR_STARTC 0x60
#define LIGHTING_ADDR_ENDC   0x77

// --- STRUCTS ---
#pragma pack(push, 1)
struct Stm32Status {
  uint8_t magic, mode, adc_avg, temp, errors, fw_major, fw_minor;
  uint8_t led_hi, led_lo, instant_on, color_ord, bal_r, bal_g, bal_b;
  uint8_t p1, p2, p3, p4, p5, pad;
};
#pragma pack(pop)

struct LightingNode {
  uint8_t i2cAddr, setId, mode;
  Stm32Status status;
  uint32_t lastSeen;
  bool online;
};

struct LightingSet {
  uint8_t mode, ww, cw, r, g, b, pattern, speed;
  uint16_t ledCount;
  uint8_t instantOn, colorOrder, balR, balG, balB;
};

// --- EXTERN GLOBALS (Defined in main.cpp) ---
extern String wifiList[MAX_WIFI];
extern int numNetworksFound;
extern LightingNode nodes[24]; 
extern uint8_t nodeCount;
extern LightingSet sets[MAX_SETS];
extern uint8_t activeSets;  
extern uint32_t lastUserAction[MAX_SETS];
extern float busN, shuN, curN, powN;
extern INA226 INA;

// --- EXTERN FUNCTIONS ---
void applyPWM(int set);
void applyRGB(int set);
void applyPattern(int set);
extern void publishMqttStatus(int set);
void sendLedCount(uint8_t set, uint16_t count);
void sendInstantOn(uint8_t set, uint8_t enabled);
void sendColorConfig(uint8_t set, uint8_t order, uint8_t r, uint8_t g, uint8_t b);
void sendDiagnosticRequest(uint8_t set);
extern void i2cScan();

// --- I2C COMMS EXTERN FUNCTIONS ---
extern void broadcastTimeSync();
extern void sendMatrixConfig(uint8_t set, uint8_t width, uint8_t height, uint16_t global_x, uint16_t global_y, uint16_t global_w, uint16_t global_h, uint8_t layout_type);
extern void provisionPendantNode(uint8_t set, uint8_t channel_id);

// --- OTA EXTERN FUNCTIONS ---
extern void executeOTASequence();
extern void handleOTARecoveryTask();
extern void ensureStmCache();
