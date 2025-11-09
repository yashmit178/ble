class ESP32ClassroomProfile {
  // ESP32 BLE Service UUID (matches ESP32 code)
  static String mainService = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static String controlChar = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Classroom automation commands (must match ESP32 code)
  static const int CMD_UNLOCK_DOOR = 0x01;
  static const int CMD_LOCK_DOOR = 0x02;
  static const int CMD_TURN_ON_PROJECTOR = 0x03;
  static const int CMD_TURN_OFF_PROJECTOR = 0x04;
  static const int CMD_TURN_ON_LIGHTS = 0x05;
  static const int CMD_TURN_OFF_LIGHTS = 0x06;
  static const int CMD_TURN_ON_AC = 0x07;
  static const int CMD_TURN_OFF_AC = 0x08;
  static const int CMD_CLASSROOM_SETUP = 0x10;
  static const int CMD_CLASSROOM_SHUTDOWN = 0x11;

  // Protocol constants
  static const int PROTOCOL_HEADER = 0xAA;
  static const int PROTOCOL_FOOTER = 0x55;

  // Helper method to create ESP32 classroom commands
  static List<int> _createCommand(int commandType, int duration) {
    int checksum = PROTOCOL_HEADER ^ commandType ^ duration;
    return [PROTOCOL_HEADER, commandType, duration, checksum, PROTOCOL_FOOTER];
  }

  // Classroom control commands
  static List<int> classroomSetupCommand(int duration) {
    return _createCommand(CMD_CLASSROOM_SETUP, duration);
  }

  static List<int> classroomShutdownCommand() {
    return _createCommand(CMD_CLASSROOM_SHUTDOWN, 0);
  }

  static List<int> unlockDoorCommand(int duration) {
    return _createCommand(CMD_UNLOCK_DOOR, duration);
  }

  static List<int> lockDoorCommand() {
    return _createCommand(CMD_LOCK_DOOR, 0);
  }

  static List<int> projectorOnCommand() {
    return _createCommand(CMD_TURN_ON_PROJECTOR, 0);
  }

  static List<int> projectorOffCommand() {
    return _createCommand(CMD_TURN_OFF_PROJECTOR, 0);
  }
}