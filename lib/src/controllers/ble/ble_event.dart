import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:equatable/equatable.dart';

abstract class BleEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class CheckBleAvailability extends BleEvent {}

class DiscoverDevices extends BleEvent {}

class ConnectDevice extends BleEvent {
  AbstractDevice device;

  ConnectDevice({required this.device});

  @override
  List<Object> get props => [device];
}

class DeviceStatusChanged extends BleEvent {
  final AbstractDevice device;

  DeviceStatusChanged(this.device);

  @override
  List<Object> get props => [device];
}

class UpdateDevice extends BleEvent {
  final AbstractDevice device;

  UpdateDevice(this.device);

  @override
  List<Object> get props => [device];
}

class StopDiscovering extends BleEvent {}

class InitBle extends BleEvent {}
