#pragma once
#include "globals.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Update.h>
//#include <HTTPUpdate.h>
#include <Arduino_JSON.h>
#include <mbedtls/md5.h>

#include <time.h>

#define UPDATE_URL "https://dev.api.limitless-lighting.co.uk/admin/ota/latest"
#define CURRENT_ESP_VERSION "1.0.1"

#define STM_BOOTLOADER_ADDR 0x72
#define SLOT_B_ADDR 0x0800F000
#define CHUNK_SIZE  64 

String ESP_OTA_URL = "";
String STM_OTA_URL = "";
String ESP_MD5 = "";
String STM_MD5 = "";
bool espUpdateAvailable = false;
bool stmUpdateAvailable = false;

// --- GLOBAL TIMERS ---
unsigned long lastRecoveryCheck = 0;
unsigned long lastCacheUpdate = 0;     // Tracks when we last pinged the API for the cache
unsigned long lastOTAProgressPrint = 0; // Tracks the serial print spam during ESP32 flash

// --- IN-MEMORY FIRMWARE CACHE ---
uint8_t* stm_fw_cache = NULL;
size_t stm_fw_cache_len = 0;

extern void i2cScan();
void printDeviceVersions();


// Assuming you got this offset from your app or your backend.
// Example: New York is UTC-5. (-5 * 60 * 60 = -18000 seconds)
long utcOffsetSeconds = 0; // default zero offset, can be changed by backend API in future.

int targetOtaHour = 11;      // 11 AM Local Time
int targetOtaMinute = -1;    // Will be randomized at boot
int lastOtaDay = -1;         

void setupOtaSchedule() {
    // Configure NTP using free Google and Pool servers.
    // We pass the raw offset in seconds here!
    configTime(utcOffsetSeconds, 0, "pool.ntp.org", "time.google.com");

    randomSeed(esp_random()); 
    targetOtaMinute = random(0, 60); 
    Serial.printf("[OTA] Daily check scheduled for %02d:%02d Local Time\n", targetOtaHour, targetOtaMinute);
}

void handleScheduledOTA() {
    struct tm timeinfo;
    // getLocalTime automatically applies the utcOffsetSeconds we set above!
    if (!getLocalTime(&timeinfo)) {
        return; // Time hasn't synced from the internet yet, skip
    }

    // THE DAILY STAGGERED 11 AM CHECK
    if (timeinfo.tm_hour == targetOtaHour && timeinfo.tm_min >= targetOtaMinute) {
        if (lastOtaDay != timeinfo.tm_mday) {
            lastOtaDay = timeinfo.tm_mday; // Lock it in so it doesn't run again today
            
            Serial.printf("\n[OTA] Performing SCHEDULED daytime update check (%02d:%02d)...\n", timeinfo.tm_hour, timeinfo.tm_min);
            executeOTASequence();
        }
    }
}

// ==========================================
// 1. API COMMUNICATION
// ==========================================
String httpPostRequest(const char* url, String payload) {
    WiFiClientSecure client;
    client.setInsecure(); 
    HTTPClient http;
    
    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    
    int httpResponseCode = http.POST(payload);
    String response = (httpResponseCode > 0) ? http.getString() : "";
    
    if (httpResponseCode <= 0) {
        Serial.printf("[OTA] HTTP POST Request failed. Error: %d\n", httpResponseCode);
    }
    
    http.end();
    return response;
}

