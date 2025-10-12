#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include <IRremote.h>

// BLE UUIDs - MUST match Flutter app exactly
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Hardware pin definitions
#define DOOR_RELAY_PIN 2
#define PROJECTOR_IR_PIN 4
#define LIGHTS_RELAY_PIN 5
#define AC_RELAY_PIN 18
#define STATUS_LED_PIN 19  // Fixed: Changed from 2 to 19 to avoid pin conflict

// Classroom automation commands (must match Flutter app)
#define CMD_UNLOCK_DOOR 0x01
#define CMD_LOCK_DOOR 0x02
#define CMD_TURN_ON_PROJECTOR 0x03
#define CMD_TURN_OFF_PROJECTOR 0x04
#define CMD_TURN_ON_LIGHTS 0x05
#define CMD_TURN_OFF_LIGHTS 0x06
#define CMD_TURN_ON_AC 0x07
#define CMD_TURN_OFF_AC 0x08
#define CMD_CLASSROOM_SETUP 0x10
#define CMD_CLASSROOM_SHUTDOWN 0x11

// Protocol constants
#define PROTOCOL_HEADER 0xAA
#define PROTOCOL_FOOTER 0x55
#define COMMAND_LENGTH 5

// Global variables
BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
unsigned long autoLockTimer = 0;
bool autoLockEnabled = false;

// IR remote for projector control
IRsend irsend(PROJECTOR_IR_PIN);

// Function declarations
void handleClassroomCommand(uint8_t *command);

void performClassroomSetup(uint8_t duration);

void performClassroomShutdown();

void unlockDoor(uint8_t duration);

void lockDoor();

void turnOnProjector();

void turnOffProjector();

void turnOnLights();

void turnOffLights();

void turnOnAC();

void turnOffAC();

void sendResponse(uint8_t status);

void setupBLE();

// BLE Server Callbacks
class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *pServer) {
        deviceConnected = true;
        Serial.println("Device connected");
        digitalWrite(STATUS_LED_PIN, HIGH);
    };

    void onDisconnect(BLEServer *pServer) {
        deviceConnected = false;
        Serial.println("Device disconnected");
        digitalWrite(STATUS_LED_PIN, LOW);
    }
};

// BLE Characteristic Callbacks
class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        // Fix: Get the value properly for ESP32 BLE library
        String rxValue = pCharacteristic->getValue().c_str();

        if (rxValue.length() == COMMAND_LENGTH) {
            uint8_t command[COMMAND_LENGTH];
            for (int i = 0; i < COMMAND_LENGTH; i++) {
                command[i] = rxValue[i];
            }

            Serial.print("Received command: ");
            for (int i = 0; i < COMMAND_LENGTH; i++) {
                Serial.printf("%02X ", command[i]);
            }
            Serial.println();

            handleClassroomCommand(command);
        } else {
            Serial.printf("Invalid command length: %d (expected %d)\n", rxValue.length(),
                          COMMAND_LENGTH);
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("ESP32 Classroom Automation Starting...");

    // Initialize hardware pins
    pinMode(DOOR_RELAY_PIN, OUTPUT);
    pinMode(LIGHTS_RELAY_PIN, OUTPUT);
    pinMode(AC_RELAY_PIN, OUTPUT);
    pinMode(STATUS_LED_PIN, OUTPUT);

    // Initialize all devices to OFF state
    digitalWrite(DOOR_RELAY_PIN, LOW);   // Door locked
    digitalWrite(LIGHTS_RELAY_PIN, LOW); // Lights off
    digitalWrite(AC_RELAY_PIN, LOW);     // AC off
    digitalWrite(STATUS_LED_PIN, LOW);   // Status LED off

    // Initialize IR sender - Fix: provide the pin number
    irsend.begin(PROJECTOR_IR_PIN);

    // Initialize BLE
    setupBLE();

    Serial.println("Classroom automation ready!");
    Serial.println("Waiting for professor authentication...");
}

void setupBLE() {
    // Create BLE Device with classroom-specific name
    BLEDevice::init("ESP32_Classroom_A"); // Change per classroom

    // Create BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create BLE Service with defined UUID
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // Create BLE Characteristic with defined UUID and NOTIFY capability
    pCharacteristic = pService->createCharacteristic(
            CHARACTERISTIC_UUID,
            BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_WRITE |
                    BLECharacteristic::PROPERTY_NOTIFY
    );

    pCharacteristic->setCallbacks(new MyCallbacks());

    // Add descriptor for notifications (CRITICAL for Flutter BLE communication)
    pCharacteristic->addDescriptor(new BLE2902());

    // Start the service
    pService->start();

    // Start advertising with classroom-specific service UUID
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(false);
    pAdvertising->setMinPreferred(0x0);  // Set value to 0x00 to not advertise this parameter
    BLEDevice::startAdvertising();

    Serial.println("BLE Service started!");
    Serial.printf("Service UUID: %s\n", SERVICE_UUID);
    Serial.printf("Characteristic UUID: %s\n", CHARACTERISTIC_UUID);
    Serial.println("Waiting for professor's device to connect...");
}

