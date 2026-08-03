import 'package:flutter/material.dart';
import '../models/user_model.dart';

abstract class AuthService extends ChangeNotifier {
  UserModel? get currentUser;
  bool get isAuthenticated => currentUser != null;

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
  Future<void> loginAsGuest();
  Future<void> logout();
}
