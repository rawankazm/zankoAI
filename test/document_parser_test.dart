import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/document_parser_service.dart';
import 'package:zanko_ai/services/docx_generator_service.dart';
import 'package:zanko_ai/services/pptx_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentParserService Tests', () {
    test('Allowed extensions list contains all Word and PowerPoint formats', () {
      expect(DocumentParserService.allowedExtensions, contains('docx'));
      expect(DocumentParserService.allowedExtensions, contains('doc'));
      expect(DocumentParserService.allowedExtensions, contains('pptx'));
      expect(DocumentParserService.allowedExtensions, contains('ppt'));
      expect(DocumentParserService.allowedExtensions, contains('pdf'));
      expect(DocumentParserService.allowedExtensions, contains('txt'));
    });

    test('Parses plain text document correctly', () {
      final textContent = 'سڵاو لە زانکۆ ئای ئەی! ئەمە تاقیکردنەوەی دەقە.';
      final bytes = Uint8List.fromList(utf8.encode(textContent));

      final result = DocumentParserService.parseDocumentBytes(
        fileName: 'sample_lecture.txt',
        bytes: bytes,
      );

      expect(result.isPlainText, isTrue);
      expect(result.content, contains('زانکۆ ئای ئەی'));
      expect(result.fileName, equals('sample_lecture.txt'));
      expect(result.extension, equals('txt'));
    });

    test('Parses generated DOCX document correctly', () async {
      final report = DocxGeneratorService.parseReportFromText(
        rawText: 'تەوەرەی ١: پێناسە و چەمکەکان\nئەمە ناوەڕۆکی بەشی یەکەمە لەسەر زیرەکی دەستکرد.',
        title: 'شیکاری سیستەمە ژیرەکان',
        studentName: 'قوتابی تاقیکردنەوە',
        supervisorName: 'سەرپەرشتیار',
        universityName: 'زانکۆی پۆلیتەکنیکی هەولێر',
        departmentName: 'ئەندازیاری کۆمپیوتەر',
        academicYear: '2024 - 2025',
        languageCode: 'ku',
      );
      final docxBytes = await DocxGeneratorService.createDocxBytes(report);
      final uint8Bytes = Uint8List.fromList(docxBytes);

      final result = DocumentParserService.parseDocumentBytes(
        fileName: 'systems_report.docx',
        bytes: uint8Bytes,
      );

      expect(result.isWord, isTrue);
      expect(result.content, contains('شیکاری سیستەمە ژیرەکان'));
      expect(result.fileName, equals('systems_report.docx'));
      expect(result.extension, equals('docx'));
      expect(result.estimatedPagesOrSlides, greaterThanOrEqualTo(1));
    });

    test('Parses generated PPTX presentation correctly', () async {
      const rawText = '''
# 📊 سیمینار: پێشکەشکردنی زیرەکی دەستکرد
### 🔹 سلایدی ١: ناساندنی سیمینار
- ناونیشانی سەرەکی: تەکنەلۆجیای زیرەک
- خاڵە سەرەکییەکان: پێناسە و مێژوو
- 🎙️ تێبینی پێشکەشکار: بەخێربێن

### 🔹 سلایدی ٢: کێشەی توێژینەوە
- ناونیشانی سەرەکی: ئاستەنگەکان
- کێشە نەریتییەکان لە کارگێڕیدا
''';

      final slides = PptxGeneratorService.parseSlidesFromText(
        rawText,
        defaultTitle: 'پێشکەشکردنی زیرەکی دەستکرد',
      );
      final pptxBytes = await PptxGeneratorService.createPptxBytes(
        slides,
        presentationTitle: 'پێشکەشکردنی زیرەکی دەستکرد',
        studentName: 'ئاراس علی',
        supervisorName: 'د. نەبەز',
        university: 'زانکۆی سەڵاحەدین',
        department: 'کۆلێژی زانست',
      );
      final uint8Bytes = Uint8List.fromList(pptxBytes);

      final result = DocumentParserService.parseDocumentBytes(
        fileName: 'ai_seminar.pptx',
        bytes: uint8Bytes,
      );

      expect(result.isPowerPoint, isTrue);
      expect(result.content, contains('سڵایدی'));
      expect(result.content, contains('کێشەی توێژینەوە'));
      expect(result.content, contains('زانکۆی سەڵاحەدین'));
      expect(result.fileName, equals('ai_seminar.pptx'));
    });

    test('Parses legacy RTF .doc document correctly', () {
      final rtfContent = r'{\rtf1\ansi\deff0 {\fonttbl {\f0 Calibri;}}\f0\fs24 Kurdish Academic Lecture on Database Systems\par Section 1: Relational Modeling\par}';
      final bytes = Uint8List.fromList(utf8.encode(rtfContent));

      final result = DocumentParserService.parseDocumentBytes(
        fileName: 'database_lecture.doc',
        bytes: bytes,
      );

      expect(result.isWord, isTrue);
      expect(result.content, contains('Kurdish Academic Lecture on Database Systems'));
      expect(result.content, contains('Relational Modeling'));
      expect(result.extension, equals('doc'));
    });

    test('Parses legacy binary .doc with UTF-16 strings correctly', () {
      final text = 'زانکۆی پۆلیتەکنیکی هەولێر - کۆلێژی تەکنیکی ئەندازیاری';
      final utf16Units = <int>[];
      for (final rune in text.runes) {
        utf16Units.add(rune & 0xFF);
        utf16Units.add((rune >> 8) & 0xFF);
      }
      final bytes = Uint8List.fromList(utf16Units);

      final result = DocumentParserService.parseDocumentBytes(
        fileName: 'university_doc.doc',
        bytes: bytes,
      );

      expect(result.isWord, isTrue);
      expect(result.content, contains('زانکۆی پۆلیتەکنیکی هەولێر'));
    });
  });
}
