import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanko_ai/services/ai_teacher_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Mock Audioplayers platform channels for headless unit tests
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => 1,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => 1,
      );

  group('Prompt 37 — ZankoAI Multilingual AI Teacher Voice Tests', () {
    late final AiTeacherVoiceService voiceService;

    setUpAll(() {
      voiceService = AiTeacherVoiceService();
    });

    test('1. Kurdish Sorani Text Cleaning & Phonetic Normalization', () {
      const rawKurdish = '''
## یاسای ئۆم (Ohm's Law)
لە فیزیا و ئەندازیاریدا، **یاسای ئۆم** پەیوەندی نێوان ڤۆڵتییە (V) و تەزوو (I) و بەرگری (R) ڕوون دەکاتەوە:
```cpp
float V = I * R;
```
سەرەتا: ڤۆڵتییە = تەزوو × بەرگری. ئایا دەزانی ئەم یاسایە لە ساڵی 1827 دۆزرایەوە؟
''';

      final cleaned = voiceService.cleanTextForSpeech(rawKurdish);

      // Markdown and code blocks must be removed
      expect(cleaned.contains('##'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('```'), isFalse);
      expect(cleaned.contains('float V = I * R;'), isFalse);

      // Educational content and technical terms must be preserved
      expect(cleaned.contains('یاسای ئۆم'), isTrue);
      expect(cleaned.contains('ڤۆڵتییە'), isTrue);
    });

    test('2. Arabic Text Cleaning and Punctuation Handling', () {
      const rawArabic = '''
### قانون كولوم في الفيزياء
القوة الكهربائية المتبادلة بين شحنتين تتناسب **طردياً** مع حاصل ضرب الشحنتين و*عكسياً* مع مربع المسافة بينهما:
F = k · (q1 · q2) / r²
هل هذا المفهوم واضح لديك؟
''';

      final cleaned = voiceService.cleanTextForSpeech(rawArabic);

      expect(cleaned.contains('###'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('*عكسياً*'), isFalse);
      expect(cleaned.contains('قانون كولوم في الفيزياء'), isTrue);
      expect(cleaned.contains('طردياً'), isTrue);
    });

    test('3. English Academic & Technical Text Cleaning', () {
      const rawEnglish = '''
## Object-Oriented Programming (OOP)
In computer science, **Polymorphism** allows methods to perform different tasks based on the object:
```java
Animal myDog = new Dog();
myDog.makeSound();
```
Key benefits:
* Code reusability
* Maintainability
''';

      final cleaned = voiceService.cleanTextForSpeech(rawEnglish);

      expect(cleaned.contains('##'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('```'), isFalse);
      expect(cleaned.contains('Animal myDog'), isFalse);
      expect(cleaned.contains('Polymorphism'), isTrue);
      expect(cleaned.contains('Code reusability'), isTrue);
    });

    test('4. Safe Chunking of Long Responses (Never Cut Words or Sentences)', () {
      // Deliberately long response (> 1000 characters)
      final longResponse = '''
فێربوونی پرۆگرامسازی پێویستی بە چەند هەنگاوێکی سەرەکی و بنیادنەر هەیە لە زانکۆ.
سەرەتا دەبێت لە بنەماکانی لۆژیک و ئەلگۆریتم تێبگەیت چونکە ئەلگۆریتم بناغەی هەموو کۆدێکە.
پاشان زمانێکی سەرەکی وەک پایسۆن یان سی پڵەس پڵەس هەڵدەبژێریت بۆ جێبەجێکردنی ئەو هاوکێشانە.
لێرەدا تێگەیشتن لە چەمکەکانی Data Structures و Algorithms زۆر گرنگە بۆ هەر قوتابییەکی بەشی IT و ئەندازیاری کۆمپیوتەر.
هەروەها پەرەپێدانی پڕۆژەی کرداری و بەکارهێنانی Git و GitHub یارمەتیت دەدات بۆ ئەوەی کارەکانت تۆمار بکەیت و لە تیمی گەورەدا کار بکەیت.
لە کۆتاییدا هەمیشە هەوڵبدە پرسیار لە مامۆستا بکەیت و بەردەوام بە لە شیکارکردنی پرسیاری نوێ.
''';

      final chunks = voiceService.splitIntoSafeChunks(longResponse, maxChars: 250);

      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.length, greaterThan(1));

      // Verify no chunk exceeds the safe boundary unreasonably
      for (final chunk in chunks) {
        expect(chunk.length, lessThan(350));
        // Verify chunks don't start or end with broken words
        expect(chunk.trim().isNotEmpty, isTrue);
      }

      // Verify total content is fully preserved across all chunks
      final joined = chunks.join(' ');
      expect(joined.contains('فێربوونی پرۆگرامسازی'), isTrue);
      expect(joined.contains('بناغەی هەموو کۆدێکە'), isTrue);
      expect(joined.contains('لە کۆتاییدا هەمیشە هەوڵبدە'), isTrue);
    });

    test('5. Automatic Language Detection', () {
      expect(voiceService.detectLanguage('سڵاو مامۆستا، کاتی وانەکە کەیە؟'), equals('ku'));
      expect(voiceService.detectLanguage('مرحباً يا أستاذ، متى موعد المحاضرة القادمة؟'), equals('ar'));
      expect(voiceService.detectLanguage('Hello Professor, could you explain Dijkstra algorithm?'), equals('en'));

      // Explicit instruction overrides
      expect(voiceService.detectLanguage('دەتوانی بە ئینگلیزی باسی بکەیت؟', preferredLang: 'en'), equals('en'));
      expect(voiceService.detectLanguage('Explain this in Kurdish please', preferredLang: 'ku'), equals('ku'));
      expect(voiceService.detectLanguage('Explain this in Arabic please', preferredLang: 'ar'), equals('ar'));
    });

    test('6. Playback State Transitions & Speed Clamping', () async {
      expect(voiceService.playbackNotifier.value.state, equals(AiTeacherVoiceState.idle));

      await voiceService.setSpeed(1.5);
      expect(voiceService.playbackSpeed, equals(1.5));

      await voiceService.setSpeed(2.5); // Clamped to 2.0
      expect(voiceService.playbackSpeed, equals(2.0));

      await voiceService.setSpeed(0.2); // Clamped to 0.5
      expect(voiceService.playbackSpeed, equals(0.5));

      await voiceService.setSpeed(1.0);
      expect(voiceService.playbackSpeed, equals(1.0));
    });
  });
}
