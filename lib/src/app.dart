import 'package:ble/src/routes/initial_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canovaccio',
      initialRoute: '/splash-screen',
      routes: navigationRoutes,
      debugShowCheckedModeBanner: false,
      builder: EasyLoading.init(),
    );
  }
}
