import 'package:equatable/equatable.dart';

enum AuthStatus {
  uninitialised,
  authenticated,
  unauthenticated,
  loading,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final String errorMessage;

  const AuthState({
    required this.status,
    required this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, errorMessage];
}
