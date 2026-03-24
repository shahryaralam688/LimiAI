#pragma once
#include "globals.h"
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <DNSServer.h>
#include "index.h" // Your HTML string

AsyncWebServer server(80);
AsyncWebSocket ws("/ws");
AsyncWebServer APserver(80);
DNSServer dnsServer;

extern Preferences prefs;
extern String saved_ssid;
extern String saved_pass;
extern bool apMode;

// done ... PASTE sendConfig(), sendNodeStatus(), sendSensors() HERE ...
void sendConfig() {
  JSONVar cfg;
  JSONVar arr;

  for (int i = 0; i < nodeCount; i++) {
    JSONVar s;
    s["id"] = nodes[i].setId;
    
// --- MAP INTEGERS TO STRINGS FOR THE UI ---
    if (sets[i].mode == 1) s["mode"] = "PWM";
    else if (sets[i].mode == 2) s["mode"] = "RGB";
    else if (sets[i].mode == 3) s["mode"] = "PATTERN";
    else s["mode"] = "PWM"; // Fallback

    s["ww"] = sets[i].ww; 
    s["cw"] = sets[i].cw;
    s["r"] = sets[i].r; 
    s["g"] = sets[i].g; 
    //s["b"] = sets[i].b;s["brightness"] = sets[i].brightness;
    s["pattern"] = sets[i].pattern; 
    s["speed"] = sets[i].speed;
    
    // Send Advanced Configs
    s["ledCount"] = sets[i].ledCount;
    s["instantOn"] = sets[i].instantOn;
    s["colorOrder"] = sets[i].colorOrder;
    s["balR"] = sets[i].balR;
    s["balG"] = sets[i].balG;
    s["balB"] = sets[i].balB;

    arr[i] = s;
  }
  cfg["sets"] = arr;
  ws.textAll(JSON.stringify(cfg));
}

void sendNodeStatus() {
  JSONVar root;
  JSONVar arr;

  for (int i = 0; i < nodeCount; i++) {
    LightingNode &n = nodes[i];
    JSONVar o;

    o["id"] = n.setId;
    o["addr"] = n.i2cAddr;
    o["online"] = n.online;

    if (n.online) {
      o["mode"] = (n.status.mode == 1) ? "PWM" : "RGB"; // 1 = CCT on the STM32
      o["adc"]  = n.status.adc_avg / 10.0;
      o["temp"] = n.status.temp; 
      o["fw"] = String(n.status.fw_major) + "." + String(n.status.fw_minor);
      o["errors"] = n.status.errors;
    }
    arr[i] = o;
  }
  root["nodes"] = arr;
  ws.textAll(JSON.stringify(root));
}

void sendSensors() {
  JSONVar s;
  s["bus"] = String(busN, 3);
  s["shu"] = String(shuN, 3);
  s["cur"] = String(curN, 1);
  s["pow"] = String(powN, 1);
  ws.textAll(JSON.stringify(s));
}


// done ... PASTE handleWebSocketMessage() HERE ...
void handleWebSocketMessage(void *arg, uint8_t *data, size_t len) {
  AwsFrameInfo *info = (AwsFrameInfo*)arg;
  if (!(info->final && info->index == 0 && info->opcode == WS_TEXT)) return;

  data[len] = 0;
  String msg = (char*)data;

  if (msg == "getConfig") { sendConfig(); return; }
  if (msg == "getSensors") { sendSensors(); return; }
  if (msg == "getNodes") { sendNodeStatus(); return; }

  JSONVar obj = JSON.parse(msg);
  if (JSON.typeof(obj) != "object") return;

  String type = (const char*)obj["type"];
  int set = (int)obj["set"];

  // Safety: Ensure set index is valid
  if (set >= nodeCount) return;

  // Mark this set as "active" to block the background poller from overwriting
  // local ESP32 variables while the user is interacting.
  lastUserAction[set] = millis();

  if (type == "setMode") {
    String modeStr = (const char*)obj["mode"];
    uint8_t targetMode = 1; // Default PWM (STM32 Mode 1)
    if (modeStr == "RGB") targetMode = 2;       // STM32 Mode 2
    if (modeStr == "PATTERN") targetMode = 3;   // Internal ESP32 logic for Patterns

    if (sets[set].mode != targetMode) {
      sets[set].mode = targetMode;
      
      if (targetMode == 1) applyPWM(set);
      else if (targetMode == 2) applyRGB(set);
      else applyPattern(set);

      // CRITICAL: Tell the UI to refresh its layout (sliders vs dropdowns)
      sendConfig(); 
    }
    return;
  }

  if (type == "pwm") {
    String ch = (const char*)obj["channel"];
    int val = (int)obj["value"];
    bool changed = false;

    if (ch == "WW" && sets[set].ww != val) { sets[set].ww = val; changed = true; }
    if (ch == "CW" && sets[set].cw != val) { sets[set].cw = val; changed = true; }

    if (changed) applyPWM(set);
    return;
  }

  if (type == "rgb") {
    String ch = (const char*)obj["channel"];
    int val = (int)obj["value"];
    bool changed = false;

    if (ch == "R" && sets[set].r != val) { sets[set].r = val; changed = true; }
    if (ch == "G" && sets[set].g != val) { sets[set].g = val; changed = true; }
    if (ch == "B" && sets[set].b != val) { sets[set].b = val; changed = true; }

    if (changed) applyRGB(set);
    return;
  }

  if (type == "pattern") {
    String ch = (const char*)obj["channel"];
    int val = (int)obj["value"];
    bool changed = false;

    if (ch == "PAT" && sets[set].pattern != val) { sets[set].pattern = val; changed = true; }
    if (ch == "SPD" && sets[set].speed != val)   { sets[set].speed = val;   changed = true; }
    if (ch == "R" && sets[set].r != val)         { sets[set].r = val;       changed = true; }
    if (ch == "G" && sets[set].g != val)         { sets[set].g = val;       changed = true; }
    if (ch == "B" && sets[set].b != val)         { sets[set].b = val;       changed = true; }

    if (changed) applyPattern(set);
    return;
  }

  if (type == "adv") {
    String ch = (const char*)obj["channel"];
    int val = (int)obj["value"];

    if (ch == "LEDS") {
      sets[set].ledCount = val;
      sendLedCount(set, val);
    }
    else if (ch == "INST") {
      sets[set].instantOn = val;
      sendInstantOn(set, val);
    }
    else if (ch == "ORD" || ch == "BR" || ch == "BG" || ch == "BB") {
      if (ch == "ORD") sets[set].colorOrder = val;
      else if (ch == "BR") sets[set].balR = val;
      else if (ch == "BG") sets[set].balG = val;
      else if (ch == "BB") sets[set].balB = val;
      sendColorConfig(set, sets[set].colorOrder, sets[set].balR, sets[set].balG, sets[set].balB);
    }
    return;
  }
  
  if (type == "trigger") {
      String cmd = (const char*)obj["cmd"];
      if (cmd == "DIAG") sendDiagnosticRequest(set);
      return;
  }
}