bool checkOTAUpdate() {
    Serial.println("[OTA] Checking API for firmware updates...");
    
    JSONVar requestPayload;
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    requestPayload["macAddress"] = mac; 
    requestPayload["espVersion"] = CURRENT_ESP_VERSION;
    
    if (nodeCount > 0) {
        requestPayload["stmVersion"] = String(nodes[0].status.fw_major) + "." + String(nodes[0].status.fw_minor);
    } else {
        requestPayload["stmVersion"] = "0.0"; 
    }

    String jsonData = httpPostRequest(UPDATE_URL, JSON.stringify(requestPayload));
    if (jsonData == "") return false;

    JSONVar doc = JSON.parse(jsonData);
    if (JSON.typeof(doc) == "undefined" || !(bool)doc["success"]) return false;

    JSONVar data = doc["data"];
    espUpdateAvailable = false;
    stmUpdateAvailable = false;

    // Safely check and extract ESP32 URL and MD5
    if (data.hasOwnProperty("espFileUrl") && JSON.typeof(data["espFileUrl"]) == "string") {
        String url = (const char*)data["espFileUrl"];
        if (url.length() > 10) { // Ensure it's a real URL, not just ""
            ESP_OTA_URL = url;
            espUpdateAvailable = true;
            Serial.println("[OTA] ESP32 Update Available!");
            
            if (data.hasOwnProperty("esp_md5") && JSON.typeof(data["esp_md5"]) == "string") {
                ESP_MD5 = (const char*)data["esp_md5"];
            }
        }
    }

    // Safely check and extract STM32 URL and MD5
    if (data.hasOwnProperty("stmFileUrl") && JSON.typeof(data["stmFileUrl"]) == "string") {
        String url = (const char*)data["stmFileUrl"];
        if (url.length() > 10) {
            STM_OTA_URL = url;
            stmUpdateAvailable = true;
            Serial.println("[OTA] STM32 Update Available!");
            
            if (data.hasOwnProperty("stm_md5") && JSON.typeof(data["stm_md5"]) == "string") {
                STM_MD5 = (const char*)data["stm_md5"];
            }
        }
    }
    
    return (espUpdateAvailable || stmUpdateAvailable);
}

bool verifyMD5(const uint8_t* payload, size_t len, String expected_md5) {
    if (expected_md5 == "" || expected_md5.length() != 32) {
        Serial.println("[OTA] Warning: No valid MD5 provided by backend. Skipping check.");
        return true; // Proceed anyway if backend didn't send a valid MD5
    }

    mbedtls_md5_context ctx;
    mbedtls_md5_init(&ctx);
    mbedtls_md5_starts(&ctx);                   // Removed _ret
    mbedtls_md5_update(&ctx, payload, len);     // Removed _ret
    
    byte md5_result[16];
    mbedtls_md5_finish(&ctx, md5_result);       // Removed _ret
    mbedtls_md5_free(&ctx);

    // Convert the 16-byte result into a 32-character Hex String
    String calculated_md5 = "";
    for(int i = 0; i < 16; i++) {
        char hex[3];
        sprintf(hex, "%02x", md5_result[i]);
        calculated_md5 += hex;
    }

    // Force both to lowercase for a safe comparison
    expected_md5.toLowerCase();
    calculated_md5.toLowerCase();

    if (calculated_md5 == expected_md5) {
        Serial.printf("[OTA] MD5 Verified Successfully! (%s)\n", calculated_md5.c_str());
        return true;
    } else {
        Serial.printf("[OTA] MD5 MISMATCH! \n  Expected: %s \n  Calculated: %s\n", expected_md5.c_str(), calculated_md5.c_str());
        return false;
    }
}

