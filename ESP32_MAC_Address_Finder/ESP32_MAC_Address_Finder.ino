#include "WiFi.h"

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println();
    Serial.println("===== ESP32 MAC Address Finder =====");

    // Get WiFi MAC address (same as BLE MAC address on ESP32)
    WiFi.mode(WIFI_MODE_STA);
    String macAddress = WiFi.macAddress();

    Serial.print("ESP32 MAC Address: ");
    Serial.println(macAddress);

    // Also show in different formats
    Serial.print("For Flutter code: \"");
    Serial.print(macAddress);
    Serial.println("\"");

    Serial.print("Uppercase format: ");
    macAddress.toUpperCase();
    Serial.println(macAddress);

    Serial.println("=====================================");
    Serial.println(
            "Copy the MAC address above and use it in your Flutter local_services.dart file");
}

void loop() {
    // Print MAC address every 10 seconds
    delay(10000);
    Serial.print("MAC Address: ");
    Serial.println(WiFi.macAddress());
}