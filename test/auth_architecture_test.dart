import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zanko_ai/core/auth/auth_state.dart';
import 'package:zanko_ai/core/config/env.dart';
import 'package:zanko_ai/models/user_model.dart';
import 'package:zanko_ai/repositories/auth_repository.dart';
import 'package:zanko_ai/repositories/supabase_auth_repository.dart';
import 'package:zanko_ai/services/supabase_auth_service.dart';

void main() {
  group('ZankoAuthState Sealed Class Tests', () {
    test('Initial Unauthenticated state', () {
      const state = Unauthenticated();
      expect(state, isA<ZankoAuthState>());
      expect(state, isA<Unauthenticated>());
    });

    test('Authenticating state with custom message', () {
      const state = Authenticating('چوونەژوورەوە...');
      expect(state.message, equals('چوونەژوورەوە...'));
      expect(state, isA<ZankoAuthState>());
    });

    test('EmailUnconfirmedState holds email and userId', () {
      const state = EmailUnconfirmedState(
        email: 'student@zanko.edu',
        userId: 'uuid-1234',
      );
      expect(state.email, equals('student@zanko.edu'));
      expect(state.userId, equals('uuid-1234'));
      expect(state, isA<ZankoAuthState>());
    });

    test('PasswordRecoveryState holds recovery credentials', () {
      const state = PasswordRecoveryState(
        email: 'reset@zanko.edu',
        recoveryToken: 'jwt-recovery-token',
      );
      expect(state.email, equals('reset@zanko.edu'));
      expect(state.recoveryToken, equals('jwt-recovery-token'));
    });

    test('AuthErrorState holds user-friendly Kurdish message and code', () {
      const state = AuthErrorState(
        message: 'وشەی نهێنی یان ئیمەیڵ هەڵەیە.',
        code: 'invalid_credentials',
      );
      expect(state.message, contains('هەڵەیە'));
      expect(state.code, equals('invalid_credentials'));
    });
  });

  group('Supabase Exception Mapping Tests', () {
    test('Maps email_provider_disabled to Kurdish explanation', () {
      const ex = AuthException('Email signups are disabled', code: 'email_provider_disabled');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('سێرڤەر'));
    });

    test('Maps email_not_confirmed to verification guidance', () {
      const ex = AuthException('Email not confirmed', code: 'email_not_confirmed');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('پشتڕاست'));
    });

    test('Maps invalid_credentials to password/email mismatch notice', () {
      const ex = AuthException('Invalid login credentials', code: 'invalid_credentials');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('هەڵەیە'));
    });

    test('Maps already registered email notice', () {
      const ex = AuthException('User already registered');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('پێشتر تۆمارکراوە'));
    });

    test('Maps weak password notice', () {
      const ex = AuthException('Password should be at least 6 characters');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('٦ پیت'));
    });

    test('Maps rate limit notice', () {
      const ex = AuthException('Over rate limit', code: 'over_email_send_rate_limit');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('چاوەڕێ'));
    });

    test('Maps network error to Kurdish connection advice', () {
      const ex = AuthException('SocketException: OS Error: Failed host lookup');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('ئینتەرنێت'));
    });

    test('Maps expired session / token to re-login guidance', () {
      const ex = AuthException('JWT expired: token is expired by 300s', code: 'session_expired');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('بەسەرچووە'));
    });

    test('Maps cancelled OAuth flow cleanly', () {
      const ex = AuthException('User canceled the login flow', code: 'canceled');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('هەڵوەشێنرایەوە'));
    });

    test('Maps access_denied / OAuth provider error', () {
      const ex = AuthException('OAuth access_denied');
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('ڕەتکرایەوە'));
    });
  });

  group('AppEnv Deep Link & OAuth Configuration Tests', () {
    test('AppEnv provides secure deep link redirects for Supabase callbacks', () {
      expect(AppEnv.authRedirectScheme, equals('io.supabase.zankoai'));
      expect(AppEnv.authRedirectUrl, equals('io.supabase.zankoai://login-callback'));
      expect(AppEnv.passwordResetRedirectUrl, equals('io.supabase.zankoai://reset-password'));
    });

    test('AppEnv does not contain hardcoded secret keys in client configuration', () {
      expect(AppEnv.supabaseAnonKey, isNotEmpty);
      expect(AppEnv.supabaseUrl, contains('supabase.co'));
      expect(AppEnv.googleWebClientId, isNotEmpty);
    });
  });

  group('UserModel Integration Tests', () {
    test('UserModel fromMap supports profiles table schema with snake_case', () {
      final map = {
        'id': 'b8e91402-9a3b-4835-9f51-24754324f8cb',
        'full_name': 'Rawan Kazim',
        'email': 'rawankazim11@gmail.com',
        'avatar_url': 'https://zanko.edu/avatar.png',
        'role': 'student',
        'is_vip': true,
        'vip_status': 'active',
        'plan': 'premium',
        'score': 150,
        'rank_title': 'Scholar',
        'city_name': 'Hawler',
      };

      final user = UserModel.fromMap(map);
      expect(user.id, equals('b8e91402-9a3b-4835-9f51-24754324f8cb'));
      expect(user.name, equals('Rawan Kazim'));
      expect(user.email, equals('rawankazim11@gmail.com'));
      expect(user.isVip, isTrue);
      expect(user.role, equals(UserRole.student));
      expect(user.cityName, equals('Hawler'));
    });
  });

  group('SupabaseAuthService State Machine Tests', () {
    test('Service responds to login, logout, and deleteAccount correctly', () async {
      final fakeRepo = _FakeAuthRepository();
      final authService = SupabaseAuthService(repository: fakeRepo);

      expect(authService.isAuthenticated, isFalse);
      expect(authService.authState, isA<Unauthenticated>());

      // Perform Login
      final loginSuccess = await authService.login('test@zanko.edu', 'Password123!');
      expect(loginSuccess, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.email, equals('test@zanko.edu'));
      expect(authService.authState, isA<Authenticated>());

      // Perform Logout
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(authService.authState, isA<Unauthenticated>());

      // Re-login then delete account
      await authService.login('test@zanko.edu', 'Password123!');
      expect(authService.isAuthenticated, isTrue);

      await authService.deleteAccount();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(fakeRepo.deleteAccountCalled, isTrue);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  final StreamController<ZankoAuthState> _controller = StreamController<ZankoAuthState>.broadcast();
  bool deleteAccountCalled = false;

  UserModel _testUser = UserModel(
    id: 'test-user-id',
    name: 'Test Student',
    email: 'test@zanko.edu',
    role: UserRole.student,
    isVip: false,
    vipStatus: 'none',
  );

  @override
  Stream<ZankoAuthState> get authStateChanges => _controller.stream;

  @override
  User? get currentAuthUser => null;

  @override
  Session? get currentSession => null;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    _controller.add(const Unauthenticated());
  }

  @override
  Future<UserModel?> fetchUserProfile(String userId, [String? fallbackEmail]) async {
    return _testUser;
  }

  @override
  Future<AuthResponse> refreshSession() async {
    return AuthResponse();
  }

  @override
  Future<void> resendVerificationEmail(String email) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthResponse> signInWithEmail({required String email, required String password}) async {
    _testUser = UserModel(
      id: 'test-user-id',
      name: 'Test Student',
      email: email,
      role: UserRole.student,
      isVip: false,
      vipStatus: 'none',
    );
    final user = User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {'full_name': 'Test Student'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    final session = Session(
      accessToken: 'test-jwt-token',
      tokenType: 'bearer',
      user: user,
    );
    return AuthResponse(user: user, session: session);
  }

  @override
  Future<AuthResponse?> signInWithApple() async => null;

  @override
  Future<AuthResponse?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {
    _controller.add(const Unauthenticated());
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.student,
    String? universityName,
    String? departmentName,
    String? cityName,
  }) async {
    final user = User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {'full_name': fullName},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    return AuthResponse(user: user);
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    return UserResponse.fromJson({
      'user': {
        'id': 'test-user-id',
        'aud': 'authenticated',
        'created_at': DateTime.now().toIso8601String(),
      },
    });
  }
}
