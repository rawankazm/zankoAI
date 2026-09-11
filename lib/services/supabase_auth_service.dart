import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_state.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_auth_repository.dart';
import 'auth_service.dart';
import 'vip_firestore_service.dart';

/// Production-ready AuthService implementation backed by SupabaseAuthRepository
class SupabaseAuthService extends ChangeNotifier implements AuthService {
  final AuthRepository _repository;
  StreamSubscription<ZankoAuthState>? _repoSub;
  Timer? _vipWatcherTimer;

  UserModel? _currentUser;
  ZankoAuthState _authState = const Unauthenticated();
  final Completer<void> _initCompleter = Completer<void>();

  @override
  AuthRepository get repository => _repository;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Session? get currentSession => _repository.currentSession;

  @override
  bool get isAuthenticated =>
      _currentUser != null || _repository.currentSession != null;

  @override
  Future<void> get initializationReady => _initCompleter.future;

  @override
  ZankoAuthState get authState => _authState;

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('zanko_device_id');
    if (id == null || id.isEmpty) {
      id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await prefs.setString('zanko_device_id', id);
    }
    return id;
  }

  SupabaseAuthService({AuthRepository? repository})
    : _repository = repository ?? SupabaseAuthRepository() {
    _init();
  }

  void _init() {
    // 1. Listen to repository state changes
    _repoSub = _repository.authStateChanges.listen((state) {
      _authState = state;
      if (state is Authenticated) {
        _currentUser = state.user;
      } else if (state is Unauthenticated) {
        if (_currentUser?.isGuest != true) {
          _currentUser = null;
        }
      }
      notifyListeners();
    });

    _performInitialRestore();
  }

  Future<void> _performInitialRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('zanko_is_guest') ?? false;

      final currentSession = _repository.currentSession;
      final authUser = _repository.currentAuthUser;

      // 2. Fast local restore: Check SharedPreferences cached user model first
      final cachedProfile = await _repository.getCachedProfile(authUser?.id);

      if (cachedProfile != null) {
        _currentUser = cachedProfile;
        if (currentSession != null) {
          _authState = Authenticated(user: cachedProfile, session: currentSession);
        }
        notifyListeners();
      } else if (isGuest) {
        final guestId = prefs.getString('zanko_guest_id') ??
            'guest_${DateTime.now().millisecondsSinceEpoch}';
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

      // 3. If there is an active session or auth user, sync remote profile
      if (currentSession != null || authUser != null) {
        final targetUser = currentSession?.user ?? authUser!;
        final profile = await _repository.fetchUserProfile(
          targetUser.id,
          targetUser.email,
          targetUser,
        );

        if (profile != null) {
          _currentUser = profile;
          if (currentSession != null) {
            _authState = Authenticated(user: profile, session: currentSession);
          }
          _syncUserAndVipStatus(profile);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error restoring user session in SupabaseAuthService: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void _startVipWatcher() {
    _vipWatcherTimer?.cancel();
    if (_currentUser == null || _currentUser!.isGuest || _currentUser!.isVip) {
      return;
    }

    // Periodic background watcher to detect when admin approves VIP on admin panel
    _vipWatcherTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final u = _currentUser;
      if (u == null || u.isGuest || u.isVip) {
        _vipWatcherTimer?.cancel();
        return;
      }

      final isVip = await VipFirestoreService.checkAndSyncVipStatus(
        userId: u.id,
        userEmail: u.email,
      );

      if (isVip && _currentUser != null && !_currentUser!.isVip) {
        _vipWatcherTimer?.cancel();
        _currentUser = _currentUser!.copyWith(isVip: true, vipStatus: 'active');
        notifyListeners();
        await reloadUser();
      }
    });
  }

  void _syncUserAndVipStatus(UserModel profile) {
    VipFirestoreService.checkAndSyncVipStatus(
          userId: profile.id,
          userEmail: profile.email,
        )
        .then((isVip) {
          if (isVip && _currentUser != null && !_currentUser!.isVip) {
            _currentUser = _currentUser!.copyWith(
              isVip: true,
              vipStatus: 'active',
            );
            _vipWatcherTimer?.cancel();
            notifyListeners();
          } else if (!isVip) {
            _startVipWatcher();
          }
          VipFirestoreService.syncUserToFirestore(
            _currentUser ?? profile,
          ).ignore();
        })
        .catchError((_) {
          _startVipWatcher();
        });
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
        final profile = await _repository.fetchUserProfile(
          res.user!.id,
          res.user!.email,
          res.user,
        );
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          } else {
            _authState = EmailUnconfirmedState(
              email: res.user!.email ?? email,
              userId: res.user!.id,
            );
          }
          _syncUserAndVipStatus(profile);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_done', true);
            await prefs.setBool('zanko_is_guest', false);
          } catch (_) {}
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
  Future<bool> loginWithRole(
    String email,
    String password,
    UserRole role,
  ) async {
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
          final profile = await _repository.fetchUserProfile(
            user.id,
            email,
            user,
          );
          _currentUser =
              profile ??
              UserModel(
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
          _authState = Authenticated(
            user: _currentUser!,
            session: res.session!,
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_done', true);
            await prefs.setBool('zanko_is_guest', false);
          } catch (_) {}
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
        final profile = await _repository.fetchUserProfile(
          res.user!.id,
          res.user!.email,
          res.user,
        );
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          }
          _syncUserAndVipStatus(profile);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_done', true);
            await prefs.setBool('zanko_is_guest', false);
          } catch (_) {}
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
        final profile = await _repository.fetchUserProfile(
          res.user!.id,
          res.user!.email,
          res.user,
        );
        if (profile != null) {
          _currentUser = profile;
          if (res.session != null) {
            _authState = Authenticated(user: profile, session: res.session!);
          }
          _syncUserAndVipStatus(profile);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_done', true);
            await prefs.setBool('zanko_is_guest', false);
          } catch (_) {}
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
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('zanko_guest_id') ??
        'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('zanko_guest_id', guestId);
    await prefs.setBool('zanko_is_guest', true);
    await prefs.setBool('onboarding_done', true);

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
    _vipWatcherTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('zanko_is_guest');
      await prefs.remove('zanko_guest_id');
      await prefs.remove('zanko_active_user_json');
      await prefs.remove('zanko_active_user_id');
    } catch (_) {}
    await _repository.signOut();
    _currentUser = null;
    _authState = const Unauthenticated();
    notifyListeners();
  }

  @override
  Future<void> reloadUser() async {
    final session = _repository.currentSession;
    final user = session?.user ?? _repository.currentAuthUser;
    if (user != null) {
      final cleanEmail = user.email ?? _currentUser?.email ?? '';

      // Check & sync VIP approval status from Admin panel (Firestore tomartv-67cda)
      bool firestoreIsVip = false;
      try {
        firestoreIsVip = await VipFirestoreService.checkAndSyncVipStatus(
          userId: user.id,
          userEmail: cleanEmail,
        );
        if (firestoreIsVip && _currentUser != null && !_currentUser!.isVip) {
          _currentUser = _currentUser!.copyWith(
            isVip: true,
            vipStatus: 'active',
          );
          _vipWatcherTimer?.cancel();
          notifyListeners();
        }
      } catch (_) {}

      final profile = await _repository.fetchUserProfile(
        user.id,
        user.email,
        user,
      );
      if (profile != null) {
        final shouldBeVip =
            firestoreIsVip || (_currentUser?.isVip == true) || profile.isVip;
        _currentUser = (shouldBeVip && !profile.isVip)
            ? profile.copyWith(isVip: true, vipStatus: 'active')
            : profile;
        if (session != null) {
          _authState = Authenticated(user: _currentUser!, session: session);
        }
        if (_currentUser!.isVip) {
          _vipWatcherTimer?.cancel();
        } else {
          _startVipWatcher();
        }
        VipFirestoreService.syncUserToFirestore(_currentUser!).ignore();
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

      final trimmedName = fullName.trim();
      if (trimmedName.isEmpty) return false;

      if (_currentUser!.isGuest) {
        _currentUser = _currentUser!.copyWith(
          name: trimmedName,
          cityName: cityName?.trim(),
          universityName: universityName?.trim(),
          departmentName: departmentName?.trim(),
          photoUrl: avatarUrl?.trim(),
        );
        notifyListeners();
        return true;
      }

      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;
      final targetId = authUser?.id ?? _currentUser!.id;
      final userEmail = (authUser?.email ?? _currentUser?.email ?? '')
          .trim()
          .toLowerCase();

      // 1. Persist to local device SharedPreferences immediately with multiple keys (ID, email, active)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('zanko_user_name_$targetId', trimmedName);
        await prefs.setString('zanko_active_user_name', trimmedName);
        if (userEmail.isNotEmpty) {
          await prefs.setString('zanko_user_name_$userEmail', trimmedName);
        }
        if (cityName != null && cityName.trim().isNotEmpty) {
          await prefs.setString('zanko_user_city_$targetId', cityName.trim());
          await prefs.setString('zanko_active_user_city', cityName.trim());
          if (userEmail.isNotEmpty)
            await prefs.setString(
              'zanko_user_city_$userEmail',
              cityName.trim(),
            );
        }
        if (universityName != null && universityName.trim().isNotEmpty) {
          await prefs.setString(
            'zanko_user_uni_$targetId',
            universityName.trim(),
          );
          await prefs.setString('zanko_active_user_uni', universityName.trim());
          if (userEmail.isNotEmpty)
            await prefs.setString(
              'zanko_user_uni_$userEmail',
              universityName.trim(),
            );
        }
        if (departmentName != null && departmentName.trim().isNotEmpty) {
          await prefs.setString(
            'zanko_user_dept_$targetId',
            departmentName.trim(),
          );
          await prefs.setString(
            'zanko_active_user_dept',
            departmentName.trim(),
          );
          if (userEmail.isNotEmpty)
            await prefs.setString(
              'zanko_user_dept_$userEmail',
              departmentName.trim(),
            );
        }
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
          await prefs.setString(
            'zanko_user_avatar_$targetId',
            avatarUrl.trim(),
          );
          await prefs.setString('zanko_active_user_avatar', avatarUrl.trim());
          if (userEmail.isNotEmpty)
            await prefs.setString(
              'zanko_user_avatar_$userEmail',
              avatarUrl.trim(),
            );
        }
      } catch (prefErr) {
        debugPrint('Local profile cache notice: $prefErr');
      }

      // 2. Keep Supabase Auth User metadata updated (persists across sessions and is RLS-independent)
      try {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': trimmedName,
              'name': trimmedName,
              if (cityName != null && cityName.trim().isNotEmpty)
                'city_name': cityName.trim(),
              if (universityName != null && universityName.trim().isNotEmpty)
                'university_name': universityName.trim(),
              if (departmentName != null && departmentName.trim().isNotEmpty)
                'department_name': departmentName.trim(),
              if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
              if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                'avatar_url': avatarUrl.trim(),
            },
          ),
        );
      } catch (metaErr) {
        debugPrint('Auth metadata sync notice: $metaErr');
      }

      // 3. Update public.profiles database table (if row exists)
      final updatePayload = <String, dynamic>{
        'full_name': trimmedName,
        if (cityName != null && cityName.trim().isNotEmpty)
          'city_name': cityName.trim(),
        if (universityName != null && universityName.trim().isNotEmpty)
          'university_name': universityName.trim(),
        if (departmentName != null && departmentName.trim().isNotEmpty)
          'department_name': departmentName.trim(),
        if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          'avatar_url': avatarUrl.trim(),
      };

      try {
        await client.from('profiles').update(updatePayload).eq('id', targetId);
      } catch (e) {
        debugPrint('Full profile table update warning: $e');
        try {
          await client
              .from('profiles')
              .update({
                'full_name': trimmedName,
                if (cityName != null && cityName.trim().isNotEmpty)
                  'city_name': cityName.trim(),
                if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                  'avatar_url': avatarUrl.trim(),
              })
              .eq('id', targetId);
        } catch (innerError) {
          debugPrint('Core profile table update warning: $innerError');
        }
      }

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          name: trimmedName,
          cityName: cityName?.trim() ?? _currentUser!.cityName,
          universityName:
              universityName?.trim() ?? _currentUser!.universityName,
          departmentName:
              departmentName?.trim() ?? _currentUser!.departmentName,
          photoUrl: avatarUrl?.trim() ?? _currentUser!.photoUrl,
        );
        VipFirestoreService.syncUserToFirestore(_currentUser!).ignore();
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
        final profile = await _repository.fetchUserProfile(
          res.user!.id,
          res.user!.email,
          res.user,
        );
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
    _vipWatcherTimer?.cancel();
    _repoSub?.cancel();
    super.dispose();
  }
}
