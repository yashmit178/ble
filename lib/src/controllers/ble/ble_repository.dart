import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/smart_switch/smart_switch.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom_profile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum DeviceType {
  smartSwitch,
  esp32Classroom,
}

class BleRepository {
  final ServiceRepository _serviceRepository;
  final List<BluetoothDevice> discoveredDevices = [];
  final Map<int, DateTime?> proximityTimer = {};

  BleRepository(this._serviceRepository);

  Future<bool> checkBleAvailability() async {
    return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  Stream<AbstractDevice> startDiscovering() async* {
    discoveredDevices.clear();
    // get known device uuids
    final knownDevices = await _serviceRepository.getKnownDeviceUuid();
    if (!knownDevices.status) return;

    FlutterBluePlus.startScan();
    Stream<List<ScanResult>> scanResults = FlutterBluePlus.scanResults;
    // Listen to scan results
    await for (List<ScanResult> results in scanResults) {
      for (var r in results) {
        if (discoveredDevices.contains(r.device) ||
            await r.device.connectionState.first == BluetoothConnectionState.connected) {
          continue;
        }
        discoveredDevices.add(r.device);
        if (knownDevices.data.contains(r.device.remoteId.str)) {
          // Determine device type and create appropriate device
          final deviceType = await _determineDeviceType(r.device);
          yield _createAbstractDevice(r.device, deviceType);
        }
      }
    }
  }

  Future<DeviceType> _determineDeviceType(BluetoothDevice bleDevice) async {
    try {
      // Try to connect briefly to check services
      await bleDevice.connect(timeout: Duration(seconds: 5));
      List<BluetoothService> services = await bleDevice.discoverServices();
      await bleDevice.disconnect();

      // Check for ESP32 classroom service
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            ESP32ClassroomProfile.mainService.toLowerCase()) {
          print("ESP32 Classroom device detected: ${bleDevice.platformName}");
          return DeviceType.esp32Classroom;
        }
      }

      // Default to smart switch for backward compatibility
      print("Smart Switch device detected: ${bleDevice.platformName}");
      return DeviceType.smartSwitch;
    } catch (e) {
      print("Error determining device type for ${bleDevice.platformName}: $e");
      // Default to smart switch if unable to determine
      return DeviceType.smartSwitch;
    }
  }

  AbstractDevice _createAbstractDevice(
      BluetoothDevice bleDevice, DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.esp32Classroom:
        return ESP32Classroom(
          name: bleDevice.platformName.isEmpty
              ? "ESP32 Classroom"
              : bleDevice.platformName,
          uuid: bleDevice.remoteId.str,
          bleDevice: bleDevice,
        );
      case DeviceType.smartSwitch:
      default:
        return SmartSwitch(
          name: bleDevice.platformName.isEmpty
              ? "Smart Switch"
              : bleDevice.platformName,
          uuid: bleDevice.remoteId.str,
          bleDevice: bleDevice,
        );
    }
  }

  Future<void> stopDiscovering() async {
    await FlutterBluePlus.stopScan();
    await Future.delayed(Duration.zero);
  }

  Future<List<AbstractDevice>> checkConnectedDevices() async {
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
    List<AbstractDevice> abstracts = [];

    for (var i = 0; i < devices.length; i++) {
      try {
        final deviceType = await _determineDeviceType(devices[i]);
        final device = _createAbstractDevice(devices[i], deviceType);
        await device.loadServicesAndCharacteristics();
        abstracts.add(device);
      } catch (e) {
        print(
            "Error processing connected device ${devices[i].platformName}: $e");
        // Skip this device if there's an error
        continue;
      }
    }
    return abstracts;
  }

  Future<void> connect(AbstractDevice device, Function listener) async {
    await device.connect();
    device.setDeviceStateListener(listener);
    await device.loadServicesAndCharacteristics();
  }

  Future<void> disconnect(AbstractDevice device) async {
    await device.disconnect();
  }

  // Helper method to get ESP32 classroom devices only
  List<AbstractDevice> getESP32ClassroomDevices(
      List<AbstractDevice> allDevices) {
    return allDevices
        .whereType<ESP32Classroom>()
        .cast<AbstractDevice>()
        .toList();
  }

  // Helper method to get smart switch devices only
  List<AbstractDevice> getSmartSwitchDevices(List<AbstractDevice> allDevices) {
    return allDevices.whereType<SmartSwitch>().cast<AbstractDevice>().toList();
  }
}