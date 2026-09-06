import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_state.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_auth_repository.dart';
import 'auth_service.dart';

/// Production-ready AuthService implementation backed by SupabaseAuthRepository
class SupabaseAuthService extends ChangeNotifier implements AuthService {
  final AuthRepository _repository;
  StreamSubscription<ZankoAuthState>? _repoSub;

  UserModel? _currentUser;
  ZankoAuthState _authState = const Unauthenticated();

  @override
  AuthRepository get repository => _repository;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Session? get currentSession => _repository.currentSession;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  ZankoAuthState get authState => _authState;

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('zanko_device_id');
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await prefs.setString('zanko_device_id', id);
    }
    return id;
  }

  SupabaseAuthService({AuthRepository? repository})
      : _repository = repository ?? SupabaseAuthRepository() {
    _init();
  }

  void _init() {
    // Listen to repository state changes
    _repoSub = _repository.authStateChanges.listen((state) {
      _authState = state;
      if (state is Authenticated) {
        _currentUser = state.user;
      } else if (state is Unauthenticated) {
        _currentUser = null;
      }
      notifyListeners();
    });

    // Check if a session is already cached
    final currentSession = _repository.currentSession;
    if (currentSession != null) {
      _repository.fetchUserProfile(currentSession.user.id, currentSession.user.email).then((profile) {
        if (profile != null) {
          _currentUser = profile;
          _authState = Authenticated(user: profile, session: currentSession);
          notifyListeners();
        }
      });
    }
  }

  @override
  Future<bool> login(String email, String password) async {
    try {
      _authState = const Authenticating('چوونەژوورەوە...');
      notifyListeners();

      final res = await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      if (res.user != null) {
        final profile = await _repository.fetchUserProfile(res.user!.id, res.user!.email);
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          } else {
            _authState = EmailUnconfirmedState(email: res.user!.email ?? email, userId: res.user!.id);
          }
          notifyListeners();
          return true;
        }
      }
      _authState = const Unauthenticated();
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthErrorState(message: e.toString(), originalError: e);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<bool> loginWithRole(String email, String password, UserRole role) async {
    return login(email, password);
  }

  @override
  Future<bool> register(
    String name,
    String email,
    String password,
    UserRole role, {
    String? universityName,
    String? departmentName,
    String? cityName,
  }) async {
    try {
      _authState = const Authenticating('دروستکردنی هەژمار...');
      notifyListeners();

      final res = await _repository.signUpWithEmail(
        email: email,
        password: password,
        fullName: name,
        role: role,
        universityName: universityName,
        departmentName: departmentName,
        cityName: cityName,
      );

      final user = res.user;
      if (user != null) {
        if (res.session != null) {
          final profile = await _repository.fetchUserProfile(user.id, email);
          _currentUser = profile ?? UserModel(
            id: user.id,
            name: name,
            email: email,
            role: role,
            universityName: universityName,
            departmentName: departmentName,
            cityName: cityName,
            isVip: false,
            vipStatus: 'none',
          );
          _authState = Authenticated(user: _currentUser!, session: res.session!);
          notifyListeners();
          return true;
        } else {
          // Email confirmation is required by Supabase
          _currentUser = UserModel(
            id: user.id,
            name: name,
            email: email,
            role: role,
            universityName: universityName,
            departmentName: departmentName,
            cityName: cityName,
            isVip: false,
            vipStatus: 'none',
          );
          _authState = EmailUnconfirmedState(email: email, userId: user.id);
          notifyListeners();
          return true;
        }
      }

      _authState = const Unauthenticated();
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthErrorState(message: e.toString(), originalError: e);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<bool> loginWithGoogle([UserRole role = UserRole.student]) async {
    try {
      _authState = const Authenticating('چوونەژوورەوە بە گووگڵ...');
      notifyListeners();

      final res = await _repository.signInWithGoogle();
      if (res == null) {
        _authState = const Unauthenticated();
        notifyListeners();
        return false;
      }

      if (res.user != null) {
        final profile = await _repository.fetchUserProfile(res.user!.id, res.user!.email);
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          }
          notifyListeners();
          return true;
        }
      }

      _authState = const Unauthenticated();
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthErrorState(message: e.toString(), originalError: e);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<bool> loginWithApple([UserRole role = UserRole.student]) async {
    try {
      _authState = const Authenticating('چوونەژوورەوە بە ئەپڵ...');
      notifyListeners();

      final res = await _repository.signInWithApple();
      if (res == null) {
        _authState = const Unauthenticated();
        notifyListeners();
        return false;
      }

      if (res.user != null) {
        final profile = await _repository.fetchUserProfile(res.user!.id, res.user!.email);
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          }
          notifyListeners();
          return true;
        }
      }

      _authState = const Unauthenticated();
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthErrorState(message: e.toString(), originalError: e);
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
    } catch (e) {
      debugPrint('Error sending password reset: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _repository.updatePassword(newPassword);
      return true;
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _repository.resendVerificationEmail(email);
    } catch (e) {
      debugPrint('Error resending email verification: $e');
      rethrow;
    }
  }

  @override
  Future<void> loginAsGuest() async {
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = UserModel(
      id: guestId,
      name: 'مێوان',
      email: 'guest@zanko.edu',
      role: UserRole.student,
      isVip: false,
      vipStatus: 'none',
    );
    _authState = const Unauthenticated();
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    await _repository.signOut();
    _currentUser = null;
    _authState = const Unauthenticated();
    notifyListeners();
  }

  @override
  Future<void> reloadUser() async {
    final user = _repository.currentAuthUser;
    if (user != null) {
      final profile = await _repository.fetchUserProfile(user.id, user.email);
      if (profile != null) {
        _currentUser = profile;
        notifyListeners();
      }
    }
  }

  @override
  Future<bool> updateProfile({
    required String fullName,
    String? cityName,
    String? universityName,
    String? departmentName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      if (_currentUser == null) return false;

      if (_currentUser!.isGuest) {
        _currentUser = _currentUser!.copyWith(
          name: fullName,
          cityName: cityName,
          universityName: universityName,
          departmentName: departmentName,
          photoUrl: avatarUrl,
        );
        notifyListeners();
        return true;
      }

      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;
      final targetId = authUser?.id ?? _currentUser!.id;

      final updatePayload = <String, dynamic>{
        'full_name': fullName,
        ...?cityName != null ? {'city_name': cityName} : null,
        ...?universityName != null ? {'university_name': universityName} : null,
        ...?departmentName != null ? {'department_name': departmentName} : null,
        ...?bio != null ? {'bio': bio} : null,
        ...?avatarUrl != null ? {'avatar_url': avatarUrl} : null,
      };

      try {
        final res = await client.from('profiles').update(updatePayload).eq('id', targetId).select();
        if (res.isEmpty) {
          await client.from('profiles').upsert({
            'id': targetId,
            'email': authUser?.email ?? _currentUser?.email ?? '',
            'full_name': fullName,
            'role': 'student',
            'status': 'active',
            'plan': 'free',
            ...updatePayload,
          }, onConflict: 'id');
        }
      } catch (e) {
        // If department_name or university_name columns do not exist yet in schema cache
        final corePayload = Map<String, dynamic>.from(updatePayload)
          ..remove('university_name')
          ..remove('department_name');
        try {
          final res = await client.from('profiles').update(corePayload).eq('id', targetId).select();
          if (res.isEmpty) {
            await client.from('profiles').upsert({
              'id': targetId,
              'email': authUser?.email ?? _currentUser?.email ?? '',
              'full_name': fullName,
              'role': 'student',
              'status': 'active',
              'plan': 'free',
              ...corePayload,
            }, onConflict: 'id');
          }
        } catch (innerError) {
          debugPrint('Profile update fallback notice: $innerError');
        }
      }

      // Keep Supabase Auth User metadata in sync with user's chosen full name
      try {
        await client.auth.updateUser(
          UserAttributes(data: {
            'full_name': fullName,
            'name': fullName,
          }),
        );
      } catch (metaErr) {
        debugPrint('Auth metadata sync notice: $metaErr');
      }

      await reloadUser();
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          name: fullName,
          cityName: cityName ?? _currentUser!.cityName,
          universityName: universityName ?? _currentUser!.universityName,
          departmentName: departmentName ?? _currentUser!.departmentName,
          photoUrl: avatarUrl ?? _currentUser!.photoUrl,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error in updateProfile: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    _currentUser = null;
    _authState = const Unauthenticated();
    notifyListeners();
  }

  @override
  Future<bool> refreshSession() async {
    try {
      final res = await _repository.refreshSession();
      if (res.session != null && res.user != null) {
        final profile = await _repository.fetchUserProfile(res.user!.id, res.user!.email);
        if (profile != null) {
          _currentUser = profile;
          _authState = Authenticated(user: profile, session: res.session!);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshing session in AuthService: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _repoSub?.cancel();
    super.dispose();
  }
}
