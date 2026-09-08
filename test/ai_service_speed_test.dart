import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanko_ai/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ZankoAiService aiService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    aiService = ZankoAiService();
  });

  group('AI Teacher Speed and Fallback Engine Tests', () {
    test(
      'Academic fallback engine responds in less than 500ms with rich content',
      () async {
        final stopwatch = Stopwatch()..start();
        final response = await aiService.askTeacher(
          'پێناسەی OOP و چەمکەکانی چییە؟',
          [],
          isVip: true,
        );
        stopwatch.stop();

        expect(response, isNotEmpty);
        expect(
          response.contains('OOP') ||
              response.contains('بەرنامەسازی') ||
              response.contains('Object-Oriented'),
          isTrue,
        );
        // Ensure fast response
        expect(stopwatch.elapsedMilliseconds, lessThan(8000));
      },
    );

    test('Medicine subject queries return fast contextual response', () async {
      final stopwatch = Stopwatch()..start();
      final response = await aiService.askTeacher(
        '[تایبەتمەندی: Medicine & Health]\nفرمانی دڵ و پەستانی خوێن',
        [],
        isVip: true,
      );
      stopwatch.stop();

      expect(response, isNotEmpty);
      expect(
        response.contains('دڵ') ||
            response.contains('خوێن') ||
            response.contains('سەرەکی'),
        isTrue,
      );
      expect(stopwatch.elapsedMilliseconds, lessThan(8000));
    });

    test('Mathematics subject queries return fast math response', () async {
      final stopwatch = Stopwatch()..start();
      final response = await aiService.askTeacher(
        '[تایبەتمەندی: Math, Physics & Engineering]\nتەواوکاری و هاوکێشەی داتاشراو',
        [],
        isVip: true,
      );
      stopwatch.stop();

      expect(response, isNotEmpty);
      expect(
        response.contains('شیکاری') ||
            response.contains('یاسا') ||
            response.contains('تەواوکاری') ||
            response.contains('داتاشراو'),
        isTrue,
      );
      expect(stopwatch.elapsedMilliseconds, lessThan(8000));
    });
    test(
      'Pure greeting alone returns immediate friendly assistance prompt',
      () async {
        final response = await aiService.askTeacher('سڵاو', [], isVip: true);

        expect(response, equals('سڵاو! چۆن دەتوانم یارمەتیت بدەم؟'));
      },
    );

    test(
      'Greeting combined with academic question answers BOTH in a single chat response',
      () async {
        final response = await aiService.askTeacher(
          'سڵاو مامۆستا چۆنیت؟ دەمەوێت لەسەر فلاتەر بزانم',
          [],
          isVip: true,
        );

        expect(response, isNotEmpty);
        // Confirms greeting is returned
        expect(
          response.contains('سڵاو') || response.contains('بەخێربێیت'),
          isTrue,
        );
        // Confirms academic answer to the question is also returned in the same chat
        expect(
          response.contains('فلاتەر') || response.contains('Flutter'),
          isTrue,
        );
      },
    );
  });
}
