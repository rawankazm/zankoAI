import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_state.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

abstract class AuthService extends ChangeNotifier {
  UserModel? get currentUser;
  Session? get currentSession;
  bool get isAuthenticated => currentUser != null;
  ZankoAuthState get authState;
  AuthRepository get repository;

  Future<bool> login(String email, String password);
  Future<bool> loginWithRole(String email, String password, UserRole role);
  Future<bool> register(
    String name,
    String email,
    String password,
    UserRole role, {
    String? universityName,
    String? departmentName,
    String? cityName,
  });

  Future<bool> loginWithGoogle([UserRole role = UserRole.student]);
  Future<bool> loginWithApple([UserRole role = UserRole.student]);
  Future<void> sendPasswordResetEmail(String email);
  Future<bool> updatePassword(String newPassword);
  Future<void> resendVerificationEmail(String email);
  Future<void> loginAsGuest();
  Future<void> logout();
  Future<void> reloadUser();
  Future<void> deleteAccount();
  Future<bool> refreshSession();
}
