import 'package:flutter/material.dart';
import '../models/user_model.dart';

abstract class AuthService extends ChangeNotifier {
  UserModel? get currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<bool> login(String email, String password);
  Future<bool> loginWithRole(String email, String password, UserRole role);
  Future<bool> register(String name, String email, String password, UserRole role);
  Future<bool> loginWithGoogle([UserRole role = UserRole.student]);
  Future<void> logout();
}

class MockAuthService extends ChangeNotifier implements AuthService {
  UserModel? _currentUser;
  final Map<String, UserModel> _registeredUsers = {};

  MockAuthService() {
    // Preload a default student for easy testing
    _registeredUsers['aras@zanko.edu'] = UserModel(
      id: 'mock_user_123',
      name: 'ئاراس ئەحمەد',
      email: 'aras@zanko.edu',
      role: UserRole.student,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: 3.65,
    );
    // Preload a default teacher for easy testing
    _registeredUsers['teacher@zanko.edu'] = UserModel(
      id: 'mock_teacher_001',
      name: 'د. سارا محمد',
      email: 'teacher@zanko.edu',
      role: UserRole.teacher,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: null,
    );
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Future<bool> login(String email, String password) async {
    return loginWithRole(email, password, UserRole.student);
  }

  @override
  Future<bool> loginWithRole(
      String email, String password, UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isNotEmpty && password.length >= 6) {
      final normalizedEmail = email.toLowerCase().trim();

      if (_registeredUsers.containsKey(normalizedEmail)) {
        // If user exists, override their role with what they selected at login
        final existing = _registeredUsers[normalizedEmail]!;
        _currentUser = existing.copyWith(role: role);
      } else {
        final namePart = normalizedEmail.split('@').first;
        final formattedName =
            namePart[0].toUpperCase() + namePart.substring(1);

        _currentUser = UserModel(
          id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
          name: formattedName,
          email: email,
          role: role,
          universityName: 'زانکۆی سلێمانی',
          departmentName: 'تەکنەلۆجیای زانیاری',
          gpa: role == UserRole.student ? 3.65 : null,
        );
        _registeredUsers[normalizedEmail] = _currentUser!;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<bool> register(
      String name, String email, String password, UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final normalizedEmail = email.toLowerCase().trim();

    _currentUser = UserModel(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: role == UserRole.student ? 3.65 : null,
    );

    _registeredUsers[normalizedEmail] = _currentUser!;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> loginWithGoogle([UserRole role = UserRole.student]) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _currentUser = UserModel(
      id: 'google_user_999',
      name: role == UserRole.teacher ? 'د. ڕاوەن شێرکۆ' : 'ڕاوەن شێرکۆ',
      email: 'rawan.sherko@gmail.com',
      role: role,
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: role == UserRole.student ? 3.82 : null,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    notifyListeners();
  }
}
