import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

/// Strongly typed authentication states for the ZankoAI domain
sealed class ZankoAuthState {
  const ZankoAuthState();
}

/// No user is currently signed in
class Unauthenticated extends ZankoAuthState {
  const Unauthenticated();
}

/// An authentication operation is in progress (signing in, registering, resetting)
class Authenticating extends ZankoAuthState {
  final String? message;
  const Authenticating([this.message]);
}

/// User is successfully authenticated with valid profile and session
class Authenticated extends ZankoAuthState {
  final UserModel user;
  final Session session;

  const Authenticated({
    required this.user,
    required this.session,
  });
}

/// User registered but their email requires confirmation before full sign-in
class EmailUnconfirmedState extends ZankoAuthState {
  final String email;
  final String? userId;

  const EmailUnconfirmedState({
    required this.email,
    this.userId,
  });
}

/// User opened the app via a password recovery deep link
class PasswordRecoveryState extends ZankoAuthState {
  final String? email;
  final String? recoveryToken;

  const PasswordRecoveryState({
    this.email,
    this.recoveryToken,
  });
}

/// Authentication encountered an error with localized Kurdish explanation
class AuthErrorState extends ZankoAuthState {
  final String message;
  final String? code;
  final dynamic originalError;

  const AuthErrorState({
    required this.message,
    this.code,
    this.originalError,
  });
}
