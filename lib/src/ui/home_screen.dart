import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
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
    BlocProvider.of<BleBloc>(context).add(CheckBleAvailability());
    _loadProfessorProfile();
    _loadClassroomMapping();
    super.initState();
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
    BlocProvider.of<BleBloc>(context).add(StopDiscovering());
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
      body: BlocConsumer<BleBloc, BleState>(
        builder: (_, state) => _createView(state),
        listener: (_, state) => _handleState(state),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeviceInfo(),
        child: Icon(Icons.info),
        tooltip: 'Device Information',
      ),
    );
  }

  Widget _createView(BleState state) {
    if (state.connectedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No devices connected',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure your ESP32 classroom device is powered on and nearby',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Separate ESP32 classroom devices from legacy smart switches
    final classroomDevices =
        state.connectedDevices.whereType<ESP32Classroom>().toList();
    final smartSwitches =
        state.connectedDevices.whereType<SmartSwitch>().toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ESP32 Classroom Devices Section
          if (classroomDevices.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Classroom Devices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            ...classroomDevices.map((device) {
              final classroomId = _classroomMapping[device.uuid];
              return ClassroomDeviceItem(
                device: device,
                professorId: _professorProfile?['professorId'],
                classroomId: classroomId,
              );
            }).toList(),
          ],

          // Legacy Smart Switches Section
          if (smartSwitches.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Smart Switches',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            ...smartSwitches
                .map((device) => _buildSmartSwitchItem(device))
                .toList(),
          ],

          // Professor Information Section
          if (_professorProfile != null) _buildProfessorInfoCard(),
        ],
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

  void _handleState(BleState state) {
    print(state.status);
    switch (state.status) {
      case BleStatus.checkingAvailability:
        EasyLoading.show(
            dismissOnTap: false, maskType: EasyLoadingMaskType.black);
        break;
      case BleStatus.notAvailable:
        EasyLoading.showError('Bluetooth not available',
            dismissOnTap: false, maskType: EasyLoadingMaskType.black);
        break;
      case BleStatus.available:
        EasyLoading.dismiss();
        BlocProvider.of<BleBloc>(context).add(DiscoverDevices());
        break;
      case BleStatus.discovering:
        EasyLoading.show(
            dismissOnTap: false, maskType: EasyLoadingMaskType.black);
        break;
      case BleStatus.connecting:
        EasyLoading.show(
          status: state.message,
          dismissOnTap: false,
          maskType: EasyLoadingMaskType.black,
        );
        break;
      case BleStatus.connected:
        EasyLoading.dismiss();
        break;
      case BleStatus.notConnected:
        EasyLoading.showError(
          state.message ?? "Error during connection",
          dismissOnTap: false,
          maskType: EasyLoadingMaskType.black,
        );
        break;
      case BleStatus.disconnected:
        EasyLoading.showInfo(
          state.message ?? "Device disconnected",
          dismissOnTap: false,
          maskType: EasyLoadingMaskType.black,
        );
        break;
    }
  }
}