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
    // Ensure scanning is stopped before starting a new one
    await FlutterBluePlus.stopScan();
    print("Previous scan stopped."); // Add logging

    discoveredDevices.clear();
    final knownDevices = await _serviceRepository.getKnownDeviceUuid();
    if (!knownDevices.status) {
      print("Failed to get known device UUIDs."); // Add logging
      return;
    }

    final serviceGuid = Guid(ESP32ClassroomProfile.mainService);
    print(
        "Starting scan. Will filter for known MACs: ${knownDevices.data}"); // Updated log
    print("Target Service UUID (for reference): ${serviceGuid.toString()}");

    try {
      FlutterBluePlus.startScan(
        //withServices: [serviceGuid],
        timeout: const Duration(seconds: 20), // Increased timeout
      );

      // Use distinct to avoid processing the same device multiple times rapidly
      await for (var results in FlutterBluePlus.scanResults) {
        print("Scan results received: ${results.length} devices found");

        for (ScanResult r in results) {
          print(
              "Found device: ${r.device.platformName} (${r.device.remoteId.str}) RSSI: ${r.rssi}");

          // Check if already discovered OR if already connected by the system
          final isConnected = await r.device.connectionState.first ==
              BluetoothConnectionState.connected;
          if (!discoveredDevices.contains(r.device) &&
              knownDevices.data.contains(r.device.remoteId.str) &&
              !isConnected) {
            // Add check for already connected
            print(
                'Found known Classroom ESP32: ${r.device.remoteId.str}, RSSI: ${r.rssi}');
            discoveredDevices.add(r.device);
            yield _createAbstractDevice(r.device, DeviceType.esp32Classroom);
            // Stop after finding first matching device
            await FlutterBluePlus.stopScan();
            return;
          }
        }
      }
    } catch (e) {
      print("Error during BLE scan: $e");
      await FlutterBluePlus.stopScan();
    }

    print("Scan completed - no matching devices found");
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
    print("Repository: Connecting to ${device.name} (${device.uuid})"); // Add logging
    // Listen to state changes *before* connecting
    device.setDeviceStateListener(listener);

    await device.connect(); // Let the AbstractDevice handle its own timeout if needed
    print(
        "Repository: Connection initiated, loading services for ${device.name}"); // Add logging
    await device.loadServicesAndCharacteristics();
    print(
        "Repository: Services loaded for ${device.name}"); // Add logging
  }

  Stream<AbstractDevice> startScanning() {
    print("Background Service: Starting scan...");

    // Using a StreamController to manage this
    late StreamController<AbstractDevice> controller;
    StreamSubscription? scanSub;

    controller = StreamController<AbstractDevice>(
      onListen: () async {
        final knownDevices = await _localServices.getKnownDevices();
        if (!knownDevices.status) {
          controller.addError('Could not load known devices');
          controller.close();
          return;
        }

        FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 20),
        );

        scanSub = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult r in results) {
            if (knownDevices.data.contains(r.device.remoteId.str)) {
              print('>>> MATCH FOUND: ${r.device.remoteId.str}. Yielding device.');
              FlutterBluePlus.stopScan();
              controller.add(_createAbstractDevice(r.device, DeviceType.esp32Classroom));
              controller.close(); // We are done
              scanSub?.cancel();
              return;
            }
          }
        });
      },
      onCancel: () {
        FlutterBluePlus.stopScan();
        scanSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// A helper to listen to connection state for the background service.
  StreamSubscription<BluetoothConnectionState> listenToConnection(
      AbstractDevice device,
      void Function(BluetoothConnectionState state) onStateChanged,
      ) {
    return device.bleDevice!.connectionState.listen((state) {
      onStateChanged(state);
    });
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