#include <NimBLEDevice.h>
#include <Preferences.h>
#include <Arduino.h>

#define INFO_SERVICE_UUID "F000"
#define DEVICE_NAME_UUID "F001"
#define MANUFACTURER_UUID "F002"

#define SERVICE_UUID "FF01"
#define READ_FUNCTION_UUID "FF02"
#define WRITE_FUNCTION_UUID "FF03"

#define SENSOR_SERVICE_UUID "FA01"
#define CURRENT_FUNCTION_UUID "FA02"
#define VOLTAGE_FUNCTION_UUID "FA03"
#define POWER_FUNCTION_UUID "FA04"

#define WIFI_SERVICE_UUID "FB01"
#define WIFI_SSID_UUID "FB02"
#define WIFI_PASS_UUID "FB03"
#define WIFI_LIST_UUID "FB04"

bool SSID_recv = false;
bool PASS_recv = false;

std::string value = "Hello BLE";
static NimBLEServer *pServer;

// --- EXTERNAL VARIABLES FROM MAIN.CPP ---
extern Preferences prefs;
extern float curN, busN, powN;
extern struct LightingSet sets[];
extern void applyPWM(int set);
extern void applyRGB(int set);
extern String wifiList[];
extern int numNetworksFound;

const char* deviceID = "LIMI-Smart-Light";
const char* manufacturer = "LIMI";

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) {
        Serial.printf("BLE Client connected: %s\n", connInfo.getAddress().toString().c_str());
    }

    void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) {
        Serial.printf("BLE Client disconnected - restarting advertising\n");
        NimBLEDevice::startAdvertising();
    }
} serverCallbacks;

class LEDWriteCharCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pChar) {
        std::vector<uint8_t> rxBytes = pChar->getValue();
        if (rxBytes.empty()) return;

        std::string rxValue = std::string(rxBytes.begin(), rxBytes.end());
        String strValue = String(rxValue.c_str());
        strValue.trim();
        strValue.toLowerCase(); // Standardize for text matching

        // 1. HEX BYTE COMMAND PARSING (App Sliders & Color Pickers)
        if (rxBytes[0] == 0x01) { 
            // CCT Control: [0x01] [WW] [CW] [Brightness]
            Serial.printf("BLE CCT -> WW:%d CW:%d Bright:%d\n", rxBytes[1], rxBytes[2], rxBytes[3]);
            sets[0].mode = 1; 
            // Scale WW/CW by the brightness byte (0-255)
            sets[0].ww = (rxBytes[1] * rxBytes[3]) / 255;
            sets[0].cw = (rxBytes[2] * rxBytes[3]) / 255;
            applyPWM(0);
        }
        else if (rxBytes[0] == 0x02) { 
            // RGB Control: [0x02] [R] [G] [B] [Brightness]
            Serial.printf("BLE RGB -> R:%d G:%d B:%d Bright:%d\n", rxBytes[1], rxBytes[2], rxBytes[3], rxBytes[4]);
            sets[0].mode = 2;
            // Scale RGB by the brightness byte (0-255)
            sets[0].r = (rxBytes[1] * rxBytes[4]) / 255;
            sets[0].g = (rxBytes[2] * rxBytes[4]) / 255;
            sets[0].b = (rxBytes[3] * rxBytes[4]) / 255;
            applyRGB(0);
        }
        
        // 2. CSV PARSING ("50,100" or "255,0,0")
        else if (strValue.indexOf(",") != -1) {
            int firstComma = strValue.indexOf(",");
            int secondComma = strValue.indexOf(",", firstComma + 1);

            if (secondComma == -1) { // 2 Values: WW,CW
                sets[0].mode = 1;
                sets[0].ww = strValue.substring(0, firstComma).toInt();
                sets[0].cw = strValue.substring(firstComma + 1).toInt();
                applyPWM(0);
            } else { // 3 Values: R,G,B
                sets[0].mode = 2;
                sets[0].r = strValue.substring(0, firstComma).toInt();
                sets[0].g = strValue.substring(firstComma + 1, secondComma).toInt();
                sets[0].b = strValue.substring(secondComma + 1).toInt();
                applyRGB(0);
            }
        }
        
