// lib/blocs/authentication/authentication_state.dart

import 'package:equatable/equatable.dart';
import 'package:talabna/screens/check_auth.dart';

abstract class AuthenticationState extends Equatable {
  const AuthenticationState();

  @override
  List<Object?> get props => [];
}

class AuthenticationInitial extends AuthenticationState {}

class AuthenticationInProgress extends AuthenticationState {}

class AuthenticationSuccess extends AuthenticationState {
  final int? userId;
  final String? token;
  final String authType;
  final bool dataSaverEnabled;
  final bool isNewUser;

  const AuthenticationSuccess({
    this.userId,
    this.token,
    this.authType = 'email',
    this.dataSaverEnabled = false,
    this.isNewUser = false,
  });

  @override
  List<Object?> get props => [userId, token, authType, dataSaverEnabled, isNewUser];

  AuthenticationSuccess copyWith({
    int? userId,
    String? token,
    String? authType,
    bool? dataSaverEnabled,
    bool? isNewUser,
  }) {
    return AuthenticationSuccess(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      authType: authType ?? this.authType,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

class AuthenticationFailure extends AuthenticationState {
  final String error;
  final AuthErrorType errorType;

  const AuthenticationFailure({
    required this.error,
    this.errorType = AuthErrorType.unknownError,
  });

  @override
  List<Object?> get props => [error, errorType];
}

class DataSaverToggled extends AuthenticationSuccess {
  final bool isEnabled;

  const DataSaverToggled({
    required this.isEnabled,
    int? userId,
    String? token,
    String? authType,
  }) : super(
    userId: userId,
    token: token,
    authType: authType ?? 'email',
    dataSaverEnabled: isEnabled,
  );

  @override
  List<Object?> get props => [isEnabled, userId, token, authType, dataSaverEnabled];
}

class DataSaverToggleFailure extends AuthenticationSuccess {
  final String error;

  const DataSaverToggleFailure({
    required this.error,
    int? userId,
    String? token,
    String? authType,
    bool dataSaverEnabled = false,
  }) : super(
    userId: userId,
    token: token,
    authType: authType ?? 'email',
    dataSaverEnabled: dataSaverEnabled,
  );

  @override
  List<Object?> get props => [error, userId, token, authType, dataSaverEnabled];
}

class ForgotPasswordSuccess extends AuthenticationState {
  final String message;

  const ForgotPasswordSuccess({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

// New state for banned users
class AuthenticationBanned extends AuthenticationState {
  final String? banReason;

  const AuthenticationBanned({
    this.banReason,
  });

  @override
  List<Object?> get props => [banReason];
}