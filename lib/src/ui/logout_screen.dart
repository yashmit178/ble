import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:ble/src/ui/sign_in_screen.dart'; // Import the sign-in screen
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_background_service/flutter_background_service.dart'; // Import service

import '../controllers/auth/auth_bloc.dart';
import '../controllers/auth/auth_event.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({Key? key}) : super(key: key);

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  @override
  void initState() {
    EasyLoading.show(status: "Logging out...");
    super.initState();
    // Call the logout function after build is done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logout();
    });
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White background instead of transparent
      child: const Center(
        child: CircularProgressIndicator(), // Show loader
      ),
    );
  }

  void logout() async {
    try {
      // 1. Trigger BLoC events to clear state
      BlocProvider.of<BleBloc>(context).add(InitBle());
      BlocProvider.of<AuthBloc>(context).add(Logout());

      // 2. Stop background service
      final service = FlutterBackgroundService();
      var isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke("stopService");
        // Give it a small moment to process the stop command
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait a moment for UI smoothness
      await Future.delayed(const Duration(milliseconds: 500));

    } catch (e) {
      print("Logout Error: $e");
    } finally {
      // 3. Always navigate, even if errors occurred above
      if (mounted) {
        EasyLoading.dismiss();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
              (route) => false,
        );
      }
    }
  }
}