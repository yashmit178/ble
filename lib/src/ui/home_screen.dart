import 'dart:io'; // Required for Platform check
import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart';
import 'package:ble/src/models/smart_switch/smart_switch.dart';
import 'package:ble/src/ui/widgets/classroom_device_item.dart';
import 'package:ble/src/ui/widgets/custom_device_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Required for turnOn()

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final LocalServices _localServices = LocalServices();
  Map<String, dynamic>? _professorProfile;
  Map<String, String> _classroomMapping = {};

  @override
  void initState() {
    super.initState();

    // --- RESTORED LOGIC START ---
    // This runs every time the app is opened (Home Screen initialized)
    _enableBluetoothWithSystemDialog();
    // --- RESTORED LOGIC END ---

    _loadProfessorProfile();
    _loadClassroomMapping();
  }

  /// This function implements the exact logic from your old BleBloc
  Future<void> _enableBluetoothWithSystemDialog() async {
    // 1. We must request CONNECT permission first, otherwise turnOn() fails silently on Android 12+
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ].request();

    // 2. Check if Bluetooth Adapter is ON
    if (Platform.isAndroid) {
      // Get the current state
      final adapterState = await FlutterBluePlus.adapterState.first;

      if (adapterState != BluetoothAdapterState.on) {
        print("Bluetooth is OFF. Triggering system dialog...");

        try {
          // --- THIS IS THE LINE THAT TRIGGERS "ble wants to turn on bluetooth" ---
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print("Error requesting to turn on Bluetooth: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Could not enable Bluetooth: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _loadProfessorProfile() async {
    final profile = await _authRepository.getProfessorProfile();
    setState(() {
      _professorProfile = profile;
    });
  }

  Future<void> _loadClassroomMapping() async {
    final mapping = await _localServices.getClassroomMapping();
    if (mapping.status) {
      setState(() {
        _classroomMapping = mapping.data;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Classroom Control"),
            if (_professorProfile != null)
              Text(
                "Welcome, ${_professorProfile!['professorName'] ?? _professorProfile!['username']}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showLessonSchedule(),
            icon: Icon(Icons.schedule),
            tooltip: 'View Schedule',
          ),
          IconButton(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/logout', (route) => false),
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      // Note: We are listening to the Background Service for UI updates
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: FlutterBackgroundService().on('update'),
        builder: (context, snapshot) {
          final status = snapshot.data?['status'] ?? "Initializing...";
          final body = snapshot.data?['body'] ?? "Waiting for service...";
          return _createView(status, body);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeviceInfo(),
        child: Icon(Icons.info),
        tooltip: 'Device Information',
      ),
    );
  }

  Widget _createView(String status, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status.contains("Scanning") || status.contains("Initializing"))
              const CircularProgressIndicator(),
            if (!status.contains("Scanning") && !status.contains("Initializing"))
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            Text(
              status,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartSwitchItem(SmartSwitch device) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              device.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            CustomDeviceListItem(
                title: 'Relay 1',
                relayId: 0x01, device: device),
            CustomDeviceListItem(
                title: 'Relay 2',
                relayId: 0x02, device: device),
            CustomDeviceListItem(
                title: 'Relay 3',
                relayId: 0x03, device: device),
            CustomDeviceListItem(
                title: 'Relay 4',
                relayId: 0x04, device: device),
          ],
        ),
      ),
    );
  }

  void _showLessonSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lesson schedule feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeviceInfo() {
    // Note: BLoC state might be empty if logic is in BackgroundService,
    // but keeping this purely for compatibility with your existing widgets.
    final state = BlocProvider.of<BleBloc>(context).state;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connected Devices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total devices: ${state.connectedDevices.length}'),
            Text(
                'ESP32 Classrooms: ${state.connectedDevices.whereType<ESP32Classroom>().length}'),
            Text(
                'Smart Switches: ${state.connectedDevices.whereType<SmartSwitch>().length}'),
            SizedBox(height: 16),
            ...state.connectedDevices
                .map((device) => Text('• ${device.name} (${device.uuid})')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}