#pragma once
#include <ESPmDNS.h>
#include <Arduino_JSON.h>

// External references to your existing globals
extern AsyncWebServer server;
extern String getChipId();
extern struct LightingSet sets[];
extern uint8_t nodeCount; // Dynamic count of connected lights
extern void applyPWM(int set);
extern void applyRGB(int set);
extern void publishMqttStatus(int ch);

void setupLocalAPI() {
    // 1. START THE mDNS "BONJOUR" BROADCASTER
    String mac = getChipId();
    String deviceIdName = "limi1ch-" + mac; // Using "limi1ch" prefix as required by iOS app filter
    
    if (!MDNS.begin(deviceIdName.c_str())) {
        Serial.println("Error setting up MDNS responder!");
    } else {
        Serial.println("mDNS responder started successfully");
        MDNS.addService("_Limi1Ch", "_udp", 80);
        MDNS.addServiceTxt("_Limi1Ch", "_udp", "deviceId", deviceIdName);
        
        // 1. Broadcast the total number of lights
        MDNS.addServiceTxt("Limi1Ch", "udp", "channelCount", String(nodeCount));
        
        // 2. Dynamically build a list of what those lights actually are
        String channelTypes = "";
        for (int i = 0; i < nodeCount; i++) {
            if (i > 0) channelTypes += ","; // Add a comma between items
            
            // Assuming sets[i].mode holds the type (1 = CCT, 2 = RGB)
            if (sets[i].mode == 2) {
                channelTypes += "RGB";
            } else {
                channelTypes += "CCT";
            }
        }
        
        // 3. Broadcast the list to the iOS app!
        MDNS.addServiceTxt("Limi1Ch", "udp", "channelTypes", channelTypes);
    }

    // 2. SETUP THE HTTP GET ROUTE (/status)
    server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request){
        // For simplicity, we return the status of Channel 0. 
        // If the iOS dev updates the app to request specific channels (e.g., /status?channel=1), 
        // you can read request->getParam("channel") here later.
        int ch = 0; 
        
        JSONVar state;
        state["on"] = (sets[ch].cw > 0 || sets[ch].ww > 0 || sets[ch].r > 0 || sets[ch].g > 0 || sets[ch].b > 0);
        state["brightness"] = 255; // Placeholder, as raw PWM is stored
        
        if (sets[ch].mode == 2) {
            state["r"] = sets[ch].r;
            state["g"] = sets[ch].g;
            state["b"] = sets[ch].b;
        } else {
            // Rough approximation to send back to the app
            state["colorTemp"] = (sets[ch].cw > sets[ch].ww) ? 6500 : 2000;
        }
        
        JSONVar response;
        response["status"] = "success";
        response["state"] = state;
        
        request->send(200, "application/json", JSON.stringify(response));

        Serial.println("GET: status sent");
    });

    // 3. SETUP THE HTTP POST ROUTE (/control)
    server.on("/control", HTTP_POST, 
        [](AsyncWebServerRequest *request) {
            // Send success response back to iOS app instantly
            request->send(200, "application/json", "{\"status\":\"success\"}");
        },
        NULL, 
        [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
            Serial.println("POST: status sent");
            String body = "";
            for (size_t i = 0; i < len; i++) {
                body += (char)data[i];
            }
            
            JSONVar doc = JSON.parse(body);
            if (JSON.typeof(doc) == "undefined") {
                Serial.println("Failed to parse /control JSON");
                return;
            }

            // Figure out which channel the app is trying to control (Default to 0)
            int ch = 0;
            if (doc.hasOwnProperty("channel")) {
                ch = (int)doc["channel"];
            }
            
            // Safety check: Ensure the channel actually exists
            if (ch >= nodeCount) {
                Serial.printf("Local API -> Ignored command for unconnected channel %d\n", ch);
                return;
            }

            bool turnOn = true;
            if (doc.hasOwnProperty("on")) {
                turnOn = (bool)doc["on"];
            }

            // RGB Control Path
            if (doc.hasOwnProperty("r") && doc.hasOwnProperty("g") && doc.hasOwnProperty("b")) {
                sets[ch].mode = 2; // RGB Mode
                
                if (turnOn) {
                    int brightness = doc.hasOwnProperty("brightness") ? (int)doc["brightness"] : 255;
                    sets[ch].r = ((int)doc["r"] * brightness) / 255;
                    sets[ch].g = ((int)doc["g"] * brightness) / 255;
                    sets[ch].b = ((int)doc["b"] * brightness) / 255;
                } else {
                    sets[ch].r = 0; sets[ch].g = 0; sets[ch].b = 0;
                }
                
                Serial.printf("Local API -> Ch %d set to RGB: %d,%d,%d\n", ch, sets[ch].r, sets[ch].g, sets[ch].b);
                applyRGB(ch);
            } 
            // CCT Control Path
            else if (doc.hasOwnProperty("colorTemp")) {
                sets[ch].mode = 1; // CCT Mode
                
                if (turnOn) {
                    int colorTemp = (int)doc["colorTemp"];
                    int brightness = doc.hasOwnProperty("brightness") ? (int)doc["brightness"] : 255;
                    
                    int cw_raw = map(colorTemp, 2000, 6500, 0, 255);
                    cw_raw = constrain(cw_raw, 0, 255);
                    int ww_raw = 255 - cw_raw;

                    sets[ch].cw = (cw_raw * brightness) / 255;
                    sets[ch].ww = (ww_raw * brightness) / 255;
                } else {
                    sets[ch].cw = 0; sets[ch].ww = 0;
                }
                
                Serial.printf("Local API -> Ch %d set to CCT (CW:%d WW:%d)\n", ch, sets[ch].cw, sets[ch].ww);
                applyPWM(ch);
            }

            publishMqttStatus(ch); // Sync changes to the cloud
        }
    );
}