// ==========================================
// 2. RAM CACHE FIRMWARE DOWNLOADER
// ==========================================
bool downloadToCache(String url) {
    Serial.println("\n[OTA] Downloading STM32 Firmware into ESP32 RAM Cache...");
    Serial.print("[OTA] Target URL: ");
    Serial.println(url);

    // Create both clients, but only use the one we need
    WiFiClient client;
    WiFiClientSecure clientSecure;
    HTTPClient http;
    http.setTimeout(7000); // Add this: 7 second timeout so it aborts if the server stalls
    
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    // Dynamically choose the right client based on the URL
    if (url.startsWith("https")) {
        Serial.println("[OTA] Using Secure Client (HTTPS)");
        clientSecure.setInsecure(); 
        http.begin(clientSecure, url);
    } else {
        Serial.println("[OTA] Using Standard Client (HTTP)");
        http.begin(client, url);
    }
    
    int httpCode = http.GET();
    
    if (httpCode != HTTP_CODE_OK) {
        Serial.printf("[OTA] Failed to download. HTTP Code: %d\n", httpCode);
        if (httpCode < 0) {
            Serial.printf("[OTA] Internal Error: %s\n", http.errorToString(httpCode).c_str());
        }
        http.end();
        return false;
    }

    size_t actual_len = http.getSize();
    size_t padded_len = ((actual_len + 2047) / 2048) * 2048; 
    
    uint8_t* new_buffer = (uint8_t*)malloc(padded_len);
    if (new_buffer == NULL) {
        Serial.println("[OTA] ESP32 out of memory! Cannot buffer STM32 firmware.");
        http.end();
        return false;
    }

    WiFiClient* stream = http.getStreamPtr();
    size_t written = 0;
    while (http.connected() && (written < actual_len)) {
        size_t available = stream->available();
        if (available) {
            int bytesRead = stream->readBytes(&new_buffer[written], available);
            written += bytesRead;
        }
        delay(1);
    }
    http.end();

    if (written != actual_len) {
        Serial.println("[OTA] Download interrupted.");
        free(new_buffer);
        return false;
    }

    // === NEW: PERFORM MD5 CHECK BEFORE PADDING ===
    // We check against 'actual_len' because the backend hashed the unpadded file
    if (!verifyMD5(new_buffer, actual_len, STM_MD5)) {
        Serial.println("[OTA] Firmware corrupted during download. Discarding cache.");
        free(new_buffer);
        return false; 
    }
    // =============================================

    // If MD5 passes, apply the 2048-byte alignment padding for the STM32 flasher
    for (size_t i = actual_len; i < padded_len; i++) new_buffer[i] = 0xAA;

    if (stm_fw_cache != NULL) free(stm_fw_cache);
    stm_fw_cache = new_buffer;
    stm_fw_cache_len = padded_len;

    lastCacheUpdate = millis(); 
    if (lastCacheUpdate == 0) lastCacheUpdate = 1; // Prevent it from getting stuck on 0

    Serial.printf("[OTA] Download Success & Verified. %d bytes Locked in RAM Cache.\n", stm_fw_cache_len);
    return true;
}

// Smart Background Task: 
// Tries to fetch at boot. If it fails, retries every 5 mins. If it succeeds, checks again in 10 hours.
void ensureStmCache() {
    if (WiFi.status() != WL_CONNECTED) return; 
    
    // 5 minutes if cache is empty, 10 hours if cache is full
    unsigned long interval = (stm_fw_cache == NULL) ? 300000 : 36000000; 

    if (lastCacheUpdate == 0 || (millis() - lastCacheUpdate > interval)) {
        lastCacheUpdate = millis();
        if (lastCacheUpdate == 0) lastCacheUpdate = 1; // Safety to prevent re-triggering at exactly 0
        
        Serial.println("[OTA] Fetching latest STM32 firmware for Offline Recovery Cache...");
        
        JSONVar requestPayload;
        String mac = WiFi.macAddress();
        mac.replace(":", "");
        requestPayload["macAddress"] = mac; 
        requestPayload["espVersion"] = CURRENT_ESP_VERSION;
        requestPayload["stmVersion"] = "0.0"; // Force API to yield the URL
        
        String jsonData = httpPostRequest(UPDATE_URL, JSON.stringify(requestPayload));
        if (jsonData == "") return;

        JSONVar doc = JSON.parse(jsonData);
        if (JSON.typeof(doc) != "undefined" && (bool)doc["success"]) {
            JSONVar data = doc["data"];
            if (data.hasOwnProperty("stmFileUrl")) {
                downloadToCache((const char*)data["stmFileUrl"]);
            }
        }
    }
}

// ==========================================
// 3. STM32 I2C FLASHER CORE
// ==========================================
uint32_t calc_stm32_crc(const uint8_t *data, size_t len) {
    uint32_t crc = 0xFFFFFFFF; 
    for (size_t i = 0; i < len; i += 4) {
        uint32_t word = 0;
        for (int j = 0; j < 4; j++) {
            if (i + j < len) word |= ((uint32_t)data[i + j]) << (8 * j);
        }
        crc ^= word;
        for (int bit = 0; bit < 32; bit++) {
            if (crc & 0x80000000) crc = (crc << 1) ^ 0x04C11DB7; 
            else crc = (crc << 1);
        }
    }
    return crc;
}

