import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/notification_service.dart';

void main() {
  group('Notification Mojibake Repair Tests', () {
    test('Repairs Windows-1252/Latin-1 Mojibake from push notification', () {
      // Exact title and body from the user screenshot
      const corruptedTitle = 'ðŸŽ‰ Ù¾ÛŒØ±Û†Ø²Û•! Ø¨Û•Ø´Ø¯Ø§Ø±Ø¨ÙˆÙˆÙ†ÛŒ VIPÛŒ ØªÛ† Ú†Ø§Ù„Ø§Ú©Ú©Ø±Ø§';
      const corruptedBody = 'Ù¾ÛŒØ±Û†Ø²Û•! Ù‡Û•Ú˜Ù…Ø§Ø±Û•Ú©Û•Øª Ù„Û•Ú¯Û•Úµ Ø²Û•Ù†Ú©Û† ZankoAI Ø¨Û• Ø³Û•Ø±Ú©Û•ÙˆØªÙˆÙˆÛŒÛŒ Ø¨ÙˆÙˆÛ• VIP ðŸ‘‘. Ø¦ÛŽØ³ØªØ§ Ø¯Û•ØªÙˆØ§Ù†ÛŒØª Ø³ÙˆØ¯ Ù„Û• Ø³Û•Ø±Ø¬Û•Ù… ØªØ§ÛŒØ¨Û•ØªÙ…Û•Ù†Ø¯ÛŒÛŒÛ• Ø¨ÛŽØ³Ù†ÙˆÙˆØ±Û•Ú©Ø§Ù† Ùˆ Ø¯Û•Ù†Ú¯ÛŒ Ú˜ÛŒØ±ÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ ÙˆÛ•Ø±Ø¨Ú¯Ø±ÛŒØª.';

      final cleanTitle = fixNotificationEncoding(corruptedTitle);
      final cleanBody = fixNotificationEncoding(corruptedBody);

      expect(cleanTitle, contains('🎉'));
      expect(cleanTitle, contains('پیرۆزە!'));
      expect(cleanTitle, contains('VIP'));

      expect(cleanBody, contains('پیرۆزە!'));
      expect(cleanBody, contains('هەژمارەکەت لەگەڵ زەنکۆ ZankoAI'));
      expect(cleanBody, contains('👑'));
    });

    test('Leaves already-clean Kurdish text intact without alteration', () {
      const cleanKurdish = '🎉 پیرۆزە! هەژمارەکەت لەگەڵ زەنکۆ ZankoAI چالاککرا';
      expect(fixNotificationEncoding(cleanKurdish), equals(cleanKurdish));
    });

    test('Leaves clean English text intact', () {
      const cleanEnglish = 'Welcome to ZankoAI Student Portal!';
      expect(fixNotificationEncoding(cleanEnglish), equals(cleanEnglish));
    });
  });
}
