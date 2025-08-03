import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/smart_switch/smart_switch.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
          yield _createAbstractDevice(r.device);
        }
      }
    }
  }

  AbstractDevice _createAbstractDevice(BluetoothDevice bleDevice) {
    return SmartSwitch(
      name: bleDevice.platformName,
      uuid: bleDevice.remoteId.str,
      bleDevice: bleDevice,
    );
  }

  Future<void> stopDiscovering() async {
    await FlutterBluePlus.stopScan();
    await Future.delayed(Duration.zero);
  }

  Future<List<AbstractDevice>> checkConnectedDevices() async {
    // TODO: add listener to ble device in order to intercept disconnection
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
    List<AbstractDevice> abstracts = [];
    for (var i = 0; i < devices.length; i++) {
      final device = _createAbstractDevice(devices[i]);
      await device.loadServicesAndCharacteristics();
      abstracts.add(device);
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
}