        // 3. TEXT COMMAND PARSING ("on", "off", "warm", "cool")
        else if (strValue == "on") {
            sets[0].mode = 1; sets[0].ww = 255; sets[0].cw = 255; applyPWM(0);
        } else if (strValue == "off") {
            sets[0].mode = 1; sets[0].ww = 0; sets[0].cw = 0; applyPWM(0);
        } else if (strValue == "cool") {
            sets[0].mode = 1; sets[0].ww = 0; sets[0].cw = 255; applyPWM(0);
        } else if (strValue == "warm") {
            sets[0].mode = 1; sets[0].ww = 255; sets[0].cw = 0; applyPWM(0);
        }
        
        // 4. SINGLE NUMBER PARSING (Assume CW only based on old code)
        else {
            bool isNum = true;
            for (int i=0; i<strValue.length(); i++) {
                if (!isDigit(strValue.charAt(i))) isNum = false;
            }
            if (isNum) {
                sets[0].mode = 1; sets[0].cw = strValue.toInt(); applyPWM(0);
            }
        }
    }
};

// --- SENSOR CALLBACKS ---
class readCurrentCharCallbacks : public BLECharacteristicCallbacks {
    void onRead(BLECharacteristic *pChar) {
        String curr = String(curN, 0) + "mA";
        pChar->setValue(curr.c_str());
    }
};

class readVoltageCharCallbacks : public BLECharacteristicCallbacks {
    void onRead(BLECharacteristic *pChar) {
        String volt = String(busN, 2) + "V";
        pChar->setValue(volt.c_str());
    }
};

class readPowerCharCallbacks : public BLECharacteristicCallbacks {
    void onRead(BLECharacteristic *pChar) {
        // Converting mW to W for the app
        String pwr = String(powN / 1000.0, 2) + "W"; 
        pChar->setValue(pwr.c_str());
    }
};

// --- WIFI PROVISIONING CALLBACKS ---
class SSIDCharCallbacks : public NimBLECharacteristicCallbacks {
    // Make sure onWrite has the new signature and the 'override' keyword
    void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {
        std::string rxValue = pChar->getValue();
        if (rxValue.length() > 0) {
            Serial.printf("BLE SSID Received: %s\n", rxValue.c_str());
            prefs.begin("wifi", false);
            prefs.putString("ssid", rxValue.c_str()); 
            prefs.end();
            SSID_recv = true;
            if (SSID_recv && PASS_recv) ESP.restart();
        }
    }
};