void send_chunk(uint8_t target_addr, uint32_t addr, const uint8_t* data, uint8_t len) {
    Wire.beginTransmission(target_addr);
    Wire.write(0x10); 
    Wire.write((uint8_t)(addr & 0xFF));
    Wire.write((uint8_t)((addr >> 8) & 0xFF));
    Wire.write((uint8_t)((addr >> 16) & 0xFF));
    Wire.write((uint8_t)((addr >> 24) & 0xFF));
    Wire.write(data, len);
    
    byte error = Wire.endTransmission();
    if (error != 0) {
        Serial.printf("\n[OTA-STM32] I2C Write Failed at 0x%X (Err: %d)\n", addr, error);
    }

    if ((addr % 2048) == 0) delay(30); 
    else delay(10);  
}

bool flash_single_stm32(uint8_t target_addr, const uint8_t* fw_data, size_t total_len) {
    Serial.printf("\n[OTA-STM32] Targeting Bulb at I2C 0x%02X\n", target_addr);
    
    if (target_addr != STM_BOOTLOADER_ADDR) { 
        Wire.beginTransmission(target_addr);
        Wire.write(0x99); // Command to reboot into bootloader
        Wire.endTransmission();
        Serial.print("[OTA-STM32] Reboot commanded. Waiting for bootloader to wake up.");
        
        // --- THE POLLING LOOP ---
        // Knock on the I2C address every 100ms, up to 40 times (4 seconds total)
        bool bootloader_ready = false;
        for (int i = 0; i < 40; i++) {
            delay(100);
            Serial.print(".");
            
            Wire.beginTransmission(target_addr);
            if (Wire.endTransmission() == 0) { // 0 means we received an ACK!
                bootloader_ready = true;
                Serial.println(" Online!");
                break; 
            }
        }

        if (!bootloader_ready) {
            Serial.printf("\n[OTA-STM32] ERROR: Bootloader never woke up at 0x%02X!\n", target_addr);
            return false;
        }
        
    } else {
        // If it's already at the 0x72 rescue address, just do a quick sanity check
        Wire.beginTransmission(target_addr);
        if (Wire.endTransmission() != 0) {
            Serial.printf("[OTA-STM32] ERROR: Rescue Bootloader not responding at 0x%02X!\n", target_addr);
            return false;
        }
    }

    Serial.printf("[OTA-STM32] Bootloader ready! Flashing %d bytes to Slot B...\n", total_len);
    uint32_t current_addr = SLOT_B_ADDR;
    int remaining = total_len;
    int offset = 0;
    
    while(remaining > 0) {
        int c = (remaining > CHUNK_SIZE) ? CHUNK_SIZE : remaining;
        send_chunk(target_addr, current_addr, &fw_data[offset], c);
        current_addr += c;
        offset += c;
        remaining -= c;
        if (offset % 2048 == 0) Serial.print("."); 
    }
    Serial.println("\n[OTA-STM32] Write Complete.");

    struct {
        uint32_t magic;
        uint32_t update_pending;
        uint32_t image_size;
        uint32_t image_crc;
    } cfg;
    
    cfg.magic = 0xDEADBEEF;
    cfg.update_pending = 1;     
    cfg.image_size = total_len;
    cfg.image_crc = calc_stm32_crc(fw_data, total_len);         

    Wire.beginTransmission(target_addr);
    Wire.write(0x30); 
    Wire.write((uint8_t*)&cfg, sizeof(cfg));
    if (Wire.endTransmission() != 0) return false;
    delay(50); 
    
    Serial.println("[OTA-STM32] Commanding Slot-Swap Reset...");
    Wire.beginTransmission(target_addr);
    Wire.write(0x40); 
    Wire.endTransmission();
    
    // Give it time to copy the partition and boot back into the app before the ESP32 scans again
    delay(2000); 
    return true;
}

