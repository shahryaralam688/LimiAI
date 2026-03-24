#pragma once
#include "globals.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <Arduino_JSON.h>

// ======== EMQX CONFIG =========
//const char* mqtt_server = "mqtt.limilighting.com"; 
//const int mqtt_port = 1883;                   
//const char* mqtt_user = "aura-client";                   
//const char* mqtt_pass = "AuraPass123!";


// ======== EMQX CONFIG =========
const char* mqtt_server = "mqtt.limilighting.co.uk"; 
const int mqtt_port = 1884;                   
const char* mqtt_user = "limiuser";                   
const char* mqtt_pass = "test";

WiFiClient espClient;
PubSubClient MqttClient(espClient);

String commandTopic;
String statusTopic;
String deviceID_MAC;
unsigned long lastMqttReconnectAttempt = 0;
unsigned long wifiConnectedAt = 0;
bool wifiWasConnected = false;
unsigned long lastStatusPublish = 0;

String getChipId() {
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    //mac.toLowerCase();
    return mac;
}

void prepareTopics() {
    deviceID_MAC = getChipId();
    String prefix = "device/";
    commandTopic = prefix + deviceID_MAC + "/command";
    statusTopic = prefix + deviceID_MAC + "/status";
}

// --- PUBLISH STATUS TO APP ---
void publishMqttStatus(int ch) {
    if (!MqttClient.connected() || ch >= nodeCount) return;

    JSONVar doc;
    doc["deviceId"] = deviceID_MAC;
    
    JSONVar status;
    status["channel"] = ch + 1; // Tell the iOS app it is channel 1, 2, 3, etc.
    
    if (sets[ch].mode == 1) status["mode"] = "CCT";
    else if (sets[ch].mode == 2) status["mode"] = "RGB";
    else status["mode"] = "PATTERN";

    status["ww"] = sets[ch].ww;
    status["cw"] = sets[ch].cw;
    status["red"] = sets[ch].r;
    status["green"] = sets[ch].g;
    status["blue"] = sets[ch].b;
    status["pattern"] = sets[ch].pattern;
    status["speed"] = sets[ch].speed;
    
    // Advanced Configs
    status["ledCount"] = sets[ch].ledCount;
    status["instantOn"] = sets[ch].instantOn;
    status["colorOrder"] = sets[ch].colorOrder;
    
    status["wifi_uptime"] = (millis() - wifiConnectedAt) / 1000; // Time since Wi-Fi connected

    // ESP32 Health
    status["uptime"] = millis() / 1000;
    status["rssi"] = WiFi.RSSI();
    status["heap"] = ESP.getFreeHeap();

    // --- NEW: INA226 Power Metrics (Global to the board) ---
    status["bus_v"] = busN;
    status["current_ma"] = curN;
    status["power_mw"] = powN;

    // --- NEW: STM32 Node Status (Specific to this channel) ---
    status["online"] = nodes[ch].online;
    
    // NOTE: Change ".temp" if your struct uses a different name!
    status["temp"] = nodes[ch].status.temp; 

    doc["status"] = status;

    String output = JSON.stringify(doc);
    MqttClient.publish(statusTopic.c_str(), output.c_str(), true);
    Serial.printf("MQTT <- Published Status for Channel %d\n", ch); // Optional: mute to reduce serial spam
}

