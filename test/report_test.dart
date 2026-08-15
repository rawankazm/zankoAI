import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/docx_generator_service.dart';
import 'package:zanko_ai/services/report_pdf_generator_service.dart';

void main() {
  test('12-Page DOCX and PDF generation test', () async {
    final rawText = '''
# 📑 ڕاپۆرتی زانستی: کاریگەریی ژیریی دەستکرد
### 🔹 پەڕەی ٣: ناساندن و گرنگی بابەتەکە
- ناساندنی چەمکی سەرەکی ژیریی دەستکرد
- بەکارهێنانی لە زانکۆکاندا
### 🔹 پەڕەی ٤: چەمک و بنەما تیۆرییەکان
- پێناسەی مۆدێلە زانستییەکان
### 🔹 پەڕەی ٥: کێشەی توێژینەوە
- بۆشاییە زانستییەکان
### 🔹 پەڕەی ٦: ئامانجەکانی توێژینەوە
- دەستنیشانکردنی کارایی
### 🔹 پەڕەی ٧: میتۆدۆلۆجی
- تاقیکردنەوەی مەیدانی
### 🔹 پەڕەی ٨: شیکاریی داتاکان
- بەرزبوونەوەی کارایی بە ڕێژەی ٨٥٪
### 🔹 پەڕەی ٩: دۆزینەوە سەرەکییەکان
- دابەزینی ڕێژەی هەڵە بۆ کەمتر لە ٣٪
### 🔹 پەڕەی ١٠: ڕاسپاردە و پێشنیارەکان
- پلان بۆ جێبەجێکردنی پڕۆژە
### 🔹 پەڕەی ١١: دەرئەنجامی گشتی
- سەلماندنی گریمانەی سەرەکی
### 🔹 پەڕەی ١٢: سەرچاوە زانستییەکان
- Smith, J. A. (2024). Modern Methodologies.
- World Educational Research Association (2025).
- UNESCO (2025). Guidelines.
- ئەحمەد، ڕێبوار (٢٠٢٤). میتۆدۆلۆجی.
- IEEE Standard Association (2025).
''';

    final report = DocxGeneratorService.parseReportFromText(
      rawText: rawText,
      title: 'کاریگەریی ژیریی دەستکرد لەسەر فێربوونی ئەکادیمی',
      studentName: 'ڕاوان ئەحمەد',
      supervisorName: 'د. ئارام مەحموود',
      universityName: 'زانکۆی سەڵاحەدین - هەولێر',
      departmentName: 'کۆلێژی زانست - بەشی کۆمپیوتەر',
      academicYear: '2025 - 2026',
      languageCode: 'ku',
    );

    expect(report.pages.length, 12);
    expect(report.pages[0].pageType, 'cover');
    expect(report.pages[1].pageType, 'toc');
    expect(report.pages[10].pageType, 'conclusion');
    expect(report.pages[11].pageType, 'references');
    expect(report.pages[11].bulletPoints.length >= 5, true);

    // Test DOCX generation
    final docxBytes = await DocxGeneratorService.createDocxBytes(report);
    expect(docxBytes.isNotEmpty, true);
    print('Generated DOCX bytes length: ${docxBytes.length}');

    // Test PDF generation
    final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
    expect(pdfBytes.isNotEmpty, true);
    print('Generated PDF bytes length: ${pdfBytes.length}');
  });
}
