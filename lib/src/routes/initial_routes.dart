import 'package:ble/src/ui/home_screen.dart';
import 'package:ble/src/ui/logout_screen.dart';
import 'package:ble/src/ui/sign_in_screen.dart';
import 'package:ble/src/ui/splash_screen.dart';
import 'package:flutter/material.dart';

var navigationRoutes = <String, WidgetBuilder>{
  '/sign-in': (context) => const SignInScreen(),
  '/splash-screen': (context) => const SplashScreen(),
  '/home': (context) => const HomeScreen(),
  '/logout': (context) => const LogoutScreen(),
};
