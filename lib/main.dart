import 'package:ble/src/app.dart';
import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:ble/src/controllers/schedule/schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          BlocProvider<BleBloc>(
            create: (context) =>
                BleBloc(BleRepository(context.read<ServiceRepository>())),
          )
        ],
        child: MyApp(),
      ),
    ),
  );
}
