import 'package:ble/src/models/abstract_device.dart';
import 'package:flutter/material.dart';

class CustomDeviceListItem extends StatelessWidget {
  final String title;
  final int relayId;
  final AbstractDevice device;

  const CustomDeviceListItem({
    Key? key,
    required this.title,
    required this.relayId,
    required this.device,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _sendRelayCommand(true),
            icon: const Icon(
              Icons.door_back_door,
              color: Colors.green,
            ),
          ),
          IconButton(
            onPressed: () => _sendRelayCommand(false),
            icon: const Icon(
              Icons.door_back_door,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _sendRelayCommand(bool status) async {
    try {
      await device.controlRelay(relayId, status);
    } catch (e) {
      // Handle the error, e.g., show a message to the user
      print("Failed to send relay command: $e");
    }
    Future.delayed(Duration.zero);
  }
}