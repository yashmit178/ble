class ESP32ClassroomProfile {
  // Standard ESP32 BLE Service UUID (commonly used)
  // CRITICAL FIX: Match the ESP32's actual service UUID
  static String mainService = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static String controlChar = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Classroom automation commands
  static const int CMD_UNLOCK_DOOR = 0x01;
  static const int CMD_LOCK_DOOR = 0x02;
  static const int CMD_TURN_ON_PROJECTOR = 0x03;
  static const int CMD_TURN_OFF_PROJECTOR = 0x04;
  static const int CMD_TURN_ON_LIGHTS = 0x05;
  static const int CMD_TURN_OFF_LIGHTS = 0x06;
  static const int CMD_TURN_ON_AC = 0x07;
  static const int CMD_TURN_OFF_AC = 0x08;
  static const int CMD_CLASSROOM_SETUP = 0x10; // Combined: unlock + projector + lights
  static const int CMD_CLASSROOM_SHUTDOWN = 0x11; // Combined: lock + turn off all

  // Status responses from ESP32
  static const int STATUS_SUCCESS = 0x01;
  static const int STATUS_ERROR = 0x00;

  static List<int> createCommand(int commandType, {int duration = 0}) {
    /*
    ESP32 Classroom Protocol:
    Byte 1 = Header = 0xAA (start marker)
    Byte 2 = Command Type (0x01-0x11)
    Byte 3 = Duration (in minutes for time-based commands, 0 for instant)
    Byte 4 = Checksum = XOR of preceding bytes
    Byte 5 = Footer = 0x55 (end marker)
    */
    int header = 0xAA;
    int footer = 0x55;
    int checksum = header ^ commandType ^ duration;

    return [header, commandType, duration, checksum, footer];
  }

  static List<int> classroomSetupCommand(int durationMinutes) {
    return createCommand(CMD_CLASSROOM_SETUP, duration: durationMinutes);
  }

  static List<int> classroomShutdownCommand() {
    return createCommand(CMD_CLASSROOM_SHUTDOWN);
  }

  static List<int> unlockDoorCommand(int durationMinutes) {
    return createCommand(CMD_UNLOCK_DOOR, duration: durationMinutes);
  }

  static List<int> lockDoorCommand() {
    return createCommand(CMD_LOCK_DOOR);
  }

  static List<int> projectorOnCommand() {
    return createCommand(CMD_TURN_ON_PROJECTOR);
  }

  static List<int> projectorOffCommand() {
    return createCommand(CMD_TURN_OFF_PROJECTOR);
  }
}