import 'dart:async';
import 'dart:math';

import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/ble/ble_state.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

    // CRITICAL: Request permissions FIRST before checking Bluetooth
    bool permissionsGranted = await _requestBlePermissions();
    if (!permissionsGranted) {
      emit(state.copyWith(
          status: BleStatus.notAvailable,
          message:
              "Bluetooth and Location permissions are required. Please enable Location Services in Settings."));
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      emit(state.copyWith(
          status: BleStatus.notAvailable, message: "Please turn on Bluetooth"));
      // Prompt the user to turn on Bluetooth
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print("Error requesting to turn on Bluetooth: $e");
      }
    } else {
      final devices = await _bleRepository.checkConnectedDevices();
      emit(state.copyWith(
          status: BleStatus.available,
          connectedDevices: devices,
          message: "Bluetooth ready - searching for classroom devices..."));
    }
  }

  Future<bool> _requestBlePermissions() async {
    print("Requesting BLE permissions...");

    try {
      // CRITICAL FIX: Check if location services are enabled first
      bool isLocationServiceEnabled =
          await Permission.location.serviceStatus.isEnabled;
      if (!isLocationServiceEnabled) {
        print(
            "Location services are disabled - this is required for BLE scanning");
        return false;
      }

      // Request all required permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

      print("Permission statuses: $statuses");

      // Check if critical permissions are granted
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
      bool scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      bool connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;

      print(
          "Location: $locationGranted, Scan: $scanGranted, Connect: $connectGranted");

      return locationGranted && scanGranted && connectGranted;
    } catch (e) {
      print("Error requesting BLE permissions: $e");
      return false;
    }
  }

  FutureOr<void> _discoverDevices(
      DiscoverDevices event, Emitter<BleState> emit) async {
    // Check if Bluetooth is actually available before trying to discover
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      emit(state.copyWith(
          status: BleStatus.notAvailable, message: "Bluetooth is not enabled"));
      return;
    }

    emit(state.copyWith(
        status: BleStatus.discovering,
        message: "Searching for ESP32 classroom devices..."));
    _scanSubscription?.cancel(); // Ensure any old scan is stopped

    print("Starting BLE discovery..."); // Add logging

    // Listen to the stream and handle devices or errors
    _scanSubscription = _bleRepository.startDiscovering().listen(
          (device) {
        print("Device discovered via stream: ${device.name} (${device.uuid})"); // Add logging
        // Add the ConnectDevice event when a device is yielded by the stream
        add(ConnectDevice(device: device));
      },
      onError: (error) {
        print("Error during discovery: $error"); // Add logging
        emit(state.copyWith(
            status: BleStatus.notConnected,
            message: "Discovery failed: $error"));
      },
      onDone: () {
        print("Discovery stream done."); // Add logging
        // If the scan completes without finding a device that was yielded
        if (state.status == BleStatus.discovering) {
          emit(state.copyWith(
              status: BleStatus.available,
              message: "No ESP32 classroom devices found nearby"));
        }
      },
    );
  }

