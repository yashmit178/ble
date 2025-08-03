import 'package:ble/src/app.dart';
import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_bloc.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ServiceRepository>(
          create: (context) => LocalServices(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
              create: (context) =>
                  AuthBloc(AuthRepository(context.read<ServiceRepository>()))
                    ..add(AppStarted())),
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
