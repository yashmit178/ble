import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom_profile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ESP32Classroom extends AbstractDevice {
  final Map<String, BluetoothService> deviceServices = {};
  final Map<String, BluetoothCharacteristic> deviceChars = {};

  // Classroom state
  bool _isDoorUnlocked = false;
  bool _isProjectorOn = false;
  bool _areLightsOn = false;
  DateTime? _unlockTime;
  int _lessonDurationMinutes = 0;

  ESP32Classroom({
    required String name,
    required String uuid,
    required BluetoothDevice bleDevice,
  }) : super(name: name, uuid: uuid, bleDevice: bleDevice);

  // Getters for classroom state
  bool get isDoorUnlocked => _isDoorUnlocked;

  bool get isProjectorOn => _isProjectorOn;

  bool get areLightsOn => _areLightsOn;

  DateTime? get unlockTime => _unlockTime;

  int get remainingMinutes {
    if (_unlockTime == null) return 0;
    final elapsed = DateTime
        .now()
        .difference(_unlockTime!)
        .inMinutes;
    return (_lessonDurationMinutes + 10 - elapsed).clamp(
        0, _lessonDurationMinutes + 10);
  }

  @override
  Future<void> connect() async {
    if (bleDevice == null) return;
    print("ESP32Classroom: Attempting connection to ${bleDevice!.remoteId.str}"); // Add logging
    try {
      await bleDevice!.connect(timeout: Duration(seconds: 15)); // Add timeout here
      print(
          "ESP32Classroom: Connection successful to ${bleDevice!.remoteId.str}"); // Add logging
    } catch (e) {
      print(
          "ESP32Classroom: Connection failed to ${bleDevice!.remoteId.str}: $e"); // Add logging
      throw e; // Re-throw the exception so the BLoC can catch it
    }
    // No need for Future.delayed here
  }

  @override
  Future<void> disconnect() async {
    await bleDevice!.disconnect();
    await Future.delayed(Duration.zero);
  }

  @override
  Future<void> loadServicesAndCharacteristics() async {
    List<BluetoothService> tmpServices = await bleDevice!.discoverServices();
    await Future.delayed(Duration.zero);

    for (BluetoothService service in tmpServices) {
      deviceServices[service.uuid.toString()] = service;
      print("ESP32 Service discovered: ${service.uuid}");

      for (BluetoothCharacteristic c in service.characteristics) {
        deviceChars[c.uuid.toString()] = c;
        print("ESP32 Characteristic discovered: ${c.uuid}");
      }
    }
  }

  @override
  Future<void> controlRelay(int id, bool status) async {
    // Legacy support - map relay IDs to classroom functions
    switch (id) {
      case 0x01:
        if (status) {
          await unlockDoor(90); // Default 90 minutes
        } else {
          await lockDoor();
        }
        break;
      case 0x03:
        if (status) {
          await turnOnProjector();
        } else {
          await turnOffProjector();
        }
        break;
      default:
        print("Relay ID $id not mapped to classroom function");
    }
  }

  // Classroom-specific methods
  Future<void> setupClassroom(int lessonDurationMinutes) async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.classroomSetupCommand(
          lessonDurationMinutes + 10);
      await write(characteristic, command);

      _isDoorUnlocked = true;
      _isProjectorOn = true;
      _areLightsOn = true;
      _unlockTime = DateTime.now();
      _lessonDurationMinutes = lessonDurationMinutes;

      print(
          "Classroom setup completed for $lessonDurationMinutes minutes + 10 buffer");
      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }

  Future<void> shutdownClassroom() async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.classroomShutdownCommand();
      await write(characteristic, command);

      _isDoorUnlocked = false;
      _isProjectorOn = false;
      _areLightsOn = false;
      _unlockTime = null;
      _lessonDurationMinutes = 0;

      print("Classroom shutdown completed");
      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }

  Future<void> unlockDoor(int durationMinutes) async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.unlockDoorCommand(
          durationMinutes);
      await write(characteristic, command);

      _isDoorUnlocked = true;
      _unlockTime = DateTime.now();
      _lessonDurationMinutes = durationMinutes - 10; // Subtract buffer

      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }

  Future<void> lockDoor() async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.lockDoorCommand();
      await write(characteristic, command);

      _isDoorUnlocked = false;
      _unlockTime = null;

      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }

  Future<void> turnOnProjector() async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.projectorOnCommand();
      await write(characteristic, command);
      _isProjectorOn = true;
      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }

  Future<void> turnOffProjector() async {
    final characteristic = deviceChars[ESP32ClassroomProfile.controlChar];
    if (characteristic != null) {
      List<int> command = ESP32ClassroomProfile.projectorOffCommand();
      await write(characteristic, command);
      _isProjectorOn = false;
      await Future.delayed(Duration.zero);
    } else {
      throw Exception("ESP32 control characteristic not found");
    }
  }
}