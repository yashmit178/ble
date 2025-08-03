import 'package:ble/src/controllers/auth/auth_bloc.dart';
import 'package:ble/src/controllers/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      child: Center(
        child: Container(
          child: Image.asset('assets/images/logo.png'),
        ),
      ),
      listener: _getInitialRoute,
    );
  }
}

void _getInitialRoute(BuildContext context, AuthState state) async {
  await Future.delayed(Duration(seconds: 5));
  if (state.status == AuthStatus.authenticated) {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  } else if (state.status == AuthStatus.unauthenticated) {
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
  }
}
