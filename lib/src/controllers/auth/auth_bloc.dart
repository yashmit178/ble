import 'dart:async';

import 'package:ble/src/controllers/auth/auth_event.dart';
import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository)
      : super(AuthState(status: AuthStatus.uninitialised, errorMessage: "")) {
    on<AppStarted>(_appStarted);
    on<Login>(_login);
    on<Logout>(_logout);
  }

  FutureOr<void> _appStarted(AppStarted event, Emitter<AuthState> emit) async {
    final bool hasToken = await _authRepository.hasToken();

    if (hasToken) {
      emit(state.copyWith(status: AuthStatus.authenticated));
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  FutureOr<void> _login(Login event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    await _authRepository.login(event.username, event.password)
        ? emit(state.copyWith(status: AuthStatus.authenticated))
        : emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Username or Password wrong!',
          ));
  }

  FutureOr<void> _logout(Logout event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }
}
