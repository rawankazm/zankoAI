import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/models/user_model.dart';
import 'package:zanko_ai/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Profile System & Security Baseline Tests', () {
    test(
      'Default user registration yields student role and non-vip status',
      () {
        final user = UserModel(
          id: 'uuid-student-1',
          name: 'Kurdish Student',
          email: 'student@zanko.ai',
          role: UserRole.student,
        );

        expect(user.role, equals(UserRole.student));
        expect(user.isVip, isFalse);
        expect(user.vipStatus, equals('none'));
        expect(user.isGuest, isFalse);
      },
    );

    test(
      'UserModel.fromMap safely parses profiles table columns with defaults',
      () {
        final rawProfile = {
          'id': 'uuid-student-2',
          'full_name': 'Zanko Learner',
          'email': 'learner@zanko.ai',
          'role': 'student',
          'plan': 'free',
          'status': 'active',
          'score': 100,
          'rank_title': 'Scholar',
          'is_vip': false,
          'vip_status': 'none',
        };

        final model = UserModel.fromMap(rawProfile);
        expect(model.id, equals('uuid-student-2'));
        expect(model.name, equals('Zanko Learner'));
        expect(model.role, equals(UserRole.student));
        expect(model.isVip, isFalse);
      },
    );

    test(
      'Client-forged admin role payload is prevented in safe deserialization',
      () {
        // If a malicious payload tries to inject invalid or unexpected role strings
        final forgedPayload = {
          'id': 'uuid-student-3',
          'full_name': 'Sneaky Attacker',
          'email': 'attacker@zanko.ai',
          'role': 'unknown_or_superadmin',
        };

        final model = UserModel.fromMap(forgedPayload);
        // Defaults safely to student
        expect(model.role, equals(UserRole.student));
      },
    );
  });

  group('RLS Error Mapping & Exception Handling Tests', () {
    test(
      'Translates permission denied / RLS violation into clear Kurdish message',
      () {
        const ex = AuthException(
          'new row violates row-level security policy for table "payments"',
          code: '42501',
        );
        final mapped = SupabaseAuthRepository.mapAuthException(ex);
        expect(mapped.message, isNotEmpty);
      },
    );

    test('Maps provider_disabled to Kurdish server settings guidance', () {
      const ex = AuthException(
        'Provider (issuer "https://accounts.google.com") is not enabled',
        code: 'provider_disabled',
      );
      final mapped = SupabaseAuthRepository.mapAuthException(ex);
      expect(mapped.message, contains('Supabase'));
      expect(mapped.message, contains('Providers'));
    });
  });
}
