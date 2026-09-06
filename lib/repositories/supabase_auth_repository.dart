import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_state.dart';
import '../core/config/env.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Production Supabase Auth repository implementation with zero Firebase dependencies
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;
  final StreamController<ZankoAuthState> _authStateController = StreamController<ZankoAuthState>.broadcast();

  StreamSubscription<AuthState>? _subSubscription;

  SupabaseAuthRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    _initListener();
  }

  @override
  Stream<ZankoAuthState> get authStateChanges => _authStateController.stream;

  @override
  Session? get currentSession => _supabase.auth.currentSession;

  @override
  User? get currentAuthUser => _supabase.auth.currentUser;

  void _initListener() {
    _subSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (session != null) {
            final profile = await fetchUserProfile(session.user.id, session.user.email);
            if (profile != null) {
              _authStateController.add(Authenticated(user: profile, session: session));
            }
          }
          break;
        case AuthChangeEvent.passwordRecovery:
          _authStateController.add(PasswordRecoveryState(
            email: session?.user.email,
            recoveryToken: session?.accessToken,
          ));
          break;
        case AuthChangeEvent.signedOut:
        // ignore: deprecated_member_use
        case AuthChangeEvent.userDeleted:
          _authStateController.add(const Unauthenticated());
          break;
        case AuthChangeEvent.mfaChallengeVerified:
        case AuthChangeEvent.initialSession:
          if (session != null) {
            final profile = await fetchUserProfile(session.user.id, session.user.email);
            if (profile != null) {
              _authStateController.add(Authenticated(user: profile, session: session));
            }
          } else {
            _authStateController.add(const Unauthenticated());
          }
          break;
      }
    });
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
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: AppEnv.authRedirectUrl,
        data: {
          'full_name': fullName.trim(),
          'role': role.toString().split('.').last,
          'university_name': universityName,
          'department_name': departmentName,
          'city_name': cityName,
        },
      );

      final user = response.user;
      if (user != null) {
        // If session is present, user was auto-confirmed
        if (response.session != null) {
          try {
            await _supabase.from('profiles').update({
              'full_name': fullName.trim(),
              'city_name': cityName,
            }).eq('id', user.id);
          } catch (_) {}
        }
      }

      return response;
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('signUpWithEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('signInWithEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final String? serverClientId = AppEnv.googleWebClientId.contains('YOUR_')
          ? null
          : AppEnv.googleWebClientId;
      final String? iosClientId = (!kIsWeb && Platform.isIOS && !AppEnv.googleIosClientId.contains('YOUR_'))
          ? AppEnv.googleIosClientId
          : null;

      final googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: serverClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled flow
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException('پەیوەندی لەگەڵ گووگڵ سەرکەوتوو نەبوو (ID Token بەردەست نەبوو).');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user != null) {
        final displayName = googleUser.displayName ?? user.userMetadata?['full_name'];
        final avatarUrl = googleUser.photoUrl ?? user.userMetadata?['avatar_url'];
        if (displayName != null && displayName.isNotEmpty) {
          try {
            await _supabase.from('profiles').update({
              'full_name': displayName,
              ...?avatarUrl != null ? {'avatar_url': avatarUrl} : null,
            }).eq('id', user.id);
            await _supabase.auth.updateUser(
              UserAttributes(data: {
                'full_name': displayName,
                ...?avatarUrl != null ? {'avatar_url': avatarUrl} : null,
              }),
            );
          } catch (_) {}
        }
      }

      return response;
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      rethrow;
    }
  }

  @override
  Future<AuthResponse?> signInWithApple() async {
    try {
      final rawNonce = _generateRandomString();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('پەیوەندی لەگەڵ ئەپڵ سەرکەوتوو نەبوو (Identity Token بەردەست نەبوو).');
      }

      // Safe capture: Apple only transmits givenName & familyName on FIRST authorization
      final givenName = credential.givenName ?? '';
      final familyName = credential.familyName ?? '';
      final assembledAppleName = '$givenName $familyName'.trim();

      // Persist in local storage as a fallback keyed by Apple user identifier
      final prefs = await SharedPreferences.getInstance();
      final userKey = credential.userIdentifier != null
          ? 'apple_name_${credential.userIdentifier}'
          : 'apple_saved_name';

      if (assembledAppleName.isNotEmpty) {
        await prefs.setString(userKey, assembledAppleName);
        await prefs.setString('apple_saved_name', assembledAppleName);
      }

      final cachedName = prefs.getString(userKey) ?? prefs.getString('apple_saved_name');
      final effectiveName = assembledAppleName.isNotEmpty
          ? assembledAppleName
          : (cachedName ?? 'Apple User');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final user = response.user;
      if (user != null && effectiveName.isNotEmpty && effectiveName != 'Apple User') {
        try {
          await _supabase.from('profiles').update({
            'full_name': effectiveName,
          }).eq('id', user.id);
          await _supabase.auth.updateUser(
            UserAttributes(data: {'full_name': effectiveName}),
          );
        } catch (_) {}
      }

      return response;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw AuthException(e.message);
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('signInWithApple error: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppEnv.passwordResetRedirectUrl,
      );
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('sendPasswordResetEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
      return response;
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('updatePassword error: $e');
      rethrow;
    }
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: AppEnv.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw mapAuthException(e);
    } catch (e) {
      debugPrint('resendVerificationEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    _authStateController.add(const Unauthenticated());
  }

  @override
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        // Attempt Postgres RPC security-definer function
        await _supabase.rpc('delete_user_account');
      } catch (rpcError) {
        debugPrint('RPC delete_user_account failed, using profile cleanup fallback: $rpcError');
        try {
          await _supabase.from('profiles').delete().eq('id', user.id);
        } catch (_) {}
      }
      await signOut();
    }
  }

  @override
  Future<AuthResponse> refreshSession() async {
    try {
      return await _supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw mapAuthException(e);
    }
  }

  @override
  Future<UserModel?> fetchUserProfile(String userId, [String? fallbackEmail]) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        return UserModel.fromMap(res);
      }

      // Fallback user model
      final email = fallbackEmail ?? _supabase.auth.currentUser?.email ?? 'user@zanko.edu';
      return UserModel(
        id: userId,
        name: email.split('@').first,
        email: email,
        role: UserRole.student,
        isVip: false,
        vipStatus: 'none',
      );
    } catch (e) {
      debugPrint('Error fetching user profile in repository: $e');
      return null;
    }
  }

  /// Cryptographic helper to produce random nonces for Apple Sign-In
  String _generateRandomString([int length = 32]) {
    final charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Map Supabase auth exceptions into friendly, localized Kurdish explanations
  static AuthException mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase() ?? '';

    if (code == 'provider_disabled' || code == 'email_provider_disabled' || msg.contains('is not enabled') || msg.contains('provider is disabled') || msg.contains('email signups are disabled')) {
      return const AuthException('ئەم خزمەتگوزارییە لە سێرڤەری Supabase ناچالاک کراوە. تکایە لە بەشی Providers سویچەکەی چالاک (Enable) بکە.');
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return const AuthException('ئیمەیڵەکەت هێشتا پشتڕاست نەکراوەتەوە. تکایە سەیری ئیمەیڵەکەت بکە یان لێرەوە دووبارە بینێرەوە.');
    }
    if (code == 'invalid_credentials' || msg.contains('invalid login credentials') || msg.contains('invalid credential')) {
      return const AuthException('ئیمەیڵ یان وشەی نهێنی هەڵەیە. تکایە دڵنیابەرەوە.');
    }
    if (msg.contains('already registered') || msg.contains('user already exists') || msg.contains('email-already-in-use')) {
      return const AuthException('ئەم ئیمەیڵە پێشتر تۆمارکراوە. تکایە چوونەژوورەوە بکە.');
    }
    if (msg.contains('weak-password') || msg.contains('password should be at least')) {
      return const AuthException('وشەی نهێنی زۆر لاوازە (لانی کەم ٦ پیت بنووسە).');
    }
    if (code == 'over_email_send_rate_limit' || msg.contains('rate limit') || msg.contains('too many requests')) {
      return const AuthException('تکایە کەمێک چاوەڕێ بکە پێش ئەوەی دووبارە داواکاری بنێریتەوە.');
    }
    if (msg.contains('network') || msg.contains('socketexception') || msg.contains('failed host lookup') || msg.contains('handshakeexception')) {
      return const AuthException('کێشەی هێڵی ئینتەرنێت هەیە. تکایە پەیوەندی هێڵەکەت بپشکنە.');
    }
    if (msg.contains('jwt expired') || msg.contains('token expired') || msg.contains('session expired') || code == 'session_expired') {
      return const AuthException('ماوەی چوونەژوورەوەت بەسەرچووە. تکایە دووبارە بچۆ ژوورەوە.');
    }
    if (msg.contains('canceled') || msg.contains('cancelled') || code == 'canceled') {
      return const AuthException('پڕۆسەی چوونەژوورەوە هەڵوەشێنرایەوە.');
    }
    if (msg.contains('access_denied') || msg.contains('oauth')) {
      return const AuthException('دەستگەیشتن بە ئەکاونت ڕەتکرایەوە لە لایەن خزمەتگوزاری چوونەژوورەوە.');
    }

    return e;
  }

  void dispose() {
    _subSubscription?.cancel();
    _authStateController.close();
  }
}
