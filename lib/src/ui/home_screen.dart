import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/controllers/ble/ble_state.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart';
import 'package:ble/src/models/smart_switch/smart_switch.dart';
import 'package:ble/src/ui/widgets/classroom_device_item.dart';
import 'package:ble/src/ui/widgets/custom_device_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

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
    //BlocProvider.of<BleBloc>(context).add(CheckBleAvailability());
    _loadProfessorProfile();
    _loadClassroomMapping();
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
  //  BlocProvider.of<BleBloc>(context).add(StopDiscovering());
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
    // Here you can check the status string to show different UI
    // e.g., if (status == "Connected") show the device item.
    // For now, this is a simple status display:

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == "Scanning for Classroom A...")
              const CircularProgressIndicator(),
            if (status != "Scanning for Classroom A...")
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

  Widget _buildProfessorInfoCard() {
    return Card(
      margin: EdgeInsets.all(16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Professor Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Name: ${_professorProfile!['professorName'] ?? 'N/A'}'),
            Text('Username: ${_professorProfile!['username']}'),
            Text('ID: ${_professorProfile!['professorId'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  void _showLessonSchedule() {
    // TODO: Implement lesson schedule view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lesson schedule feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeviceInfo() {
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

  /*void _handleState(BleState state) {
    print(state.status);
    switch (state.status) {
      case BleStatus.checkingAvailability:
        EasyLoading.show(
            status: "Checking Bluetooth availability...",
            dismissOnTap: false,
            maskType: EasyLoadingMaskType.black);
        break;
      case BleStatus.notAvailable:
        EasyLoading.dismiss();
        // Show more helpful error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message ?? 'Bluetooth not available'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () =>
                  BlocProvider.of<BleBloc>(context).add(CheckBleAvailability()),
            ),
          ),
        );
        break;
      case BleStatus.available:
        EasyLoading.dismiss();
        //BlocProvider.of<BleBloc>(context).add(DiscoverDevices());
        break;
      case BleStatus.discovering:
        EasyLoading.show(
            status: "Searching for ESP32 devices...",
            dismissOnTap: false,
            maskType: EasyLoadingMaskType.black);
        break;
      case BleStatus.connecting:
        EasyLoading.show(
          status: state.message ?? "Connecting...",
          dismissOnTap: false,
          maskType: EasyLoadingMaskType.black,
        );
        break;
      case BleStatus.connected:
        EasyLoading.dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully connected to ${state.connectedDevices.length} device(s)!'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case BleStatus.notConnected:
        EasyLoading.dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message ?? "Connection failed"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () =>
                  BlocProvider.of<BleBloc>(context).add(DiscoverDevices()),
            ),
          ),
        );
        break;
      case BleStatus.disconnected:
        EasyLoading.dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message ?? "Device disconnected"),
            backgroundColor: Colors.orange,
          ),
        );
        break;
    }
  }*/
}