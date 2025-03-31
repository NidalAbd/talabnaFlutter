// lib/blocs/authentication/authentication_event.dart

import 'package:equatable/equatable.dart';

abstract class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequest extends AuthenticationEvent {
  final String email;
  final String password;
  final String? fcmToken;

  const LoginRequest({
    required this.email,
    required this.password,
    this.fcmToken,
  });

  @override
  List<Object?> get props => [email, password, fcmToken];
}

class GoogleSignInRequest extends AuthenticationEvent {
  final String? fcmToken;

  const GoogleSignInRequest({
    this.fcmToken,
  });

  @override
  List<Object?> get props => [fcmToken];
}

class LoggedIn extends AuthenticationEvent {
  final String? token;
  final String? fcmToken;

  const LoggedIn({
    this.token,
    this.fcmToken,
  });

  @override
  List<Object?> get props => [token, fcmToken];
}

class Register extends AuthenticationEvent {
  final String name;
  final String email;
  final String password;
  final String? fcmToken;

  const Register({
    required this.name,
    required this.email,
    required this.password,
    this.fcmToken,
  });

  @override
  List<Object?> get props => [name, email, password, fcmToken];
}

class LoggedOut extends AuthenticationEvent {}

class ForgotPassword extends AuthenticationEvent {
  final String email;

  const ForgotPassword({
    required this.email,
  });

  @override
  List<Object?> get props => [email];
}

class ToggleDataSaver extends AuthenticationEvent {}

class SetDataSaverEnabled extends AuthenticationEvent {
  final bool enabled;

  const SetDataSaverEnabled({
    required this.enabled,
  });

  @override
  List<Object?> get props => [enabled];
}

// New event for checking ban status
class CheckBanStatus extends AuthenticationEvent {
  final bool forceCheck;

  const CheckBanStatus({
    this.forceCheck = false,
  });

  @override
  List<Object?> get props => [forceCheck];
}