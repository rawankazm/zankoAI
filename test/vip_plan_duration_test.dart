import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/models/user_model.dart';
import 'package:zanko_ai/services/vip_firestore_service.dart';

void main() {
  group('VIP Plan Duration & Renewal Tests', () {
    test('1. 1 Month Plan resolves to exactly 30 days', () {
      final days = VipFirestoreService.calculatePlanDays(plan: '1_month');
      expect(days, equals(30));
    });

    test('2. 3 Months Plan resolves to exactly 90 days', () {
      final days = VipFirestoreService.calculatePlanDays(plan: '3_months');
      expect(days, equals(90));
    });

    test('3. 9 Months Plan resolves to exactly 270 days', () {
      final days = VipFirestoreService.calculatePlanDays(plan: '9_months');
      expect(days, equals(270));
    });

    test('4. Price fallback for 3 Months (12,000 IQD) resolves to 90 days', () {
      final days = VipFirestoreService.calculatePlanDays(price: 12000);
      expect(days, equals(90));
    });

    test('5. Price fallback for 9 Months (40,000 IQD) resolves to 270 days', () {
      final days = VipFirestoreService.calculatePlanDays(price: 40000);
      expect(days, equals(270));
    });

    test('6. Price fallback for 1 Month (5,000 IQD) resolves to 30 days', () {
      final days = VipFirestoreService.calculatePlanDays(price: 5000);
      expect(days, equals(30));
    });

    test('7. UserModel correctly parses vip_expiry and calculates vipDaysLeft', () {
      final futureExpiry = DateTime.now().add(const Duration(days: 90));
      final user = UserModel.fromMap({
        'id': 'test-uuid',
        'name': 'Rawan',
        'email': 'rawan@zanko.edu',
        'is_vip': true,
        'vip_status': 'active',
        'vip_expiry': futureExpiry.toIso8601String(),
      });

      expect(user.isVip, isTrue);
      expect(user.vipExpiry, isNotNull);
      expect(user.vipDaysLeft, greaterThanOrEqualTo(89));
      expect(user.vipDaysLeft, lessThanOrEqualTo(90));
    });

    test('8. UserModel for 9-month plan calculates ~270 days remaining', () {
      final futureExpiry = DateTime.now().add(const Duration(days: 270));
      final user = UserModel.fromMap({
        'id': 'test-uuid-9m',
        'name': 'Rawan 9M',
        'email': 'rawan9@zanko.edu',
        'is_vip': true,
        'vip_status': 'active',
        'vip_expiry': futureExpiry.toIso8601String(),
      });

      expect(user.isVip, isTrue);
      expect(user.vipDaysLeft, greaterThanOrEqualTo(269));
      expect(user.vipDaysLeft, lessThanOrEqualTo(270));
    });

    test('9. Explicit durationDays parameter overrides default plan string', () {
      final days = VipFirestoreService.calculatePlanDays(
        plan: 'custom',
        durationDays: 180,
      );
      expect(days, equals(180));
    });

    test('10. UserModel toMap preserves vip_expiry serialization', () {
      final expiry = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        id: 'id-123',
        name: 'Student',
        email: 'student@zanko.edu',
        role: UserRole.student,
        isVip: true,
        vipExpiry: expiry,
      );

      final map = user.toMap();
      expect(map['vip_expiry'], isNotNull);
      expect(map['vip_expiry'], equals(expiry.toIso8601String()));
    });
  });
}
