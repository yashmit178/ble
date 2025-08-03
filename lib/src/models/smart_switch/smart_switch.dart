import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/smart_switch/smart_switch_profile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SmartSwitch extends AbstractDevice {
  final Map<String, BluetoothService> deviceServices = {};
  final Map<String, BluetoothCharacteristic> deviceChars = {};

  SmartSwitch({
    required String name,
    required String uuid,
    required BluetoothDevice bleDevice,
  }) : super(name: name, uuid: uuid, bleDevice: bleDevice);

  @override
  Future<void> connect() async {
    await bleDevice?.connect();
    Future.delayed(Duration.zero);
  }

  @override
  Future<void> disconnect() async {
    await bleDevice!.disconnect();
    Future.delayed(Duration.zero);
  }

  @override
  Future<void> loadServicesAndCharacteristics() async {
    List<BluetoothService> tmpServices = await bleDevice!.discoverServices();
    Future.delayed(Duration.zero);

    for (BluetoothService service in tmpServices) {
      deviceServices[service.uuid.toString()] = service;
      print("Service discovered: ${service.uuid}");

      for (BluetoothCharacteristic c in service.characteristics) {
        deviceChars[c.uuid.toString()] = c;
        print("Characteristic discovered: ${c.uuid}");
      }
    }
  }

  @override
  Future<void> controlRelay(int id, bool status) async {
    final characteristic = deviceChars[SmartSwitchProfile.relayChar];
    if (characteristic != null) {
      List<int> command = SmartSwitchProfile.relayCommand(id, status);
      await write(characteristic, command);
      Future.delayed(Duration.zero);
    } else {
      print("Characteristic with UUID ${SmartSwitchProfile.relayChar} not found in deviceChars.");
      throw Exception("Characteristic not found");
    }
  }
}