/*
bool flash_single_stm32(uint8_t target_addr, const uint8_t* fw_data, size_t total_len) {
    Serial.printf("\n[OTA-STM32] Targeting Bulb at I2C 0x%02X\n", target_addr);
    
    if (target_addr != STM_BOOTLOADER_ADDR) { // if the STM32 is at 0x72, we know it's broken and ready for an update without needing to set a flag and reboot it
        Wire.beginTransmission(target_addr);
        Wire.write(0x99); 
        Wire.endTransmission();
        Serial.println("[OTA-STM32] Waiting 1.5s for bootloader...");
        delay(1500); 
    }
    
    Wire.beginTransmission(target_addr);
    if (Wire.endTransmission() != 0) {
        Serial.printf("[OTA-STM32] ERROR: Bootloader not responding at 0x%02X!\n", target_addr);
        return false;
    }

    Serial.printf("[OTA-STM32] Flashing %d bytes to Slot B...\n", total_len);
    uint32_t current_addr = SLOT_B_ADDR;
    int remaining = total_len;
    int offset = 0;
    
    while(remaining > 0) {
        int c = (remaining > CHUNK_SIZE) ? CHUNK_SIZE : remaining;
        send_chunk(target_addr, current_addr, &fw_data[offset], c);
        current_addr += c;
        offset += c;
        remaining -= c;
        if (offset % 2048 == 0) Serial.print("."); 
    }
    Serial.println("\n[OTA-STM32] Write Complete.");

    struct {
        uint32_t magic;
        uint32_t update_pending;
        uint32_t image_size;
        uint32_t image_crc;
    } cfg;
    
    cfg.magic = 0xDEADBEEF;
    cfg.update_pending = 1;     
    cfg.image_size = total_len;
    cfg.image_crc = calc_stm32_crc(fw_data, total_len);         

    Wire.beginTransmission(target_addr);
    Wire.write(0x30); 
    Wire.write((uint8_t*)&cfg, sizeof(cfg));
    if (Wire.endTransmission() != 0) return false;
    delay(50); 
    
    Serial.println("[OTA-STM32] Commanding Slot-Swap Reset...");
    Wire.beginTransmission(target_addr);
    Wire.write(0x40); 
    Wire.endTransmission();
    
    delay(1500); 
    return true;
}
*/


// ==========================================
// 4. ESP32 NATIVE FLASHER
// ==========================================
void performEspOTA() {   
    Serial.println("\n[OTA] Starting Native ESP32 update...");
    Serial.print("[OTA-ESP] Target URL: ");
    Serial.println(ESP_OTA_URL);

    // Create both clients, but only use the one we need
    WiFiClient client;
    WiFiClientSecure clientSecure;
    HTTPClient http;
    http.setTimeout(7000); // Add this: 7 second timeout so it aborts if the server stalls
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

    // Dynamically choose the right client based on the URL
    if (ESP_OTA_URL.startsWith("https")) {
        Serial.println("[OTA-ESP] Using Secure Client (HTTPS)");
        clientSecure.setInsecure(); 
        http.begin(clientSecure, ESP_OTA_URL);
    } else {
        Serial.println("[OTA-ESP] Using Standard Client (HTTP)");
        http.begin(client, ESP_OTA_URL);
    }
    
    int httpCode = http.GET();
    
    if (httpCode != HTTP_CODE_OK) {
        Serial.printf("[OTA-ESP] Failed to connect to URL. HTTP Code: %d\n", httpCode);
        if (httpCode < 0) {
            Serial.printf("[OTA-ESP] Internal Error: %s\n", http.errorToString(httpCode).c_str());
        }
        http.end();
        return;
    }

    int contentLength = http.getSize();
    
    // Attach your globally-timed progress callback
    Update.onProgress([](size_t cur, size_t total) {
        if (millis() - lastOTAProgressPrint > 1000) {
            Serial.printf("[OTA-ESP] Progress: %d / %d bytes (%.1f%%)\n", cur, total, (cur * 100.0) / total);
            lastOTAProgressPrint = millis();
        }
    });

    // Request space in the inactive partition
    if (!Update.begin(contentLength)) {
        Serial.println("[OTA-ESP] Not enough space in partition to begin OTA");
        http.end();
        return;
    }

    // === INJECT THE MD5 FROM THE BACKEND API ===
    if (ESP_MD5 != "" && ESP_MD5.length() == 32) {
        ESP_MD5.toLowerCase();
        Update.setMD5(ESP_MD5.c_str());
        Serial.printf("[OTA-ESP] Expecting MD5: %s\n", ESP_MD5.c_str());
    }
    // ===========================================

    Serial.println("[OTA-ESP] Downloading and Flashing...");
    
    // http.getStream() automatically uses whichever client we started the connection with
    size_t written = Update.writeStream(http.getStream());

    if (written == contentLength) {
        Serial.println("[OTA-ESP] Stream complete. Verifying MD5 Hash...");
    } else {
        Serial.printf("[OTA-ESP] Stream interrupted! Written: %d / %d \n", written, contentLength);
    }

    // Update.end() automatically calculates the MD5 of the downloaded stream 
    // and compares it to the one we set above. It fails if they don't match.
    if (Update.end()) {
        Serial.println("[OTA-ESP] Update successful and cryptographically verified! Rebooting...");
        delay(1000);
        ESP.restart();
    } else {
        Serial.printf("[OTA-ESP] Update failed (MD5 Mismatch or Write Error). Error Code: %d\n", Update.getError());
    }
    
    http.end();
}

