import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class Login extends AuthEvent {
  final String username;
  final String password;

  Login({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

class Logout extends AuthEvent {}
