import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

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
    EasyLoading.show(status: "");
    super.initState();
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logout();
    return Container();
  }

  void logout() async {
    BlocProvider.of<BleBloc>(context).add(InitBle());
    Future.delayed(Duration.zero);
    BlocProvider.of<AuthBloc>(context).add(Logout());
    Future.delayed(Duration.zero);
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
  }
}
