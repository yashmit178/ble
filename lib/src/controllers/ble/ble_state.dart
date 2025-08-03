import 'package:ble/src/models/abstract_device.dart';
import 'package:equatable/equatable.dart';

enum BleStatus {
  checkingAvailability,
  notAvailable,
  available,
  discovering,
  connecting,
  connected,
  notConnected,
  disconnected,
}

class BleState extends Equatable {
  final BleStatus status;
  final List<AbstractDevice> connectedDevices;
  final String? message;

  const BleState({
    this.status = BleStatus.notAvailable,
    this.connectedDevices = const [],
    this.message,
  });

  BleState copyWith({
    BleStatus? status,
    List<AbstractDevice>? connectedDevices,
    String? message,
  }) {
    return BleState(
      status: status ?? this.status,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
        status,
        connectedDevices,
        message,
      ];
}
