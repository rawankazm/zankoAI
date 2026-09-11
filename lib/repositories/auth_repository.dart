import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_state.dart';
import '../models/user_model.dart';

/// Clean repository contract decoupling auth data sources from state and presentation
abstract class AuthRepository {
  /// Stream emitting real-time domain auth states (session updates, recovery, signouts)
  Stream<ZankoAuthState> get authStateChanges;

  /// Current active Supabase session, if available
  Session? get currentSession;

  /// Current active Supabase user, if available
  User? get currentAuthUser;

  /// Register user with email, password, and profile metadata
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.student,
    String? universityName,
    String? departmentName,
    String? cityName,
  });

  /// Authenticate user via email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Authenticate user with Google OAuth (native ID token via GoogleSignIn)
  Future<AuthResponse?> signInWithGoogle();

  /// Authenticate user with Apple Sign-In
  /// Captures and caches Apple's first-time name payload safely
  Future<AuthResponse?> signInWithApple();

  /// Trigger a password recovery email to the given address
  Future<void> sendPasswordResetEmail(String email);

  /// Complete password reset by updating the active password
  Future<UserResponse> updatePassword(String newPassword);

  /// Resend confirmation email for unverified user accounts
  Future<void> resendVerificationEmail(String email);

  /// End current session and sign out from Supabase Auth
  Future<void> signOut();

  /// Delete the current authenticated user's account and profile
  Future<void> deleteAccount();

  /// Explicitly refresh the current user's session tokens
  Future<AuthResponse> refreshSession();

  /// Fetch user profile from public.profiles or user metadata
  Future<UserModel?> fetchUserProfile(
    String userId, [
    String? fallbackEmail,
    User? providedUser,
  ]);

  /// Fetch user profile quickly from local storage cache
  Future<UserModel?> getCachedProfile([String? userId]);
}