// ==========================================
// 5. MASTER OTA SEQUENCE CONTROLLERS
// ==========================================
void executeOTASequence() {
    if (checkOTAUpdate()) {
        
        // Flash active Swarm Nodes
        if (stmUpdateAvailable && STM_OTA_URL != "") {
            if (downloadToCache(STM_OTA_URL)) {
                
                // --- NEW DEBUG LINES ---
                Serial.printf("\n[OTA-DEBUG] Ready to flash STM32s. Total nodeCount: %d\n", nodeCount);
                if (nodeCount == 0) {
                    Serial.println("[OTA-DEBUG] WARNING: nodeCount is 0! Skipping flash loop. Did i2cScan() run?");
                }
                // -----------------------

                for (int i = 0; i < nodeCount; i++) {
                    Serial.printf("[OTA-DEBUG] Checking Node %d (I2C: 0x%02X) - Online: %s\n", 
                                  i, nodes[i].i2cAddr, nodes[i].online ? "YES" : "NO");
                                  
                    if (nodes[i].online) {
                        flash_single_stm32(nodes[i].i2cAddr, stm_fw_cache, stm_fw_cache_len);
                    } else {
                        Serial.printf("[OTA-DEBUG] Skipping Node %d because it is marked offline.\n", i);
                    }
                }
            }
        }

        // Flash Master ESP32
        if (espUpdateAvailable && ESP_OTA_URL != "") {
            performEspOTA(); 
        }
        
        if (stmUpdateAvailable && !espUpdateAvailable) {
            Serial.println("[OTA] Rescanning I2C bus to map updated STM32 addresses...");
            i2cScan();
            printDeviceVersions();
        }
    }
}

// --- EMERGENCY OFFLINE RECOVERY ---
void handleOTARecoveryTask() {
    // Check for a bricked node every 10 seconds. DOES NOT REQUIRE WI-FI!
    if (millis() - lastRecoveryCheck > 10000) {
        lastRecoveryCheck = millis();
        
        Wire.beginTransmission(STM_BOOTLOADER_ADDR);
        if (Wire.endTransmission() == 0) {
            Serial.println("\n[EMERGENCY] STM32 detected at recovery address 0x72!");
            
            if (stm_fw_cache == NULL) {
                Serial.println("[EMERGENCY] No firmware in RAM cache! Waiting for Wi-Fi to fetch it...");
                return; 
            }

            Serial.println("[EMERGENCY] Initiating Offline Recovery Flash from RAM Cache...");
            bool success = flash_single_stm32(STM_BOOTLOADER_ADDR, stm_fw_cache, stm_fw_cache_len);
            
            if (success) {
                Serial.println("[EMERGENCY] Recovery successful. Rescanning bus...");
                i2cScan(); 
                printDeviceVersions();
            }
        }
    }
}
