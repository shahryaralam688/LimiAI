#include <Arduino.h>
#include <Preferences.h>
#include "Wire.h"
#include "INA226.h"
#include "esp_ota_ops.h"

// 1. INCLUDE GLOBALS FIRST! 
// This tells the compiler what the structs look like before we allocate memory for them.
#include "globals.h"

// ===================================================
// 2. ALLOCATE GLOBAL MEMORY
// ===================================================
String wifiList[MAX_WIFI];
int numNetworksFound = 0;

LightingNode nodes[24]; 
uint8_t nodeCount = 0;
LightingSet sets[MAX_SETS];
uint8_t activeSets = 2;  
uint32_t lastUserAction[MAX_SETS] = {0};

float busN = 0, shuN = 0, curN = 0, powN = 0;
INA226 INA(0x44); 
bool INAStarted = 0;

Preferences prefs;
String saved_ssid;
String saved_pass;
bool apMode = false;

// ===================================================
// 3. INCLUDE YOUR MODULES
// ===================================================
#include "sensors.h"
#include "i2c_comms.h"
#include "network_ui.h"
#include "ble_setup.h"
#include "ota_manager.h"
#include "mqtt_setup.h"
#include "local_api.h"

// ===================================================
// 4. EXTERN FUNCTION WRAPPERS & CHOKEPOINTS
// ===================================================
void applyPWM(int set) { 
    if(set < nodeCount) {
        sendPWM(set, sets[set].ww, sets[set].cw); 
        publishMqttStatus(set); // Update app!
    }
}

void applyRGB(int set) { 
    if(set < nodeCount) {
        sendRGB(set, sets[set].r, sets[set].g, sets[set].b); 
        publishMqttStatus(set); // Update app!
    }
}

void applyPattern(int set) { 
    if(set < nodeCount) {
        sendPattern(set, sets[set].pattern, sets[set].r, sets[set].g, sets[set].b, sets[set].speed); 
        publishMqttStatus(set); // Update app!
    }
}

void printDeviceVersions() {
    Serial.println("\n====================================");
    Serial.printf(" ESP32 Master Version: %s\n", CURRENT_ESP_VERSION);
    
    if (nodeCount > 0) {
        Serial.printf(" STM32 Node Count: %d\n", nodeCount);
        for (int i = 0; i < nodeCount; i++) {
            if (nodes[i].online) {
                Serial.printf("  -> Node at 0x%02X | Firmware: v%d.%d\n", 
                    nodes[i].i2cAddr, 
                    nodes[i].status.fw_major, 
                    nodes[i].status.fw_minor);
            }
        }
    } else {
        Serial.println(" STM32 Nodes: None detected or offline.");
    }
    Serial.println("====================================\n");
}

// ===================================================
// SETUP
// ===================================================
void setup() {
    Serial.begin(115200);
    Serial.println("Version 1.0.1");
    // Check saved Wi-Fi credentials
    prefs.begin("wifi", false);
    saved_ssid = prefs.getString("ssid", "");
    saved_pass = prefs.getString("pass", "");
    prefs.end();

    if (connectToWiFi()) {
        // --- WIFI SUCCESS! START NORMAL OPERATIONS ---
        Serial.println("Connected to WiFi successfully!");
        initMQTT(); // initialise MQTT
        
        Wire.begin(19, 9); 
        i2cScan(); 
        delay(10);
        i2cScan(); 

        printDeviceVersions();
        executeOTASequence();
        setupOtaSchedule();

        if (INA.begin()) INAStarted = 1;
        INA.setMaxCurrentShunt(40.9, 0.002); 
  
        initWebSocket();
        
        // Start Web Server
        server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
            request->send_P(200, "text/html", MAIN_pageA); // From index.h
        });

        setupLocalAPI();
        
        server.begin();
        
    } else { 
        // --- WIFI FAILED! START BLE PROVISIONING ---
        scanForNetworks();
        initBLE();


        #if DEBUG_MODE
        // just added for testing, remember to remove
          //  Wire.begin(19, 9); 
          //  i2cScan(); 
          //  delay(1000);
           // i2cScan(); 
  
         //   if (INA.begin()) INAStarted = 1;
          //  INA.setMaxCurrentShunt(40.9, 0.002); 
            // end of bit to remove

            //runDiagnosticRGBTest();
          //  runDiagnosticLightTest();
        #endif


    }
    // Confirm the current firmware is stable. 
    // If it crashes before reaching this line, the bootloader will roll back to the previous version.
    esp_ota_mark_app_valid_cancel_rollback();
}

// ===================================================
// LOOP
// ===================================================
void loop() {
  //if (apMode) { 
    // Fallback Captive Portal (if still using it)
   // dnsServer.processNextRequest();
  //} else { 
    // Normal Operations
    ina226gather();
    pollStm32s();
    
    // --- 1. OFFLINE RECOVERY ---
    // Must be OUTSIDE the Wi-Fi check so it can revive nodes if the router is down!
    handleOTARecoveryTask(); 
    
    // --- 2. 2D MATRIX GRANDMASTER CLOCK ---
    // Blast the ESP32's current time to all STM32s every 5 seconds 
    // so their 2D math animations stay perfectly in phase.
    static unsigned long lastTimeSync = 0;
    if (millis() - lastTimeSync > 5000) {
        lastTimeSync = millis();
        broadcastTimeSync(); 
        DEBUG_PRINTLN("loop");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        ws.cleanupClients(); 
        handleMqtt();
        handleScheduledOTA(); 
        // --- 3. OTA RAM CACHE ---
        // Silently checks if we have the STM32 backup firmware in memory.
        // If not, downloads it in the background.
        ensureStmCache(); 
    }
  //}
}