// Modify _connectDevice to stop scanning BEFORE attempting to connect
  FutureOr<void> _connectDevice(
      ConnectDevice event, Emitter<BleState> emit) async {
    // Stop scanning before connecting - important for stability on some devices
    await _bleRepository.stopDiscovering();
    _scanSubscription?.cancel(); // Cancel the listener as well
    _scanSubscription = null; // Clear the subscription

    print(
        "Attempting to connect to ${event.device.name} (${event.device.uuid})"); // Add logging

    // Check if already connected or connecting to this device
    if (state.connectedDevices.any((d) => d.uuid == event.device.uuid) ||
        state.status == BleStatus.connecting) {
      print(
          "Already connected or connecting to ${event.device.name}, skipping."); // Add logging
      return;
    }

    emit(state.copyWith(
      status: BleStatus.connecting,
      message: "Connecting to ${event.device.name}",
    ));

    try {
      // Add a timeout to the connection attempt
      await _bleRepository.connect(event.device, _onDeviceStateChange)
          .timeout(const Duration(seconds: 15)); // 15-second timeout

      print(
          "Successfully connected to ${event.device.name}"); // Add logging
      emit(
        state.copyWith(
          status: BleStatus.connected,
          // Ensure no duplicates are added
          connectedDevices: List.of(state.connectedDevices)
            ..removeWhere((d) => d.uuid == event.device.uuid)
            ..add(event.device),
          message: "Connected to ${event.device.name}",
        ),
      );
    } catch (e) {
      print("Failed to connect to ${event.device.name}: $e"); // Add logging
      emit(
        state.copyWith(
          status: BleStatus.notConnected,
          message: "Failed to connect: ${e.toString()}",
        ),
      );
      // Important: If connection fails, restart discovery after a short delay
      /*await Future.delayed(const Duration(seconds: 2));
      if (state.status != BleStatus.discovering && state.status != BleStatus.connected) {
        add(DiscoverDevices());
      }*/
      print("Connection failed. Cooling down for 5 seconds before retry...");
      await Future.delayed(const Duration(seconds: 5));
      if (state.status != BleStatus.discovering && state.status != BleStatus.connected) {
        print("Cooldown complete. Restarting discovery.");
        add(DiscoverDevices());
      }
    }
  }

  void _onDeviceStateChange(AbstractDevice device, BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      add(DeviceStatusChanged(device));
    }
  }

  FutureOr<void> _deviceStatusChanged(
      DeviceStatusChanged event, Emitter<BleState> emit) async {
    print(
        "Device disconnected: ${event.device.name}"); // Add logging
    // Disconnect explicitly if not already disconnected by the system event
    try {
      await _bleRepository.disconnect(event.device);
    } catch (e) {
      print("Error during explicit disconnect: $e"); // Ignore errors here
    }

    final updatedDevices = List.of(state.connectedDevices)
      ..removeWhere((d) => d.uuid == event.device.uuid);

    emit(state.copyWith(
      connectedDevices: updatedDevices,
      // If no devices are left, go back to 'available' to allow rediscovery
      status: updatedDevices.isEmpty ? BleStatus.available : state.status,
      message: "${event.device.name} disconnected",
    ));

    // If no devices are connected, restart discovery automatically
    if (updatedDevices.isEmpty) {
      print("No devices connected, restarting discovery."); // Add logging
      add(DiscoverDevices());
    }
  }

  FutureOr<void> _stopDiscovering(
      StopDiscovering event, Emitter<BleState> emit) async {
    await _bleRepository.stopDiscovering();
  }

  FutureOr<void> _updateDevice(
      UpdateDevice event, Emitter<BleState> emit) async {
    int index = state.connectedDevices.indexOf(event.device);
    emit(state.copyWith(
        connectedDevices: List.of(state.connectedDevices)
          ..replaceRange(index, index + 1, [event.device])));
  }

  FutureOr<void> _initBle(InitBle event, Emitter<BleState> emit) async {
    print("Initializing BLE state..."); // Add logging
    await _bleRepository.stopDiscovering();
    _scanSubscription?.cancel();
    _scanSubscription = null;

    // Make disconnection more robust
    List<Future> disconnectFutures = [];
    for (final device in state.connectedDevices) {
      print("Disconnecting device: ${device.name}"); // Add logging
      disconnectFutures.add(_bleRepository.disconnect(device).catchError((e) {
        print("Error disconnecting ${device.name}: $e"); // Log errors but continue
      }));
    }
    await Future.wait(disconnectFutures); // Wait for all disconnections

    emit(
      state.copyWith(
        status: BleStatus.notAvailable, // Start from notAvailable
        connectedDevices: [],
        message: "Initializing...",
      ),
    );
    // After initializing, immediately check availability again
    add(CheckBleAvailability());
  }

  Future<void> rssiListener() async {
    Future.delayed(
      const Duration(seconds: 1), // delay of 1 second
          () async {
        for (int i = 0; i < state.connectedDevices.length; i++) {
          try {
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
                  seconds =
                      currentDate.difference(proximityTimer[i]!).inSeconds;
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
          } catch (e) {
            print("Error reading RSSI for device $i: $e");
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