// done ... PASTE onEvent() and initWebSocket() HERE ...
void onEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
  switch (type) {
    case WS_EVT_CONNECT: Serial.printf("WS Client connected\n"); break;
    case WS_EVT_DISCONNECT: Serial.printf("WS Client disconnected\n"); break;
    case WS_EVT_DATA: handleWebSocketMessage(arg, data, len); break;
    case WS_EVT_PONG:
    case WS_EVT_ERROR: break;
  }
}

void initWebSocket() {
  ws.onEvent(onEvent);
  server.addHandler(&ws);
} 

// done ... PASTE scanForNetworks() HERE ...
// network scan prior to starting BLE
void scanForNetworks() {
    Serial.println("WiFi not working. Scanning for networks...");
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);

    numNetworksFound = WiFi.scanNetworks();
    if (numNetworksFound == 0) {
        Serial.println("No networks found.");
    } else {
        Serial.printf("%d networks found.\n", numNetworksFound);
        // Cap it at MAX_WIFI to prevent array overflow
        if (numNetworksFound > MAX_WIFI) numNetworksFound = MAX_WIFI;
        
        for (int i = 0; i < numNetworksFound; i++) {
            wifiList[i] = WiFi.SSID(i);
            Serial.printf("%d: %s\n", i + 1, wifiList[i].c_str());
        }
    }
}

// done ... PASTE connectToWiFi() and startCaptivePortal() HERE ...
// wifi start - if it fails, start captive portal process
bool connectToWiFi() {
  if (saved_ssid.isEmpty()) return false; 
  WiFi.mode(WIFI_STA);
  WiFi.begin(saved_ssid.c_str(), saved_pass.c_str());
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_TIMEOUT) {
    Serial.print(".");
    delay(250);
  }
  return (WiFi.status() == WL_CONNECTED); 
}

void startCaptivePortal() { 
  apMode = true;

  WiFi.disconnect(true);
  WiFi.mode(WIFI_AP);
  delay(100);
  WiFi.setSleep(false);
  WiFi.softAP(AP_SSID);
  Serial.println("Set up portal");

  IPAddress apIP = WiFi.softAPIP();
  Serial.println(apIP);
  dnsServer.start(DNS_PORT, "*", apIP);
  Serial.println("set up DNS server");

  APserver.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html", index_html);
  });

  APserver.on("/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (!request->hasParam("ssid", true) ||
        !request->hasParam("password", true)) {
      request->send(400, "application/json", "{\"error\":\"missing fields\"}");
      return;
    }

    String ssid = request->getParam("ssid", true)->value();
    String pass = request->getParam("password", true)->value();

    prefs.begin("wifi", false);
    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);
    prefs.end();

    JSONVar resp;
    resp["status"] = "saved";
    request->send(200, "application/json", JSON.stringify(resp));

    delay(500);
    ESP.restart();
  });

  APserver.onNotFound([](AsyncWebServerRequest *request) {
    request->redirect("/");
  });

  APserver.begin();
}