class PASSCharCallbacks : public NimBLECharacteristicCallbacks {
    // Update onRead signature
    void onRead(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {
        pChar->setValue("********");
    }
    
    // Update onWrite signature
    void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {
        std::string rxValue = pChar->getValue();
        if (rxValue.length() > 0) {
            Serial.println("BLE PASS Received: ********");
            // ---> TEMPORARY DEBUG PRINT: Shows actual password <---
            Serial.printf("BLE PASS Received: '%s'\n", rxValue.c_str());
            
            prefs.begin("wifi", false);
            prefs.putString("pass", rxValue.c_str()); 
            prefs.end();
            PASS_recv = true;
            if (SSID_recv && PASS_recv) ESP.restart(); 
        }
    }
};

class wifiListCharCallbacks : public NimBLECharacteristicCallbacks {
    // Added NimBLEConnInfo& connInfo to match the v2.0 library signature!
    void onRead(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {   
        Serial.println("Trying to send WiFi via BLE");
        String wifiListPayload = "[";
        for (int i = 0; i < numNetworksFound; i++) {  
            if (i > 0) wifiListPayload += ",";
            wifiListPayload += "\"" + wifiList[i] + "\""; 
        }
        wifiListPayload += "]";
        
        pChar->setValue((uint8_t*)wifiListPayload.c_str(), wifiListPayload.length());
        Serial.printf("BLE Sending Wi-Fi List (%d bytes): %s\n", wifiListPayload.length(), wifiListPayload.c_str());
    }
};

void initBLE() {
    NimBLEDevice::init("1 CH-HUB"); 
    NimBLEDevice::setMTU(512); // Request a larger packet size from iOS
    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(&serverCallbacks);

    // 1. INFO SERVICE
    NimBLEService *pInfoService = pServer->createService(INFO_SERVICE_UUID);
    NimBLECharacteristic *pDeviceNameChar = pInfoService->createCharacteristic(DEVICE_NAME_UUID, NIMBLE_PROPERTY::READ);
    pDeviceNameChar->setValue(deviceID);
    NimBLEDescriptor *pDescriptor = pDeviceNameChar->createDescriptor("1801", NIMBLE_PROPERTY::READ, 16);
    pDescriptor->setValue("Device Name");
    NimBLECharacteristic *pManufacturerChar = pInfoService->createCharacteristic(MANUFACTURER_UUID, NIMBLE_PROPERTY::READ);
    pManufacturerChar->setValue(manufacturer);
    pInfoService->start();

// 2. LED CONTROL SERVICE
    NimBLEService *pPWMService = pServer->createService(SERVICE_UUID);
    NimBLECharacteristic *pLedCodeChar = pPWMService->createCharacteristic("FF02", NIMBLE_PROPERTY::READ);
    
    // Send the exact 2-byte array the iOS app requires to unlock the UI
    // Byte 0: 91 (Normal Mode)
    // Byte 1: 0x01 (CCT) or 0x02 (RGB)
    byte appHandshake[2] = {91, (byte)((sets[0].mode == 1) ? 0x01 : 0x02)}; 
    pLedCodeChar->setValue(appHandshake, 2);

    NimBLECharacteristic *pWriteChar = pPWMService->createCharacteristic("FF03", NIMBLE_PROPERTY::WRITE);
    pWriteChar->setCallbacks(new LEDWriteCharCallbacks());
    pPWMService->start();


    // 3. SENSOR SERVICE
    NimBLEService *pSensorService = pServer->createService(SENSOR_SERVICE_UUID);
    NimBLECharacteristic *pReadCurrentChar = pSensorService->createCharacteristic(CURRENT_FUNCTION_UUID, NIMBLE_PROPERTY::READ);
    pReadCurrentChar->setCallbacks(new readCurrentCharCallbacks());
    
    NimBLECharacteristic *pReadVoltageChar = pSensorService->createCharacteristic(VOLTAGE_FUNCTION_UUID, NIMBLE_PROPERTY::READ);
    pReadVoltageChar->setCallbacks(new readVoltageCharCallbacks());
    
    NimBLECharacteristic *pReadPowerChar = pSensorService->createCharacteristic(POWER_FUNCTION_UUID, NIMBLE_PROPERTY::READ);
    pReadPowerChar->setCallbacks(new readPowerCharCallbacks());
    pSensorService->start();

    // 4. WIFI PROVISIONING SERVICE
    NimBLEService *pWifiService = pServer->createService(WIFI_SERVICE_UUID);
    NimBLECharacteristic *pSSIDChar = pWifiService->createCharacteristic(WIFI_SSID_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
    NimBLECharacteristic *pPASSChar = pWifiService->createCharacteristic(WIFI_PASS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
    NimBLECharacteristic *pWifiListChar = pWifiService->createCharacteristic(WIFI_LIST_UUID, NIMBLE_PROPERTY::READ);

    // Add the Notification ACK characteristic the iOS app expects!
    NimBLECharacteristic *pAckChar = pWifiService->createCharacteristic("FB05", NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
    byte ackReady[1] = {0x00};
    pAckChar->setValue(ackReady, 1);
    
    pSSIDChar->setCallbacks(new SSIDCharCallbacks());
    pPASSChar->setCallbacks(new PASSCharCallbacks());
    pWifiListChar->setCallbacks(new wifiListCharCallbacks());
    pWifiService->start();

    // START ADVERTISING
    NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->setName("1 CH-HUB");
    pAdvertising->addServiceUUID(pInfoService->getUUID());
    pAdvertising->addServiceUUID(pPWMService->getUUID());
    pAdvertising->addServiceUUID(pSensorService->getUUID());
    pAdvertising->addServiceUUID(pWifiService->getUUID());
    pAdvertising->start();

    Serial.println("BLE server ready. Waiting for LIMI App...");
}
