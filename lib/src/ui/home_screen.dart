import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/controllers/ble/ble_state.dart';
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
  @override
  void initState() {
    BlocProvider.of<BleBloc>(context).add(CheckBleAvailability());
    super.initState();
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
        title: Text("Canovaccio"),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/logout', (route) => false),
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: BlocConsumer<BleBloc, BleState>(
        builder: (_, state) => _createView(state),
        listener: (_, state) => _handleState(state),
      ),
    );
  }

  _createView(BleState state) {
    if (state.connectedDevices.isEmpty) {
      return const Center(
        child: Text('No device connected'),
      );
    }
    return ListView.separated(
      itemCount: state.connectedDevices.length,
      separatorBuilder: (_, i) => const Divider(),
      itemBuilder: (_, i) {
        return Column(
          children: [
            SizedBox(height: 16.0),
            Text(
              state.connectedDevices[i].name,
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            CustomDeviceListItem(
                title: 'Relay 1',
                relayId: 0x01,
                device: state.connectedDevices[i]),
            CustomDeviceListItem(
                title: 'Relay 2',
                relayId: 0x02,
                device: state.connectedDevices[i]),
            CustomDeviceListItem(
                title: 'Relay 3',
                relayId: 0x03,
                device: state.connectedDevices[i]),
            CustomDeviceListItem(
                title: 'Relay 4',
                relayId: 0x04,
                device: state.connectedDevices[i])
          ],
        );
      },
    );
  }

  _handleState(BleState state) {
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