// --- INCOMING MQTT PARSER ---
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    Serial.printf("MQTT Message arrived [%s]\n", topic);

    String message;
    for (unsigned int i = 0; i < length; i++) {
        message += (char)payload[i];
    }

    Serial.printf("Payload: %s\n", message.c_str());

    JSONVar doc = JSON.parse(message);
    if (JSON.typeof(doc) == "undefined") {
        Serial.println("Error: Failed to parse JSON payload!");
        return;
    }

    if (doc.hasOwnProperty("command")) {
        JSONVar command = doc["command"];
        
        //int ch = 0;
        //if (command.hasOwnProperty("channel")) ch = (int)command["channel"];
        //if (ch >= MAX_SETS || ch >= nodeCount) return;

        int ch = 0; // Default to internal channel 0
        if (command.hasOwnProperty("channel")) {
            ch = (int)command["channel"] - 1; // Convert app's 1-based number back to C++ 0-based index
        }
        
        // Safety check: prevent negative numbers and out-of-bounds channels
        if (ch < 0 || ch >= MAX_SETS || ch >= nodeCount) {
            Serial.printf("MQTT -> Ignored invalid channel request: %d\n", ch + 1);
            return; 
        }


        // 1. CCT COMMAND PARSING
        if (command.hasOwnProperty("ww") && command.hasOwnProperty("cw")) {
            int bright = command.hasOwnProperty("brightness") ? (int)command["brightness"] : 255;
            sets[ch].mode = 1;
            sets[ch].ww = ((int)command["ww"] * bright) / 255;
            sets[ch].cw = ((int)command["cw"] * bright) / 255;
            Serial.printf("MQTT -> CCT Set\n");
            applyPWM(ch);
        }
        
        // 2. RGB COMMAND PARSING
        else if (command.hasOwnProperty("red") && command.hasOwnProperty("green") && command.hasOwnProperty("blue") && !command.hasOwnProperty("pattern")) {
            int bright = command.hasOwnProperty("brightness") ? (int)command["brightness"] : 255;
            sets[ch].mode = 2;
            sets[ch].r = ((int)command["red"] * bright) / 255;
            sets[ch].g = ((int)command["green"] * bright) / 255;
            sets[ch].b = ((int)command["blue"] * bright) / 255;
            Serial.printf("MQTT -> RGB Set\n");
            applyRGB(ch);
        }

        // 3. PATTERN COMMAND PARSING
        // Example: {"command":{"channel":0,"pattern":10,"speed":80,"red":255,"green":0,"blue":0}}
        else if (command.hasOwnProperty("pattern")) {
            sets[ch].mode = 3;
            sets[ch].pattern = (int)command["pattern"];
            
            // Allow app to omit speed/colors, fallback to current settings if missing
            if (command.hasOwnProperty("speed")) sets[ch].speed = (int)command["speed"];
            if (command.hasOwnProperty("red")) sets[ch].r = (int)command["red"];
            if (command.hasOwnProperty("green")) sets[ch].g = (int)command["green"];
            if (command.hasOwnProperty("blue")) sets[ch].b = (int)command["blue"];
            
            Serial.printf("MQTT -> Pattern %d Set\n", sets[ch].pattern);
            applyPattern(ch);
        }

        // 4. ADVANCED SETTINGS PARSING
        // Example LEDS: {"command":{"channel":0,"adv":"leds","value":300}}
        // Example INST: {"command":{"channel":0,"adv":"instant","value":1}}
        // Example ORD:  {"command":{"channel":0,"adv":"color","order":0,"balR":255,"balG":255,"balB":255}}
        else if (command.hasOwnProperty("adv")) {
            String advType = (const char*)command["adv"];
            
            if (advType == "leds" && command.hasOwnProperty("value")) {
                sets[ch].ledCount = (int)command["value"];
                sendLedCount(ch, sets[ch].ledCount);
                Serial.printf("MQTT -> Adv LED Count: %d\n", sets[ch].ledCount);
            }
            else if (advType == "instant" && command.hasOwnProperty("value")) {
                sets[ch].instantOn = (int)command["value"];
                sendInstantOn(ch, sets[ch].instantOn);
                Serial.printf("MQTT -> Adv Instant On: %d\n", sets[ch].instantOn);
            }
            else if (advType == "color") {
                if (command.hasOwnProperty("order")) sets[ch].colorOrder = (int)command["order"];
                if (command.hasOwnProperty("balR")) sets[ch].balR = (int)command["balR"];
                if (command.hasOwnProperty("balG")) sets[ch].balG = (int)command["balG"];
                if (command.hasOwnProperty("balB")) sets[ch].balB = (int)command["balB"];
                sendColorConfig(ch, sets[ch].colorOrder, sets[ch].balR, sets[ch].balG, sets[ch].balB);
                Serial.printf("MQTT -> Adv Color Config Set\n");
            }
            publishMqttStatus(ch); // Update app with new advanced settings
        }

        // 5. DIAGNOSTIC TRIGGER
        // Example: {"command":{"channel":0,"trigger":"diag"}}
        else if (command.hasOwnProperty("trigger")) {
            String trig = (const char*)command["trigger"];
            if (trig == "diag") {
                sendDiagnosticRequest(ch);
                Serial.printf("MQTT -> Hardware Diagnostic Triggered\n");
                // Note: The background poller will automatically catch the resulting status change!
            }
        }
        // 6. OTA UPDATE TRIGGER
        // Example: {"command":{"trigger":"ota"}}
        else if (command.hasOwnProperty("trigger")) {
            String trig = (const char*)command["trigger"];
            if (trig == "diag") {
                sendDiagnosticRequest(ch);
                Serial.printf("MQTT -> Hardware Diagnostic Triggered\n");
            }
            // ADD THIS NEW TRIGGER:
            else if (trig == "ota") {
                Serial.println("MQTT -> OTA Update Sequence Triggered by App!");
                // Execute the OTA check and update process
                executeOTASequence(); 
            }
        }

        // Force a status update after any command is processed
        publishMqttStatus(ch);
    }
}

// --- NON-BLOCKING RECONNECT & LOOP ---
void handleMqtt() {
// 1. Check if Wi-Fi physically dropped
    if (WiFi.status() != WL_CONNECTED) {
        wifiWasConnected = false; // Reset our tracker
        return; // Don't even try to connect to MQTT yet
    }

    // 2. If Wi-Fi is connected, check if it JUST connected
    if (!wifiWasConnected) {
        wifiConnectedAt = millis(); // Record the exact moment we got Wi-Fi
        wifiWasConnected = true;
    }

    // 3. Wi-Fi is good, check MQTT
    if (!MqttClient.connected()) {
        unsigned long now = millis();
        if (now - lastMqttReconnectAttempt > 1000) {
            lastMqttReconnectAttempt = now;
            
            Serial.print("Connecting to EMQX MQTT broker... ");
            String clientId = "Dev_" + deviceID_MAC;  
            
            if (MqttClient.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
                Serial.println("Connected!");
                MqttClient.subscribe(commandTopic.c_str());
                
                for (int i = 0; i < nodeCount; i++) {
                    publishMqttStatus(i);
                }
            } else {
                Serial.printf("Failed, rc=%d. Will try again in 1s.\n", MqttClient.state());
            }
        }
    } else {
        MqttClient.loop();
        
        // 3. ADDED HEARTBEAT: Publish status every 10 seconds
        unsigned long now = millis();
        if (now - lastStatusPublish > 10000) { // 10000 ms = 10 seconds
            lastStatusPublish = now;
            for (int i = 0; i < nodeCount; i++) {
                publishMqttStatus(i);
            }
        }
    }
}

void initMQTT() {
    prepareTopics();

    MqttClient.setBufferSize(512);

    MqttClient.setServer(mqtt_server, mqtt_port);
    MqttClient.setCallback(mqttCallback); 
}
