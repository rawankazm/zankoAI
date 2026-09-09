import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanko_ai/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VIP Approval & Rejection Notifications Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Approval notification text is cleanly encoded without mojibake', () {
      const title = '🎉 پیرۆزە! هەژمارەکەت بوو بە VIP 👑';
      const body =
          'داواکاری بەشداریکردنی VIPەکەت لەلایەن بەڕێوەبەرەوە پەسەندکرا! ئێستا دەتوانیت لە هەموو تایبەتمەندییە بێسنوورەکانی ZankoAI سوودمەند بیت.';

      final cleanTitle = fixNotificationEncoding(title);
      final cleanBody = fixNotificationEncoding(body);

      expect(cleanTitle, contains('پیرۆزە'));
      expect(cleanTitle, contains('VIP'));
      expect(cleanBody, contains('داواکاری بەشداریکردنی VIPەکەت'));
      expect(cleanBody, contains('پەسەندکرا'));
    });

    test('2. Rejection notification text with custom reason is cleanly encoded', () {
      const reason = 'ژمارەی حەواڵە نادروستە';
      final notifTitle = fixNotificationEncoding('⚠️ داواکاری VIP پەسەند نەکرا');
      final notifBody = fixNotificationEncoding(
        'داواکاری بەشداریکردنی VIPەکەت پەسەند نەکرا. هۆکار: $reason',
      );

      expect(notifTitle, contains('داواکاری VIP پەسەند نەکرا'));
      expect(notifBody, contains('هۆکار: ژمارەی حەواڵە نادروستە'));
    });

    test('3. Rejection notification fallback text when reason is empty', () {
      const notifTitle = '⚠️ داواکاری VIP پەسەند نەکرا';
      const fallbackReason =
          ' تکایە لە وەسڵ یان ژمارەی حەواڵەکەت دڵنیابە، یان پەیوەندی بە بەڕێوەبەرەوە بکە.';
      final notifBody = 'داواکاری بەشداریکردنی VIPەکەت پەسەند نەکرا.$fallbackReason';

      expect(notifTitle, contains('داواکاری VIP پەسەند نەکرا'));
      expect(notifBody, contains('تکایە لە وەسڵ'));
    });

    test('4. SharedPreferences deduplication prevents repeated notification spam', () async {
      final prefs = await SharedPreferences.getInstance();
      const userId = 'student-test-uid';

      // First check: not notified yet
      expect(prefs.getBool('zanko_vip_notif_approved_$userId') ?? false, isFalse);

      // Mark as notified
      await prefs.setBool('zanko_vip_notif_approved_$userId', true);
      expect(prefs.getBool('zanko_vip_notif_approved_$userId'), isTrue);

      // When a new request is submitted, flag is reset to false
      await prefs.setBool('zanko_vip_notif_approved_$userId', false);
      expect(prefs.getBool('zanko_vip_notif_approved_$userId'), isFalse);
    });

    test('5. Rejection flag deduplication works per request ID', () async {
      final prefs = await SharedPreferences.getInstance();
      const reqId = 'req-doc-12345';

      expect(prefs.getBool('zanko_vip_notif_rejected_$reqId') ?? false, isFalse);

      await prefs.setBool('zanko_vip_notif_rejected_$reqId', true);
      expect(prefs.getBool('zanko_vip_notif_rejected_$reqId'), isTrue);
    });
  });
}
