import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:json_annotation/json_annotation.dart';

part 'abstract_device.g.dart';

@JsonSerializable(createFactory: false)
abstract class AbstractDevice extends Equatable {
  final String name;
  final String uuid;
  final int? rssi;
  final int count;
  static $toNull(_) => null;
  @JsonKey(toJson: $toNull, fromJson: $toNull)
  final BluetoothDevice? bleDevice;

  final String? manufacturerNameString;
  final String? modelNumberString;
  final String? hardwareRevisionString;
  final String? firmwareRevisionString;
  final String? softwareRevisionString;
  final String? systemId;

  AbstractDevice({
    required this.name,
    required this.uuid,
    this.rssi,
    this.bleDevice,
    this.manufacturerNameString,
    this.modelNumberString,
    this.hardwareRevisionString,
    this.firmwareRevisionString,
    this.softwareRevisionString,
    this.systemId,
  }) : count = 0;

  void setDeviceStateListener(Function listener) {
    bleDevice?.state.listen((state) => listener(this, state));
  }

  Future<void> connect();
  Future<void> disconnect();
  Future<void> loadServicesAndCharacteristics();
  Future<void> controlRelay(int id, bool status);

  Future<void> write(
      BluetoothCharacteristic characteristic, List<int> bytes) async {
    characteristic.write(bytes);
  }

  Future<List<int>> read(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  @override
  List<Object?> get props => [name, uuid, rssi];

  @override
  String toString() => 'AbstractDevice{name: $name, uuid: $uuid, rssi: $rssi}';

  Map<String, dynamic> toJson() => _$AbstractDeviceToJson(this);
}