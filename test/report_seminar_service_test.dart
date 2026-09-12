// ==============================================================================
// ZankoAI Report & Seminar Backend Integration Unit Tests
// ==============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanko_ai/models/academic_report_seminar_model.dart';
import 'package:zanko_ai/services/report_seminar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Report & Seminar Supabase Models Test', () {
    test('AcademicSectionModel serializes and deserializes correctly', () {
      final section = AcademicSectionModel(
        id: 'sec_123',
        sectionOrder: 1,
        title: 'Introduction to AI in Medicine',
        content:
            'Artificial Intelligence is revolutionizing clinical diagnostic workflows.',
      );

      final json = section.toJson();
      expect(json['id'], equals('sec_123'));
      expect(json['section_order'], equals(1));
      expect(json['title'], equals('Introduction to AI in Medicine'));

      final parsed = AcademicSectionModel.fromJson({
        'id': 'sec_123',
        'section_order': 1,
        'title': 'Introduction to AI in Medicine',
        'content':
            'Artificial Intelligence is revolutionizing clinical diagnostic workflows.',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(parsed.id, equals('sec_123'));
      expect(parsed.sectionOrder, equals(1));
      expect(parsed.title, equals('Introduction to AI in Medicine'));
    });

    test(
      'AcademicReportRecord serializes and deserializes correctly with sections',
      () {
        final now = DateTime.now();
        final report = AcademicReportRecord(
          id: 'rep_999',
          userId: 'usr_abc',
          title: 'ڕۆڵی ژیریی دەستکرد لە پەرەپێدانی سۆفتوێر',
          subject: 'Computer Science',
          language: 'ku',
          topic: 'AI Software Engineering',
          description: 'Detailed analysis of LLMs in coding',
          content: '### Title: ڕۆڵی ژیریی دەستکرد\n1. پێشەکی...',
          status: 'completed',
          sections: [
            AcademicSectionModel(
              id: 'sec_1',
              sectionOrder: 1,
              title: 'پێشەکی و گرنگی بابەت',
              content: 'ناوەڕۆکی پێشەکی...',
            ),
            AcademicSectionModel(
              id: 'sec_2',
              sectionOrder: 2,
              title: 'پاشخانی زانستی',
              content: 'ناوەڕۆکی پاشخانی زانستی...',
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );

        final json = report.toJson();
        expect(json['id'], equals('rep_999'));
        expect(json['user_id'], equals('usr_abc'));
        expect(json['language'], equals('ku'));
        expect(json['sections'], isA<List>());
        expect((json['sections'] as List).length, equals(2));

        final parsed = AcademicReportRecord.fromJson(json);
        expect(parsed.id, equals('rep_999'));
        expect(
          parsed.title,
          equals('ڕۆڵی ژیریی دەستکرد لە پەرەپێدانی سۆفتوێر'),
        );
        expect(parsed.sections.length, equals(2));
        expect(parsed.sections[0].title, equals('پێشەکی و گرنگی بابەت'));
      },
    );

    test(
      'AcademicSeminarRecord serializes and deserializes correctly with slides/sections',
      () {
        final now = DateTime.now();
        final seminar = AcademicSeminarRecord(
          id: 'sem_888',
          userId: 'usr_abc',
          title: 'سیمیناری مایکرۆسێرڤس و دابەشکردنی سیستەمەکان',
          subject: 'Software Architecture',
          language: 'ku',
          topic: 'Microservices vs Monoliths',
          description: 'PowerPoint 8 slides',
          content: '### 🔹 سلایدی ١: ناساندن\n- خاڵی یەکەم...',
          status: 'completed',
          sections: [
            AcademicSectionModel(
              sectionOrder: 1,
              title: 'Slide 1: Overview',
              content: '- Point 1\n- Point 2',
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );

        final json = seminar.toJson();
        expect(json['id'], equals('sem_888'));
        expect(
          json['title'],
          equals('سیمیناری مایکرۆسێرڤس و دابەشکردنی سیستەمەکان'),
        );
        expect(json['status'], equals('completed'));

        final parsed = AcademicSeminarRecord.fromJson(json);
        expect(parsed.id, equals('sem_888'));
        expect(parsed.sections.length, equals(1));
      },
    );
  });

  group('ReportSeminarService Offline & Fallback Caching Test', () {
    test(
      'createReport creates fallback and caches locally on network failure',
      () async {
        final service = ReportSeminarService.instance;

        final report = await service.createReport(
          title: 'Offline Report Test',
          subject: 'Information Technology',
          language: 'en',
          topic: 'Cloud Computing Security',
          content: 'Offline content preview',
          sections: [
            AcademicSectionModel(
              sectionOrder: 1,
              title: 'Cloud Security Fundamentals',
              content: 'Shared responsibility model',
            ),
          ],
        );

        expect(report.title, equals('Offline Report Test'));
        expect(report.language, equals('en'));

        // Verify cached locally in SharedPreferences
        final reports = await service.getReports();
        expect(reports.any((r) => r.title == 'Offline Report Test'), isTrue);
      },
    );

    test(
      'createSeminar creates fallback and caches locally on network failure',
      () async {
        final service = ReportSeminarService.instance;

        final seminar = await service.createSeminar(
          title: 'Offline Seminar Test',
          language: 'ar',
          topic: 'النظم الموزعة',
          content: 'محتوى العرض التقديمي',
        );

        expect(seminar.title, equals('Offline Seminar Test'));
        expect(seminar.language, equals('ar'));

        final list = await service.getSeminars();
        expect(list.any((s) => s.title == 'Offline Seminar Test'), isTrue);
      },
    );

    test('deleteReport removes record from local cache', () async {
      final service = ReportSeminarService.instance;

      final report = await service.createReport(
        title: 'Temporary Report to Delete',
        language: 'ku',
      );

      final before = await service.getReports();
      expect(before.any((r) => r.id == report.id), isTrue);

      await service.deleteReport(report.id);

      final after = await service.getReports();
      expect(after.any((r) => r.id == report.id), isFalse);
    });
  });

  group('Prompt 38 Architectural Guardrails & Security Test', () {
    test('No Firebase dependencies in academic services or views', () {
      final filesToCheck = [
        'lib/services/report_seminar_service.dart',
        'lib/models/academic_report_seminar_model.dart',
        'lib/widgets/academic_history_sheet.dart',
        'lib/views/academic/seminar_thesis_assistant_screen.dart',
      ];

      for (var path in filesToCheck) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'File $path must exist');
        final content = file.readAsStringSync();
        expect(
          content.contains('cloud_firestore'),
          isFalse,
          reason: '$path must not contain cloud_firestore',
        );
        expect(
          content.contains('firebase_storage'),
          isFalse,
          reason: '$path must not contain firebase_storage',
        );
        expect(
          content.contains('firebase_auth'),
          isFalse,
          reason: '$path must not contain firebase_auth',
        );
      }
    });

    test('Supabase migration exists and includes reports, seminars, and RLS', () {
      final migrationFile = File(
        'supabase/migrations/20260912000027_create_reports_and_seminars_system.sql',
      );
      expect(migrationFile.existsSync(), isTrue);

      final sql = migrationFile.readAsStringSync();
      expect(sql.contains('CREATE TABLE IF NOT EXISTS public.reports'), isTrue);
      expect(
        sql.contains('CREATE TABLE IF NOT EXISTS public.report_sections'),
        isTrue,
      );
      expect(
        sql.contains('CREATE TABLE IF NOT EXISTS public.seminars'),
        isTrue,
      );
      expect(
        sql.contains('CREATE TABLE IF NOT EXISTS public.seminar_sections'),
        isTrue,
      );
      expect(
        sql.contains('CREATE TABLE IF NOT EXISTS public.academic_files'),
        isTrue,
      );
      expect(sql.contains('ENABLE ROW LEVEL SECURITY'), isTrue);
      expect(sql.contains('auth.uid() = user_id'), isTrue);
      expect(sql.contains('academic-documents'), isTrue);
    });
  });
}
