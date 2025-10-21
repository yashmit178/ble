import 'dart:async';
import 'dart:math';

import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/ble/ble_state.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleBloc extends Bloc<BleEvent, BleState> {
  final BleRepository _bleRepository;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription? _scanSubscription;
  final Map<int, DateTime?> proximityTimer = {};

  BleBloc(this._bleRepository) : super(BleState()) {
    on<CheckBleAvailability>(_checkBleAvailability);
    on<DiscoverDevices>(_discoverDevices);
    on<ConnectDevice>(_connectDevice);
    on<DeviceStatusChanged>(_deviceStatusChanged);
    on<StopDiscovering>(_stopDiscovering);
    on<UpdateDevice>(_updateDevice);
    on<InitBle>(_initBle);
    rssiListener();

    // Listen for Bluetooth adapter state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        add(CheckBleAvailability()); // If user turns BT on, re-start the process
      } else {
        emit(this.state.copyWith(status: BleStatus.notAvailable));
      }
    });
  }

  @override
  Future<void> close() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _bleRepository.stopDiscovering();
    return super.close();
  }

  FutureOr<void> _checkBleAvailability(
      CheckBleAvailability event, Emitter<BleState> emit) async {
    emit(state.copyWith(status: BleStatus.checkingAvailability));
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      emit(state.copyWith(status: BleStatus.notAvailable));
      // Prompt the user to turn on Bluetooth
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print("Error requesting to turn on Bluetooth: $e");
      }
    } else {
      final devices = await _bleRepository.checkConnectedDevices();
      emit(state.copyWith(
          status: BleStatus.available, connectedDevices: devices));
    }
  }

  FutureOr<void> _discoverDevices(
      DiscoverDevices event, Emitter<BleState> emit) async {
    emit(state.copyWith(status: BleStatus.discovering));
    _scanSubscription?.cancel(); // Ensure any old scan is stopped
    _scanSubscription = _bleRepository.startDiscovering().listen(_onDeviceDiscovered);
  }

  void _onDeviceDiscovered(AbstractDevice device) {
    add(ConnectDevice(device: device));
  }

  FutureOr<void> _connectDevice(
      ConnectDevice event, Emitter<BleState> emit) async {
    // TODO: check if the discovering should be stopped during the connection
    // await _bleRepository.stopDiscovering();
    emit(state.copyWith(
      status: BleStatus.connecting,
      message: "connecting to ${event.device.name}",
    ));
    try {
      await _bleRepository.connect(event.device, _onDeviceStateChange);
      emit(
        state.copyWith(
          status: BleStatus.connected,
          connectedDevices: List.of(state.connectedDevices)..add(event.device),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BleStatus.notConnected,
          message: e.toString(),
        ),
      );
    }
  }

  void _onDeviceStateChange(AbstractDevice device, BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      add(DeviceStatusChanged(device));
    }
  }

  FutureOr<void> _deviceStatusChanged(
      DeviceStatusChanged event, Emitter<BleState> emit) async {
    // disconnect device to avoid reconnection
    await _bleRepository.disconnect(event.device);
    emit(state.copyWith(
      connectedDevices: List.of(state.connectedDevices)..remove(event.device),
    ));
  }

  FutureOr<void> _stopDiscovering(
      StopDiscovering event, Emitter<BleState> emit) async {
    await _bleRepository.stopDiscovering();
  }

  FutureOr<void> _updateDevice(
      UpdateDevice event, Emitter<BleState> emit) async {
    int index = state.connectedDevices.indexOf(event.device);
    state.copyWith(
        connectedDevices: List.of(state.connectedDevices)
          ..replaceRange(index, index + 1, [event.device]));
  }

  FutureOr<void> _initBle(InitBle event, Emitter<BleState> emit) async {
    await _bleRepository.stopDiscovering();
    Future.delayed(Duration.zero);
    for (final device in state.connectedDevices) {
      await _bleRepository.disconnect(device);
    }
    emit(
      state.copyWith(
        status: BleStatus.notAvailable,
        connectedDevices: [],
      ),
    );
  }

  Future<void> rssiListener() async {
    Future.delayed(
      const Duration(seconds: 1), // delay of 1 second
          () async {
        for (int i = 0; i < state.connectedDevices.length; i++) {
          int rssi = await state.connectedDevices[i].bleDevice!.readRssi();
          double distance = rssiToMeter(rssi.toDouble());
          add(UpdateDevice(state.connectedDevices[i]));
          if (distance <= 0.50) {
            print("Into the range");
            DateTime currentDate = DateTime.now();
            if (proximityTimer[i] != null) {
              // timer already set
              int seconds = 0;
              if (proximityTimer[i] != null && distance <= 0.50) {
                seconds = currentDate.difference(proximityTimer[i]!).inSeconds;
              }
              if (seconds >= 5) {
                // Open all the relays
                Future.delayed(
                    Duration(milliseconds: 0),
                        () async => await state.connectedDevices[i]
                        .controlRelay(0x01, true));
                Future.delayed(
                    Duration(milliseconds: 100),
                        () async => await state.connectedDevices[i]
                        .controlRelay(0x02, true));
                Future.delayed(
                    Duration(milliseconds: 200),
                        () async => await state.connectedDevices[i]
                        .controlRelay(0x03, true));
                Future.delayed(
                    Duration(milliseconds: 300),
                        () async => await state.connectedDevices[i]
                        .controlRelay(0x04, true));
                proximityTimer[i] = null;
              }
            } else {
              print("Set new timer");
              // set the timer
              proximityTimer[i] = currentDate;
            }
          } else {
            print("Out of range");
            proximityTimer[i] = null;
          }
        }
        rssiListener();
      },
    );
  }

  double rssiToMeter(double rssi) {
    int measuredPower = -51; // Measured Rssi value at a distance of 1 meter
    double N = 1; // Constant for the environment factor: value between 2 and 4 (1 is the one most performed now)
    double distance = pow(10, ((measuredPower - rssi) / pow(10, N))).toDouble();
    return distance;
  }
}
