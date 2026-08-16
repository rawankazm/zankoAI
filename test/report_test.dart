import 'package:flutter_test/flutter_test.dart';
import 'package:zanko_ai/services/docx_generator_service.dart';
import 'package:zanko_ai/services/report_pdf_generator_service.dart';
import 'package:zanko_ai/utils/kurdish_arabic_reshaper.dart';

void main() {
  test('8-Page Standard English University Report DOCX and PDF generation test', () async {
    final report = DocxGeneratorService.parseReportFromText(
      rawText: '',
      title: 'Artificial Intelligence in Modern Information Technology',
      studentName: 'Rawan Ahmed\nSara Mohammed',
      supervisorName: 'Dr. John Doe',
      universityName: 'Erbil Polytechnic University',
      departmentName: 'Information Technology Department',
      academicYear: '2024 - 2025',
      languageCode: 'en',
    );

    expect(report.pages.length, 8);
    expect(report.pages[0].pageType, 'cover');
    expect(report.pages[1].pageType, 'toc');
    expect(report.pages[1].bulletPoints.length, 10);
    expect(report.pages[2].pageType, 'content');
    expect(report.pages[2].sections.length, 2);
    expect(report.pages[6].sections.length, 2);
    expect(report.pages[7].pageType, 'references');
    expect(report.pages[7].bulletPoints.length, 6);

    // Test DOCX generation
    final docxBytes = await DocxGeneratorService.createDocxBytes(report);
    expect(docxBytes.isNotEmpty, true);
    print('Generated English DOCX bytes length: ${docxBytes.length}');

    // Test PDF generation
    final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
    expect(pdfBytes.isNotEmpty, true);
    print('Generated English PDF bytes length: ${pdfBytes.length}');
  });

  test('8-Page Standard Kurdish University Report DOCX and PDF generation test', () async {
    final report = DocxGeneratorService.parseReportFromText(
      rawText: '',
      title: 'کاریگەریی ژیریی دەستکرد لەسەر تەکنۆلۆژیای زانیاری',
      studentName: 'ڕاوان ئەحمەد\nسارا محەمەد\nکاروان ڕەزا',
      supervisorName: 'پ.ی.د. نەبەز عومەر',
      universityName: 'زانکۆی پۆلیتەکنیکی هەولێر',
      departmentName: 'کۆلێژی تەکنیکی ئەندازیاری - بەشی تەکنۆلۆژیای زانیاری',
      academicYear: '2024 - 2025',
      languageCode: 'ku',
    );

    expect(report.pages.length, 8);
    expect(report.pages[0].pageType, 'cover');
    expect(report.pages[1].pageType, 'toc');
    expect(report.pages[1].bulletPoints.length, 10);
    expect(report.pages[2].pageType, 'content');
    expect(report.pages[2].sections.length, 2);
    expect(report.pages[6].sections.length, 2);
    expect(report.pages[7].pageType, 'references');
    expect(report.pages[7].bulletPoints.length, 6);

    // Test DOCX generation
    final docxBytes = await DocxGeneratorService.createDocxBytes(report);
    expect(docxBytes.isNotEmpty, true);
    print('Generated Kurdish DOCX bytes length: ${docxBytes.length}');

    // Test PDF generation with TrueType font
    final pdfBytes = await ReportPdfGeneratorService.createPdfBytes(report);
    expect(pdfBytes.isNotEmpty, true);
    print('Generated Kurdish PDF bytes length: ${pdfBytes.length}');
  });

  test('Kurdish Reshaper Diagnostic Test for Kurdish Characters', () {
    final testPhrases = [
      'ڕاپۆرت لەبارەی : کۆئەندامی هەرس',
      'بەسەرپەرشتیی : پ.ی.د. نەبەز عومەر',
      'ئامادەکردنی : ڕاوان ئەحمەد، سارا محەمەد',
      'وەزارەتی خوێندنی باڵا و توێژینەوەی زانستی',
      'زانکۆی پۆلیتەکنیکی هەولێر',
      'کۆلێژی تەکنیکی تەندروستی - بەشی تاقیگە',
      'قۆناغی : یەکەم (2024 - 2025)',
      '١. پێشەکی و گرنگیی زانستیی بابەتەکە',
      '1. Introduction to AI',
      '• خاڵی یەکەم: شیکردنەوەی داتاکان بە ڕێژەی 45.8% زیادی کردووە.',
      'تەلارسازی و چوارچێوەی گشتیی «ژیریی دەستکرد» لە کۆمەڵێک بەش پێکدێت.',
    ];

    for (var phrase in testPhrases) {
      final shaped = KurdishArabicReshaper.shape(phrase);
      final reordered = KurdishArabicReshaper.shapeAndReorder(phrase);
      expect(shaped.isNotEmpty, true);
      expect(reordered.isNotEmpty, true);
    }
  });
}