void handleClassroomCommand(uint8_t *command) {
    // Validate protocol format
    if (command[0] != PROTOCOL_HEADER || command[4] != PROTOCOL_FOOTER) {
        Serial.println("Invalid protocol header/footer");
        sendResponse(0x00); // Error response
        return;
    }

    // Validate checksum
    uint8_t expectedChecksum = command[0] ^ command[1] ^ command[2];
    if (command[3] != expectedChecksum) {
        Serial.println("Invalid checksum");
        sendResponse(0x00); // Error response  
        return;
    }

    uint8_t cmdType = command[1];
    uint8_t duration = command[2];

    Serial.printf("Processing command: Type=0x%02X, Duration=%d minutes\n", cmdType, duration);

    switch (cmdType) {
        case CMD_CLASSROOM_SETUP:
            performClassroomSetup(duration);
            break;

        case CMD_CLASSROOM_SHUTDOWN:
            performClassroomShutdown();
            break;

        case CMD_UNLOCK_DOOR:
            unlockDoor(duration);
            break;

        case CMD_LOCK_DOOR:
            lockDoor();
            break;

        case CMD_TURN_ON_PROJECTOR:
            turnOnProjector();
            break;

        case CMD_TURN_OFF_PROJECTOR:
            turnOffProjector();
            break;

        case CMD_TURN_ON_LIGHTS:
            turnOnLights();
            break;

        case CMD_TURN_OFF_LIGHTS:
            turnOffLights();
            break;

        case CMD_TURN_ON_AC:
            turnOnAC();
            break;

        case CMD_TURN_OFF_AC:
            turnOffAC();
            break;

        default:
            Serial.printf("Unknown command: 0x%02X\n", cmdType);
            sendResponse(0x00); // Error response
            return;
    }

    sendResponse(0x01); // Success response
}

void performClassroomSetup(uint8_t duration) {
    Serial.printf("Setting up classroom for %d minutes (+10 buffer)\n", duration);

    // Unlock door
    digitalWrite(DOOR_RELAY_PIN, HIGH);
    Serial.println("✓ Door unlocked");

    // Turn on projector via IR
    turnOnProjector();

    // Turn on lights
    digitalWrite(LIGHTS_RELAY_PIN, HIGH);
    Serial.println("✓ Lights turned on");

    // Turn on AC (simplified - always on during class)
    digitalWrite(AC_RELAY_PIN, HIGH);
    Serial.println("✓ AC turned on");

    // Set auto-lock timer (duration + 10 minutes buffer)
    if (duration > 0) {
        autoLockTimer = millis() + ((duration + 10) * 60000UL); // Convert to milliseconds
        autoLockEnabled = true;
        Serial.printf("✓ Auto-lock timer set for %d minutes\n", duration + 10);
    }

    Serial.println("🎓 Classroom setup completed!");
}

void performClassroomShutdown() {
    Serial.println("Shutting down classroom...");

    // Lock door
    digitalWrite(DOOR_RELAY_PIN, LOW);
    Serial.println("✓ Door locked");

    // Turn off projector
    turnOffProjector();

    // Turn off lights
    digitalWrite(LIGHTS_RELAY_PIN, LOW);
    Serial.println("✓ Lights turned off");

    // Turn off AC
    digitalWrite(AC_RELAY_PIN, LOW);
    Serial.println("✓ AC turned off");

    // Disable auto-lock timer
    autoLockEnabled = false;
    autoLockTimer = 0;

    Serial.println("🔒 Classroom shutdown completed!");
}

void unlockDoor(uint8_t duration) {
    digitalWrite(DOOR_RELAY_PIN, HIGH);
    Serial.println("🚪 Door unlocked");

    if (duration > 0) {
        autoLockTimer = millis() + (duration * 60000UL);
        autoLockEnabled = true;
        Serial.printf("Auto-lock timer set for %d minutes\n", duration);
    }
}

void lockDoor() {
    digitalWrite(DOOR_RELAY_PIN, LOW);
    autoLockEnabled = false;
    Serial.println("🔒 Door locked");
}

void turnOnProjector() {
    // Send Sony projector power ON command (example)
    // Replace with your specific projector's IR codes
    irsend.sendSony(0xA90, 12); // Sony power code
    delay(100);
    Serial.println("📽️ Projector turned on");
}

void turnOffProjector() {
    // Send Sony projector power OFF command
    irsend.sendSony(0xA90, 12); // Sony power toggle
    delay(100);
    Serial.println("📽️ Projector turned off");
}

void turnOnLights() {
    digitalWrite(LIGHTS_RELAY_PIN, HIGH);
    Serial.println("💡 Lights turned on");
}

void turnOffLights() {
    digitalWrite(LIGHTS_RELAY_PIN, LOW);
    Serial.println("💡 Lights turned off");
}

void turnOnAC() {
    digitalWrite(AC_RELAY_PIN, HIGH);
    Serial.println("❄️ AC turned on");
}

void turnOffAC() {
    digitalWrite(AC_RELAY_PIN, LOW);
    Serial.println("❄️ AC turned off");
}

void sendResponse(uint8_t status) {
    // Send response back to Flutter app
    if (deviceConnected) {
        uint8_t response[2] = {status, status}; // Simple response format
        pCharacteristic->setValue(response, 2);
        pCharacteristic->notify();
        Serial.printf("Response sent: %02X\n", status);
    }
}

void loop() {
    // Handle BLE connection state changes
    if (!deviceConnected && oldDeviceConnected) {
        delay(500); // Give the bluetooth stack the chance to get things ready
        pServer->startAdvertising(); // Restart advertising
        Serial.println("Start advertising");
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }

    // Handle auto-lock timer
    if (autoLockEnabled && millis() > autoLockTimer) {
        Serial.println("⏰ Auto-lock timer expired - locking classroom");
        performClassroomShutdown();
    }

    // Optional: Add sensor readings, status updates, etc.
    delay(100);
}