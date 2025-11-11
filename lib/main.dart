import 'package:ble/src/app.dart';
import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
//import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/background_service.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:ble/src/controllers/schedule/schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions with better error handling
  print("Main: Requesting permissions...");
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ].request();

  print("Main: Permission statuses: $statuses");

  // Check if critical permissions are granted
  bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
  bool bluetoothGranted =
      (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
  bool notificationGranted =
      statuses[Permission.notification]?.isGranted ?? false;

  if (!locationGranted || !bluetoothGranted) {
    print(
        "Main: Critical permissions not granted. App may not work correctly.");
    // Show warning but continue - user can grant later
  }

  // Initialize Firebase
  print("Main: Initializing Firebase...");
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "dummy",
      // Not needed for Realtime DB-only usage
      appId: "dummy",
      messagingSenderId: "dummy",
      projectId: "dummy",
      databaseURL:
          "https://classroom-6206e-default-rtdb.europe-west1.firebasedatabase.app/",
    ),
  );
  print("Main: Firebase initialized successfully");

  // Initialize background service
  print("Main: Initializing background service...");
  try {
    await initializeService();
    print("Main: Background service initialized successfully");
  } catch (e) {
    print("Main: Background service initialization failed: $e");
    // Continue anyway - app can work without background service
  }

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ServiceRepository>(
          create: (context) => LocalServices(),
        ),
        RepositoryProvider<ScheduleRepository>(
          create: (context) => ScheduleRepository(),
        ),
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
              create: (context) =>
                  AuthBloc(context.read<AuthRepository>())..add(AppStarted())),
          /*BlocProvider<BleBloc>(
            create: (context) =>
                BleBloc(BleRepository(context.read<ServiceRepository>())),
          )*/
        ],
        child: MyApp(),
      ),
    ),
  );
}
